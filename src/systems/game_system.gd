extends Node
## Central game state manager that handles player data, game state, and core game logic.

## Dictionary containing all connected players with their data
## Key: player_id (int), Value: Dictionary with player information
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

var current_state: GameState = GameState.MENU
var game_settings: Dictionary = {
	"max_players": 4,
	"game_mode": "deathmatch",
	"map": "default",
	"match_duration_seconds": 300.0
}

var match_time_remaining: float = 0.0
var match_end_time_msec: int = 0

var _match_timer: Timer

func _ready() -> void:
	_match_timer = Timer.new()
	_match_timer.one_shot = true
	_match_timer.timeout.connect(_on_match_timer_timeout)
	add_child(_match_timer)
	
	set_process(false)
	# Ensure EventManager is ready before registering events
	if EventManager._signal_dict.is_empty():
		await get_tree().process_frame
		if EventManager._signal_dict.is_empty():
			push_error("GameManager: EventManager failed to initialize!")
			return
	
	EventManager.register(EventManager.Events.PLAYER_CONNECTED, _on_player_connected)
	EventManager.register(EventManager.Events.PLAYER_DISCONNECTED, _on_player_disconnected)
	EventManager.register(EventManager.Events.CONNECTION_SUCCEEDED, _on_connection_succeeded)
	EventManager.register(EventManager.Events.CONNECTION_FAILED, _on_connection_failed)

## Add a new player to the game
##
## @param player_id 	The unique identifier for the player
## @param player_data 	Dictionary containing player information (name, etc.)
func add_player(player_id: int, player_data: Dictionary) -> void:
	players[player_id] = player_data
	print("Player added: ", player_data.get("name", "Unknown"), " (ID: ", player_id, ")") # TODO: rm later

## Remove a player from the game
##
## @param player_id The unique identifier for the player to remove
## @return Dictionary containing the removed player's data, or empty dict if not found
func remove_player(player_id: int) -> Dictionary:
	if players.has(player_id):
		var player_data = players[player_id]
		players.erase(player_id)
		print("Player removed: ", player_data.get("name", "Unknown"), " (ID: ", player_id, ")") # TODO: rm later
		return player_data
	return {}

## Get player data by ID
##
## @param player_id The unique identifier for the player
## @return Dictionary containing player data, or empty dict if not found
func get_player(player_id: int) -> Dictionary:
	return players.get(player_id, {})

## Get all connected players
##
## @return Array of player data dictionaries
func get_all_players() -> Array:
	return players.values()

## Get the number of connected players
##
## @return The current player count
func get_player_count() -> int:
	return players.size()

## Check if the game is full
##
## @return True if at max capacity, false otherwise
func is_game_full() -> bool:
	return players.size() >= game_settings.max_players

## Set the current game state
##
## @param new_state The new game state to set
func set_game_state(new_state: GameState) -> void:
	if current_state != new_state:
		var old_state = current_state
		current_state = new_state
		print("Game state changed from ", GameState.keys()[old_state], " to ", GameState.keys()[new_state]) # TODO: rm later

		# Emit state change event
		EventManager.emit_event(EventManager.Events.GAME_STATE_CHANGED, [old_state, new_state])

## Get the current game state
##
## @return The current GameState
func get_game_state() -> GameState:
	return current_state

## Get the current game state as a string
##
## @return The current GameState as a string name
func get_game_state_name() -> String:
	return GameState.keys()[current_state]

## Check if the game is in a specific state
##
## @param state The GameState to check against
## @return True if the current state matches the provided state
func is_state(state: GameState) -> bool:
	return current_state == state

## Check if the game is in lobby (waiting for players)
##
## @return True if the game is in LOBBY state
func is_in_lobby() -> bool:
	return current_state == GameState.LOBBY

## Check if currently connecting to a game
##
## @return True if the game is in CONNECTING state
func is_connecting() -> bool:
	return current_state == GameState.CONNECTING

## Start the game (transition to PLAYING state)
func start_game() -> void:
	start_match()

## Begin a timed match. Server runs the countdown and returns players to lobby when it expires.
func start_match() -> void:
	var duration: float = game_settings.match_duration_seconds
	match_time_remaining = duration
	set_game_state(GameState.PLAYING)
	set_process(true)
	
	if not multiplayer.is_server():
		return
	
	var duration_msec: int = int(duration * 1000.0)
	match_end_time_msec = Time.get_ticks_msec() + duration_msec
	sync_match_timer.rpc(match_end_time_msec)
	_match_timer.start(duration)

## End the game (transition to GAME_OVER state)
func end_game() -> void:
	_stop_match_timer()
	set_game_state(GameState.GAME_OVER)

## Return to lobby after a match without disconnecting players.
func return_to_lobby() -> void:
	_stop_match_timer()
	match_end_time_msec = 0
	match_time_remaining = 0.0
	set_process(false)
	set_game_state(GameState.LOBBY)

## Disconnect from current game (transition to DISCONNECTED state)
func disconnect_from_game() -> void:
	set_game_state(GameState.DISCONNECTED)
	# Clear all players when disconnecting
	players.clear()

## Return to menu (transition to MENU state)
func return_to_menu() -> void:
	set_game_state(GameState.MENU)
	# Clear game data when returning to menu
	players.clear()

## Event handlers
func _on_player_connected(player_id: int) -> void:
	print("GameManager: Player connected event received for ID: ", player_id) # TODO: rm later
	
	# If we're in menu and this is the first connection, go to lobby
	if current_state == GameState.MENU and get_player_count() == 0:
		set_game_state(GameState.LOBBY)

func _on_player_disconnected(player_id: int, _player_data: Dictionary) -> void:
	print("GameManager: Player disconnected event received for ID: ", player_id) # TODO: rm later
	remove_player(player_id)
	
	# If we're in lobby and no players left, return to menu
	if current_state == GameState.LOBBY and get_player_count() == 0:
		set_game_state(GameState.MENU)

func _on_connection_succeeded() -> void:
	set_game_state(GameState.LOBBY)

func _on_connection_failed() -> void:
	set_game_state(GameState.MENU)

func _process(_delta: float) -> void:
	if current_state != GameState.PLAYING or match_end_time_msec <= 0:
		return
	
	match_time_remaining = maxf(0.0, (match_end_time_msec - Time.get_ticks_msec()) / 1000.0)

func _on_match_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	
	var lobby = get_tree().get_first_node_in_group("Lobby")
	if lobby and lobby.has_method("return_to_lobby"):
		lobby.return_to_lobby.rpc()
	else:
		push_warning("GameManager: No lobby found after match timer expired.")
		return_to_lobby()

func _stop_match_timer() -> void:
	if _match_timer.time_left > 0.0:
		_match_timer.stop()

@rpc("authority", "call_local", "reliable")
func sync_match_timer(end_time_msec: int) -> void:
	match_end_time_msec = end_time_msec
	match_time_remaining = maxf(0.0, (match_end_time_msec - Time.get_ticks_msec()) / 1000.0)
