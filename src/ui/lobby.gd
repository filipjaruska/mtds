extends Control

var available_maps: Array[String] = []
var player_ready_states: Dictionary = {}
var _active_map: Node = null
var _match_results_overlay: CanvasLayer = null
## Another menu tab (options, profile, ...) opened from the lobby's nav bar.
var _menu_overlay: Node = null

const MATCH_RESULTS_SCENE := preload("res://src/ui/menus/match_results.tscn")
const PAUSE_MENU_SCENE := preload("res://src/ui/menus/pause_menu.tscn")
const PLAYER_ROW_SCENE := preload("res://src/ui/library/lobby_player_row.tscn")
const MAIN_MENU_SCENE := "res://src/ui/menus/main.tscn"
const DEBUG_MAP := "res://src/scenes/debug.tscn"
## Dropdown entries: [setting value, label, description (also the tooltip)].
const GAME_TYPES := [
	[GameManager.GAME_TYPE_DEATHMATCH, "Deathmatch",
		"Everyone for themselves. Players are ranked by damage dealt."],
	[GameManager.GAME_TYPE_TEAMS, "Team Deathmatch",
		"Red vs Blue. No friendly fire, each team spawns on its own side, and the team with the most kills wins."],
]

@onready var player_name_input: LineEdit = %NameInput
@onready var start_button: Button = %StartButton
@onready var ready_button: Button = %ReadyButton
@onready var player_rows: VBoxContainer = %PlayerRows
@onready var map_dropdown: OptionButton = %MapDropdown
@onready var game_type_dropdown: OptionButton = %GametypeDropdown
@onready var game_type_description: Label = %GametypeDescription
@onready var switch_team_button: Button = %SwitchTeamButton

func _enter_tree() -> void:
	# Before children are ready, so the nav bar already sees an active lobby.
	add_to_group("Lobby")

func _exit_tree() -> void:
	close_menu_overlay()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	var player_name = GameManager.local_player_name
	if player_name.is_empty():
		player_name = "Player " + str(multiplayer.get_unique_id())
	player_name_input.text = player_name
	player_name_input.editable = false
	
	_load_available_maps()
	add_child(PAUSE_MENU_SCENE.instantiate())
	_fill_dropdown(game_type_dropdown, GAME_TYPES)
	_sync_settings_ui()
	_setup_ui_for_role()
	
	var player_color: Color = GameSettings.player_color
	player_color.a = 1.0
	if multiplayer.get_unique_id() != 1:
		request_register.rpc_id(1, player_name, player_color)
	else:
		GameManager.add_player(1, {"id": 1, "name": player_name, "color": player_color, "team": 0})
		player_ready_states[1] = true
		_update_player_list()

func _setup_ui_for_role() -> void:
	if multiplayer.is_server():
		start_button.visible = true
		start_button.disabled = false
		ready_button.visible = false
		map_dropdown.disabled = false
		game_type_dropdown.disabled = false
	else:
		start_button.visible = false
		ready_button.visible = true
		ready_button.disabled = false
		map_dropdown.disabled = true
		game_type_dropdown.disabled = true
		player_ready_states[multiplayer.get_unique_id()] = false

func _load_available_maps() -> void:
	map_dropdown.clear()
	available_maps.clear()
	
	# Dev-only map: listed first (the default) when running from the editor or a
	# debug export, hidden in release builds.
	if OS.is_debug_build():
		available_maps.append(DEBUG_MAP)
		map_dropdown.add_item("debug")

	var maps_dir = "res://src/scenes/maps/"
	# ResourceLoader also sees maps in exported builds (DirAccess does not).
	for file_name in ResourceLoader.list_directory(maps_dir):
		if file_name.ends_with(".tscn"):
			available_maps.append(maps_dir + file_name)
			map_dropdown.add_item(file_name.trim_suffix(".tscn"))
	
	map_dropdown.select(0)
	# The host starts on its first map; clients get the host's choice on join.
	if multiplayer.is_server() and not available_maps.has(GameManager.get_map()):
		GameManager.set_map(available_maps[0] if not available_maps.is_empty() else "")

func _fill_dropdown(dropdown: OptionButton, options: Array) -> void:
	dropdown.clear()
	for i in range(options.size()):
		dropdown.add_item(options[i][1])
		dropdown.set_item_tooltip(i, options[i][2])

func _option_index(options: Array, value: String) -> int:
	for i in range(options.size()):
		if options[i][0] == value:
			return i
	return 0

func _show_option(dropdown: OptionButton, description: Label, options: Array, value: String) -> void:
	var index := _option_index(options, value)
	dropdown.select(index)
	description.text = options[index][2]
	dropdown.tooltip_text = options[index][2]

## Shows the current GameManager settings in the dropdowns and player list.
func _sync_settings_ui() -> void:
	_show_option(game_type_dropdown, game_type_description, GAME_TYPES, GameManager.get_game_type())
	_show_map(GameManager.get_map())
	switch_team_button.visible = GameManager.is_team_mode()
	_update_player_list()

