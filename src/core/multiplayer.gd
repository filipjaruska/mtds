extends Control
var address: String = "0.0.0.0"
@export var port: int = 8080
@export var max_players: int = 4
var peer: ENetMultiplayerPeer

@onready var player_name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var address_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit2
@onready var port_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit3
@onready var start_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Start
@onready var host_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Host
@onready var join_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/Join
@onready var player_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ItemList

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	if "--server" in OS.get_cmdline_args():
		host_game()

func _on_player_connected(id: int) -> void:
	print("Player connected with ID: ", id) # TODO: rm later
	EventManager.emit_event(EventManager.Events.PLAYER_CONNECTED, [id])

func _on_player_disconnected(id: int) -> void:
	print("Player disconnected with ID: ", id) # TODO: rm later
	var player_data = GameManager.get_player(id)
	EventManager.emit_event(EventManager.Events.PLAYER_DISCONNECTED, [id, player_data])
	
	GameManager.remove_player(id)
	
	for player in get_tree().get_nodes_in_group("Player"):
		if player.name == str(id):
			player.queue_free()

func _on_connected_to_server() -> void:
	EventManager.emit_event(EventManager.Events.CONNECTION_SUCCEEDED)
	
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player " + str(multiplayer.get_unique_id())
	
	send_player.rpc_id(1, multiplayer.get_unique_id(), player_name)

func _on_connection_failed() -> void:
	EventManager.emit_event(EventManager.Events.CONNECTION_FAILED)
	_enable_ui()

## RPC method to synchronize player data between clients
@rpc("any_peer")
func send_player(id: int, player_name: String) -> void:
	if not GameManager.players.has(id):
		GameManager.add_player(id, {"id": id, "name": player_name})
	
	if multiplayer.is_server():
		for player_id in GameManager.players:
			var player_data = GameManager.get_player(player_id)
			send_player.rpc(player_id, player_data.name)
	
	_update_player_list()
	print("Current players: ", GameManager.players)

func _update_player_list() -> void:
	player_list.clear()
	for player in GameManager.get_all_players():
		player_list.add_item(player.name)

## RPC method to transition all clients to the main game scene
@rpc("any_peer", "call_local")
func start_game() -> void:
	print("Starting game...")
	var scene: Node = load("res://nodes/scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()
	
	GameManager.start_game()

## Creates a new server instance and starts listening for connections
func host_game() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	
	if error != OK:
		print("Server creation failed with error: ", error)
		_enable_ui()
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	print("Server started on port ", port, " with max ", max_players, " players")

## UI Event Handlers ##
func _on_start_pressed() -> void:
	if multiplayer.is_server():
		start_game.rpc()
	else:
		print("Only the host can start the game")

func _on_host_pressed() -> void:
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Host"
	
	host_game()
	
	send_player(multiplayer.get_unique_id(), player_name)
	_disable_ui()

func _on_join_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	
	address = address_input.text.strip_edges()
	if address.to_lower() == "localhost":
		address = "127.0.0.1"
	
	var port_text = port_input.text.strip_edges()
	if port_text.is_empty():
		port = 8080
	else:
		port = port_text.to_int()
	
	if address.is_empty(): # TODO: error handling ui
		return
	
	var error = peer.create_client(address, port)
	
	if error != OK:
		EventManager.emit_event(EventManager.Events.CONNECTION_FAILED)
		_enable_ui()
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	_disable_ui()

func _disable_ui() -> void:
	start_button.disabled = false
	player_name_input.editable = false
	address_input.editable = false
	port_input.editable = false
	host_button.visible = false
	join_button.visible = false

func _enable_ui() -> void:
	start_button.disabled = true
	player_name_input.editable = true
	address_input.editable = true
	port_input.editable = true
	host_button.visible = true
	join_button.visible = true
