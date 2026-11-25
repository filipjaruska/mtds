extends Node
## GameManager (autoload): who is in the session, what state it is in
## (menu, lobby, match...), the lobby settings, the match clock and match stats.

## peer id -> {id, name, color, team}
var players: Dictionary = {}

var local_player_name: String = ""

enum GameState {
	MENU,
	CONNECTING,
	LOBBY,
	PLAYING,
	GAME_OVER,
	DISCONNECTED
}

const GAME_TYPE_DEATHMATCH := "deathmatch"
const GAME_TYPE_TEAMS := "teams"

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector
## Players per match, host included. Maps need this many spawn points.
var MAX_PLAYERS: int = RULES.max_players

var current_state: GameState = GameState.MENU
var game_settings: Dictionary = {
	"max_players": MAX_PLAYERS,
	"game_type": GAME_TYPE_DEATHMATCH,
	"map": "", # res:// path of the selected map scene
	"match_duration_seconds": RULES.match_seconds
}

var match_time_remaining: float = 0.0
## A single-player tutorial session (TutorialLauncher); cleared on return to menu.
var tutorial_mode := false
var match_end_time_msec: int = 0
var match_stats: Dictionary = {}

var _match_timer: Timer
var _match_stats_dirty: bool = false
var _match_stats_sync_cooldown: float = 0.0
const MATCH_STATS_SYNC_INTERVAL := 0.25

func _ready() -> void:
	_match_timer = Timer.new()
	_match_timer.one_shot = true
	_match_timer.timeout.connect(_on_match_timer_timeout)
	add_child(_match_timer)
	
	set_process(false)
	EventManager.player_connected.connect(_on_player_connected)
	EventManager.player_disconnected.connect(_on_player_disconnected)
	EventManager.connected_to_host.connect(_on_connection_succeeded)
	EventManager.connection_failed.connect(_on_connection_failed)

func get_match_time_remaining() -> float:
	return match_time_remaining

func set_game_type(game_type: String) -> void:
	game_settings["game_type"] = game_type

func get_game_type() -> String:
	return game_settings.get("game_type", GAME_TYPE_DEATHMATCH)

func is_team_mode() -> bool:
	return get_game_type() == GAME_TYPE_TEAMS

func set_map(map_path: String) -> void:
	game_settings["map"] = map_path

func get_map() -> String:
	return game_settings.get("map", "")

## Team index of a player (0 Red, 1 Blue); see TeamRules.
func get_team(player_id: int) -> int:
	return TeamRules.team_of(players, player_id)

func set_team(player_id: int, team: int) -> void:
	if players.has(player_id):
		players[player_id]["team"] = team

func are_teammates(a: int, b: int) -> bool:
	return TeamRules.is_friendly(players, a, b, is_team_mode())

func get_match_duration() -> float:
	return float(game_settings.get("match_duration_seconds", RULES.match_seconds))

func add_player(player_id: int, player_data: Dictionary) -> void:
	players[player_id] = player_data

func remove_player(player_id: int) -> Dictionary:
	if players.has(player_id):
		var player_data = players[player_id]
		players.erase(player_id)
		return player_data
	return {}

func get_player(player_id: int) -> Dictionary:
	return players.get(player_id, {})

func get_all_players() -> Array:
	return players.values()

func get_player_count() -> int:
	return players.size()

func is_game_full() -> bool:
	return players.size() >= int(game_settings.get("max_players", MAX_PLAYERS))

func set_game_state(new_state: GameState) -> void:
	if current_state != new_state:
		var old_state = current_state
		current_state = new_state

		EventManager.game_state_changed.emit(old_state, new_state)

func get_game_state() -> GameState:
	return current_state

func get_game_state_name() -> String:
	return GameState.keys()[current_state]

func is_state(state: GameState) -> bool:
	return current_state == state

func is_in_lobby() -> bool:
	return current_state == GameState.LOBBY

func is_connecting() -> bool:
	return current_state == GameState.CONNECTING

func start_game() -> void:
	start_match()

## Begin a timed match. Server runs the countdown and returns players to lobby when it expires.
func start_match() -> void:
	reset_match_stats()
	var duration: float = float(game_settings.get("match_duration_seconds", RULES.match_seconds))
	match_time_remaining = duration
	set_game_state(GameState.PLAYING)
	set_process(true)
	
	if not multiplayer.is_server():
		return
	
	sync_match_mode_state.rpc(get_game_type())
	# Send the remaining duration, not an absolute tick value: Time.get_ticks_msec()
	# is process uptime and differs on every machine.
	sync_match_timer.rpc(duration)
	_match_timer.start(duration)

func end_game() -> void:
	_stop_match_timer()
	set_game_state(GameState.GAME_OVER)

## Return to lobby after a match without disconnecting players.
func return_to_lobby() -> void:
	_stop_match(true)
	set_game_state(GameState.LOBBY)

func _stop_match(broadcast_stats: bool) -> void:
	_stop_match_timer()
	match_end_time_msec = 0
	match_time_remaining = 0.0
	if broadcast_stats:
		reset_match_stats()
	else:
		match_stats.clear()
	set_process(false)

