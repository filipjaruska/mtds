extends Control

var address: String = "0.0.0.0"
@export var port: int = 8080
@export var connection_timeout: float = 5.0
var peer: ENetMultiplayerPeer
var connection_timer: Timer

@onready var player_name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/LeftPanel/PlayerInfoContainer/HBoxContainer/LineEdit
@onready var address_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/ServerConnectContainer/HBoxContainer/AddressInput
@onready var port_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/ServerConnectContainer/HBoxContainer/PortInput
@onready var join_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/ServerConnectContainer/ButtonContainer/JoinButton
@onready var host_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/ServerConnectContainer/ButtonContainer/HostButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var game_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/GameListContainer/GameList
@onready var refresh_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/RightPanel/GameListContainer/RefreshButton

func _ready() -> void:
	connection_timer = Timer.new()
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	back_button.pressed.connect(_on_back_pressed)
	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	game_list.item_activated.connect(_on_game_selected)
	
	_populate_game_list()

func _on_connected_to_server() -> void:
	if connection_timer and connection_timer.time_left > 0:
		connection_timer.stop()
	
	EventManager.emit_event(EventManager.Events.CONNECTION_SUCCEEDED)
	
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player " + str(multiplayer.get_unique_id())
	
	GameManager.local_player_name = player_name
	
	get_tree().change_scene_to_file("res://src/ui/menus/lobby.tscn")

func _on_connection_failed() -> void:
	if connection_timer and connection_timer.time_left > 0:
		connection_timer.stop()
	
	EventManager.emit_event(EventManager.Events.CONNECTION_FAILED)
	
	multiplayer.multiplayer_peer = null
	_enable_ui()

func _on_connection_timeout() -> void: # Takes too long, so I handle it manually with that timer.
	multiplayer.multiplayer_peer = null
	
	EventManager.emit_event(EventManager.Events.CONNECTION_FAILED)
	_enable_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/main.tscn")

func _on_join_pressed() -> void:
	_join_game()

func _on_host_pressed() -> void:
	_host_game()

func _on_refresh_pressed() -> void:
	_populate_game_list()


func _on_game_selected(index: int) -> void:
	var game_info = _get_game_info(index)
	if game_info:
		address_input.text = game_info.address
		port_input.text = str(game_info.port)

func _join_game() -> void:
	peer = ENetMultiplayerPeer.new()
	
	address = address_input.text.strip_edges()
	if address.to_lower() == "localhost":
		address = "127.0.0.1"
	
	var port_text = port_input.text.strip_edges()
	if port_text.is_empty():
		port = 8080
	else:
		port = port_text.to_int()
	
	if address.is_empty():
		return
	
	if player_name_input.text.strip_edges().is_empty():
		return
	
	var error = peer.create_client(address, port)
	
	if error != OK:
		print("Failed to create client with error: ", error)
		EventManager.emit_event(EventManager.Events.CONNECTION_FAILED)
		_enable_ui()
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	_disable_ui()
	
	connection_timer.start(connection_timeout)
	

func _host_game() -> void:
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		return
	
	var port_text = port_input.text.strip_edges()
	if port_text.is_empty():
		port = 8080
	else:
		port = port_text.to_int()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 4)
	
	if error != OK:
		print("Failed to create server with error: ", error)
		return
	
	if peer.get_host():
		peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	
	GameManager.local_player_name = player_name
	get_tree().change_scene_to_file("res://src/ui/menus/lobby.tscn")

func _disable_ui() -> void:
	player_name_input.editable = false
	address_input.editable = false
	port_input.editable = false
	join_button.disabled = true
	host_button.disabled = true
	refresh_button.disabled = true
	back_button.disabled = true
	game_list.set_deferred("disabled", true)

func _enable_ui() -> void:
	player_name_input.editable = true
	address_input.editable = true
	port_input.editable = true
	join_button.disabled = false
	host_button.disabled = false
	refresh_button.disabled = false
	back_button.disabled = false
	game_list.set_deferred("disabled", false)

func _populate_game_list() -> void:
	game_list.clear()
	var example_games = [ # TODO: fetch from somewhere
		{"name": "Local Server", "address": "localhost", "port": 8080, "players": "0"},
	]
	
	for game in example_games:
		game_list.add_item("%s - %s" % [game.name, game.players + "/4"])

func _get_game_info(index: int) -> Dictionary:
	var example_games = [ # TODO: replace with real data, at some point
		{"name": "Local Server", "address": "localhost", "port": 8080, "players": "0"},
	]
	
	if index >= 0 and index < example_games.size():
		return example_games[index]
	return {}