## Selects the host's map. A map this build does not list (e.g. the debug map
## on a release client) is still shown, by file name.
func _show_map(map_path: String) -> void:
	if map_path.is_empty():
		return
	var index := available_maps.find(map_path)
	if index == -1:
		available_maps.append(map_path)
		map_dropdown.add_item(map_path.get_file().trim_suffix(".tscn"))
		index = available_maps.size() - 1
	map_dropdown.select(index)

## Host -> everyone: the lobby settings. Sent whole so they can never drift apart.
@rpc("authority", "call_local", "reliable")
func sync_lobby_settings(game_type: String, map_path: String) -> void:
	GameManager.set_game_type(game_type)
	GameManager.set_map(map_path)
	_sync_settings_ui()

func _broadcast_settings() -> void:
	sync_lobby_settings.rpc(GameManager.get_game_type(), GameManager.get_map())

func _on_player_connected(id: int) -> void:
	EventManager.player_connected.emit(id)
	_update_player_list()
	_check_ready_state()

func _on_player_disconnected(id: int) -> void:
	# GameManager removes the player in its PLAYER_DISCONNECTED handler.
	EventManager.player_disconnected.emit(id, GameManager.get_player(id))
	player_ready_states.erase(id)
	_update_player_list()
	_check_ready_state()

func _on_server_disconnected() -> void:
	_clear_match_results_overlay()
	_free_active_map()
	multiplayer.multiplayer_peer = null
	GameManager.return_to_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## Client -> host: register the sender in the lobby. The id always comes from the
## transport, so a client cannot register (or rename) someone else.
@rpc("any_peer", "reliable")
func request_register(player_name: String, color: Color = Color.WHITE) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var team := GameManager.get_team(id) if GameManager.players.has(id) else TeamRules.pick_team(GameManager.players)
	_store_player(id, player_name, color, team)
	if not player_ready_states.has(id):
		player_ready_states[id] = false

	for player_id in GameManager.players:
		_broadcast_player(player_id)
	sync_lobby_settings.rpc_id(id, GameManager.get_game_type(), GameManager.get_map())
	sync_ready_states.rpc(player_ready_states)
	_update_player_list()

func _broadcast_player(player_id: int) -> void:
	var data: Dictionary = GameManager.get_player(player_id)
	sync_player.rpc(player_id, data.name, data.get("color", Color.WHITE), GameManager.get_team(player_id))

@rpc("authority", "reliable")
func sync_player(id: int, player_name: String, color: Color, team: int) -> void:
	_store_player(id, player_name, color, team)
	_update_player_list()

func _store_player(id: int, player_name: String, color: Color, team: int) -> void:
	var tint := color
	tint.a = 1.0
	if GameManager.players.has(id):
		GameManager.players[id]["name"] = player_name
		GameManager.players[id]["color"] = tint
		GameManager.set_team(id, team)
	else:
		GameManager.add_player(id, {"id": id, "name": player_name, "color": tint, "team": team})

## Any player -> host: move the sender to the other team.
@rpc("any_peer", "call_local", "reliable")
func request_switch_team() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not GameManager.players.has(id):
		return
	GameManager.set_team(id, TeamRules.other_team(GameManager.get_team(id)))
	_broadcast_player(id)
	_update_player_list()

@rpc("authority", "reliable")
func sync_ready_states(states: Dictionary) -> void:
	player_ready_states = states
	_update_player_list()
	_check_ready_state()

## Client -> host: toggle the sender's own ready state.
@rpc("any_peer", "reliable")
func request_set_ready(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	player_ready_states[multiplayer.get_remote_sender_id()] = is_ready
	sync_ready_states.rpc(player_ready_states)
	_update_player_list()
	_check_ready_state()

func _update_player_list() -> void:
	for row in player_rows.get_children():
		player_rows.remove_child(row)
		row.queue_free()
	var team_mode := GameManager.is_team_mode()
	var players := GameManager.get_all_players()
	if team_mode:
		players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return GameManager.get_team(a.id) < GameManager.get_team(b.id))
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for player in players:
		var row: LobbyPlayerRow = PLAYER_ROW_SCENE.instantiate()
		player_rows.add_child(row)
		var team := GameManager.get_team(player.id) if team_mode else -1
		var color: Color = TeamRules.COLORS[team] if team_mode else ScoreTable.player_color(player.id)
		row.show_player(str(player.name), color, team, player.id == 1,
			player_ready_states.get(player.id, false), player.id == my_id)

func _check_ready_state() -> void:
	if not multiplayer.is_server():
		return
	
	var total_players = GameManager.get_player_count()
	if total_players < 2:
		start_button.disabled = false
		return
	
	var ready_count = 0
	for player_id in player_ready_states:
		if player_id != 1 and player_ready_states[player_id]:
			ready_count += 1
	
	if total_players == 2:
		start_button.disabled = false
	else:
		start_button.disabled = ready_count < 1

