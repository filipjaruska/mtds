extends Control

var available_maps: Array[String] = []
var player_ready_states: Dictionary = {}

@onready var player_name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel/PlayerInfoContainer/HBoxContainer/LineEdit
@onready var start_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel/ButtonsContainer/StartButton
@onready var ready_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel/ButtonsContainer/ReadyButton
@onready var player_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/PlayerListContainer/PlayerList
@onready var map_dropdown: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel/MapSelectionContainer/MapDropdown

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	var player_name = GameManager.local_player_name
	if player_name.is_empty():
		player_name = "Player " + str(multiplayer.get_unique_id())
	player_name_input.text = player_name
	player_name_input.editable = false
	
	_load_available_maps()
	_setup_ui_for_role()
	
	if multiplayer.get_unique_id() != 1:
		send_player.rpc_id(1, multiplayer.get_unique_id(), player_name)
	else:
		GameManager.add_player(1, {"id": 1, "name": player_name})
		player_ready_states[1] = true
		_update_player_list()

func _setup_ui_for_role() -> void:
	if multiplayer.is_server():
		start_button.visible = true
		start_button.disabled = false
		ready_button.visible = false
		map_dropdown.disabled = false
	else:
		start_button.visible = false
		ready_button.visible = true
		ready_button.disabled = false
		map_dropdown.disabled = true
		player_ready_states[multiplayer.get_unique_id()] = false

func _load_available_maps() -> void:
	map_dropdown.clear()
	
	available_maps.append("../debug.tscn")
	map_dropdown.add_item("debug")
	
	var maps_dir = "res://src/scenes/maps/"
	var dir = DirAccess.open(maps_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				available_maps.append(file_name)
				map_dropdown.add_item(file_name.trim_suffix(".tscn"))
			file_name = dir.get_next()
		dir.list_dir_end()
	
	map_dropdown.select(0)

func _on_player_connected(_id: int) -> void:
	_update_player_list()
	_check_ready_state()

func _on_player_disconnected(id: int) -> void:
	GameManager.remove_player(id)
	player_ready_states.erase(id)
	_update_player_list()
	_check_ready_state()

@rpc("any_peer")
func send_player(id: int, player_name: String) -> void:
	if not GameManager.players.has(id):
		GameManager.add_player(id, {"id": id, "name": player_name})
		player_ready_states[id] = false
	
	if multiplayer.is_server():
		for player_id in GameManager.players:
			var player_data = GameManager.get_player(player_id)
			send_player.rpc(player_id, player_data.name)
		sync_ready_states.rpc(player_ready_states)
	
	_update_player_list()

@rpc("any_peer")
func sync_ready_states(states: Dictionary) -> void:
	player_ready_states = states
	_update_player_list()
	_check_ready_state()

@rpc("any_peer")
func set_player_ready(player_id: int, is_ready: bool) -> void:
	player_ready_states[player_id] = is_ready
	_update_player_list()
	_check_ready_state()

func _update_player_list() -> void:
	player_list.clear()
	for player in GameManager.get_all_players():
		var ready_status = " [READY]" if player_ready_states.get(player.id, false) else ""
		var host_status = " (Host)" if player.id == 1 else ""
		player_list.add_item(player.name + host_status + ready_status)

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

@rpc("any_peer", "call_local")
func start_game(map_name: String) -> void:
	var map_path = "res://src/scenes/maps/" + map_name
	var scene: Node = load(map_path).instantiate()
	get_tree().root.add_child(scene)
	self.hide()
	
	GameManager.start_game()

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		var selected_map = available_maps[map_dropdown.selected]
		start_game.rpc(selected_map)

func _on_ready_pressed() -> void:
	var player_id = multiplayer.get_unique_id()
	var new_ready_state = not player_ready_states.get(player_id, false)
	player_ready_states[player_id] = new_ready_state
	
	ready_button.text = "Unready" if new_ready_state else "Ready"
	
	set_player_ready.rpc(player_id, new_ready_state)