func reset_match_stats() -> void:
	match_stats.clear()
	for player_id in players:
		match_stats[player_id] = {
			"kills": 0,
			"deaths": 0,
			"damage_dealt": 0.0,
		}
	_broadcast_match_stats()

func _ensure_player_stats(player_id: int) -> void:
	if not match_stats.has(player_id):
		match_stats[player_id] = {
			"kills": 0,
			"deaths": 0,
			"damage_dealt": 0.0,
		}

## Host only: called by HealthComponent when damage is applied.
func record_damage(attacker_id: int, amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	_ensure_player_stats(attacker_id)
	match_stats[attacker_id]["damage_dealt"] += amount
	_match_stats_dirty = true

## Host only: called by HealthComponent when a player dies.
func record_death(victim_id: int, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_ensure_player_stats(victim_id)
	match_stats[victim_id]["deaths"] += 1
	if killer_id > 0 and killer_id != victim_id:
		_ensure_player_stats(killer_id)
		match_stats[killer_id]["kills"] += 1
	_broadcast_match_stats()
	_match_stats_dirty = false

func get_sorted_match_results() -> Array:
	var results: Array = []
	for player_id in players:
		var stats: Dictionary = match_stats.get(player_id, {
			"kills": 0,
			"deaths": 0,
			"damage_dealt": 0.0,
		})
		results.append({
			"id": player_id,
			"name": players[player_id].get("name", "Player %d" % player_id),
			"team": get_team(player_id),
			"kills": stats.get("kills", 0),
			"deaths": stats.get("deaths", 0),
			"damage_dealt": stats.get("damage_dealt", 0.0),
		})
	
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["damage_dealt"] > b["damage_dealt"]
	)
	return results

func _broadcast_match_stats() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server():
		return
	sync_match_stats.rpc(_serialize_match_stats())
	_match_stats_sync_cooldown = MATCH_STATS_SYNC_INTERVAL

func _serialize_match_stats() -> Dictionary:
	var serialized: Dictionary = {}
	for player_id in match_stats:
		serialized[str(player_id)] = match_stats[player_id].duplicate()
	return serialized

@rpc("authority", "call_local", "reliable")
func sync_match_stats(stats: Dictionary) -> void:
	match_stats.clear()
	for key in stats:
		var player_id := int(key)
		var entry: Dictionary = stats[key]
		match_stats[player_id] = {
			"kills": int(entry.get("kills", 0)),
			"deaths": int(entry.get("deaths", 0)),
			"damage_dealt": float(entry.get("damage_dealt", 0.0)),
		}

func disconnect_from_game() -> void:
	_stop_match(false)
	set_game_state(GameState.DISCONNECTED)
	players.clear()

func return_to_menu() -> void:
	_stop_match(false)
	if tutorial_mode:
		tutorial_mode = false
		game_settings["match_duration_seconds"] = RULES.match_seconds
	set_game_state(GameState.MENU)
	players.clear()

func _on_player_connected(_player_id: int) -> void:
	if current_state == GameState.MENU and get_player_count() == 0:
		set_game_state(GameState.LOBBY)

func _on_player_disconnected(player_id: int, _player_data: Dictionary) -> void:
	remove_player(player_id)
	
	if current_state == GameState.LOBBY and get_player_count() == 0:
		set_game_state(GameState.MENU)

func _on_connection_succeeded() -> void:
	set_game_state(GameState.LOBBY)

func _on_connection_failed() -> void:
	set_game_state(GameState.MENU)

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	if multiplayer.is_server() and _match_stats_dirty:
		_match_stats_sync_cooldown = maxf(0.0, _match_stats_sync_cooldown - delta)
		if _match_stats_sync_cooldown <= 0.0:
			_broadcast_match_stats()
			_match_stats_dirty = false
			_match_stats_sync_cooldown = MATCH_STATS_SYNC_INTERVAL
	
	if match_end_time_msec <= 0:
		return

	match_time_remaining = maxf(0.0, (match_end_time_msec - Time.get_ticks_msec()) / 1000.0)

## Host: end the round now (Esc menu), with results for everyone.
func finish_match_now() -> void:
	_on_match_timer_timeout()

func _on_match_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	
	end_game()
	
	var lobby = get_tree().get_first_node_in_group("Lobby")
	if lobby and lobby.has_method("show_match_results"):
		lobby.show_match_results.rpc(get_sorted_match_results())
	elif lobby and lobby.has_method("return_to_lobby"):
		lobby.return_to_lobby.rpc()
	else:
		push_warning("GameManager: No lobby found after match timer expired.")
		return_to_lobby()

func _stop_match_timer() -> void:
	if _match_timer.time_left > 0.0:
		_match_timer.stop()

@rpc("authority", "call_local", "reliable")
func sync_match_mode_state(game_type: String) -> void:
	set_game_type(game_type)

@rpc("authority", "call_local", "reliable")
func sync_match_timer(remaining_seconds: float) -> void:
	# Convert to this machine's own clock.
	match_end_time_msec = Time.get_ticks_msec() + int(remaining_seconds * 1000.0)
	match_time_remaining = maxf(0.0, remaining_seconds)