## Shows another menu tab on top of the lobby (or, from the Esc menu, on top of
## the match). The lobby node stays alive and keeps handling RPCs; it is only
## hidden. The tab sits on its own CanvasLayer so a match camera can't move it.
func open_menu_overlay(scene_path: String) -> Node:
	close_menu_overlay()
	var layer := CanvasLayer.new()
	layer.layer = 95
	var menu: Node = load(scene_path).instantiate()
	layer.add_child(menu)
	_menu_overlay = layer
	get_tree().root.add_child(_menu_overlay)
	hide()
	return menu

func has_menu_overlay() -> bool:
	return is_instance_valid(_menu_overlay)

func is_in_match() -> bool:
	return is_instance_valid(_active_map)

## Leave the session from inside a match (Esc menu). A client simply
## disconnects; the host closing the server sends every client to the menu.
func leave_session() -> void:
	_clear_match_results_overlay()
	close_menu_overlay()
	_free_active_map()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	GameManager.return_to_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func close_menu_overlay() -> void:
	if is_instance_valid(_menu_overlay):
		_menu_overlay.queue_free()
	_menu_overlay = null
	if not is_instance_valid(_active_map):
		show()

## Every peer builds the map itself; `layout_seed` makes slot maps come out
## the same everywhere (see GameMap.build_layout).
@rpc("authority", "call_local", "reliable")
func start_game(map_path: String, layout_seed: int = 0) -> void:
	close_menu_overlay()
	_free_active_map()
	GameManager.map_seed = layout_seed
	
	_active_map = load(map_path).instantiate()
	get_tree().root.add_child(_active_map)
	hide()
	GameManager.start_match()

@rpc("authority", "call_local", "reliable")
func show_match_results(results: Array) -> void:
	_clear_match_results_overlay()
	_halt_map_replication(_active_map)
	
	_match_results_overlay = MATCH_RESULTS_SCENE.instantiate()
	get_tree().root.add_child(_match_results_overlay)
	_match_results_overlay.setup(results)
	_match_results_overlay.continue_pressed.connect(_on_match_results_continue)

@rpc("authority", "call_local", "reliable")
func return_to_lobby() -> void:
	_clear_match_results_overlay()
	_free_active_map()
	
	show()
	_reset_lobby_for_new_match()
	GameManager.return_to_lobby()

func _halt_map_replication(map: Node) -> void:
	if not map or not is_instance_valid(map):
		return
	
	map.process_mode = Node.PROCESS_MODE_DISABLED
	for sync in map.find_children("*", "MultiplayerSynchronizer", true, false):
		if sync is MultiplayerSynchronizer:
			sync.public_visibility = false
			sync.process_mode = Node.PROCESS_MODE_DISABLED

func _free_active_map() -> void:
	if not _active_map or not is_instance_valid(_active_map):
		_active_map = null
		return
	
	var map := _active_map
	_active_map = null
	_halt_map_replication(map)
	
	if map.get_parent():
		map.get_parent().remove_child(map)
	map.queue_free()

func _clear_match_results_overlay() -> void:
	if _match_results_overlay and is_instance_valid(_match_results_overlay):
		_match_results_overlay.queue_free()
		_match_results_overlay = null

func _on_match_results_continue() -> void:
	# Only the host moves everyone back; clients wait for its (identical) auto-continue.
	if multiplayer.is_server():
		return_to_lobby.rpc()

func _reset_lobby_for_new_match() -> void:
	for player_id in GameManager.players:
		player_ready_states[player_id] = player_id == 1
	
	if not multiplayer.is_server():
		ready_button.text = "Ready"
	_sync_settings_ui()
	
	if multiplayer.is_server():
		sync_ready_states.rpc(player_ready_states)
	
	_update_player_list()
	_check_ready_state()

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		_broadcast_settings()
		start_game.rpc(GameManager.get_map(), randi())

func _on_ready_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	var new_ready_state = not player_ready_states.get(player_id, false)
	player_ready_states[player_id] = new_ready_state
	
	ready_button.text = "Unready" if new_ready_state else "Ready"
	
	request_set_ready.rpc_id(1, new_ready_state)

func _on_gametype_dropdown_item_selected(index: int) -> void:
	if multiplayer.is_server() and index >= 0 and index < GAME_TYPES.size():
		GameManager.set_game_type(GAME_TYPES[index][0])
		_broadcast_settings()

func _on_map_dropdown_item_selected(index: int) -> void:
	if multiplayer.is_server() and index >= 0 and index < available_maps.size():
		GameManager.set_map(available_maps[index])
		_broadcast_settings()

func _on_switch_team_pressed() -> void:
	request_switch_team.rpc_id(1)
