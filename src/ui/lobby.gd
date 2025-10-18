extends Control

@onready var player_name_input: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var start_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Start
@onready var player_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ItemList

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	var player_name = GameManager.local_player_name
	if player_name.is_empty():
		player_name = "Player " + str(multiplayer.get_unique_id())
	player_name_input.text = player_name
	player_name_input.editable = false
	
	start_button.disabled = not multiplayer.is_server()
	
	if multiplayer.get_unique_id() != 1:
		send_player.rpc_id(1, multiplayer.get_unique_id(), player_name)
	else:
		GameManager.add_player(1, {"id": 1, "name": player_name})
		_update_player_list()

func _on_player_connected(_id: int) -> void:
	_update_player_list()

func _on_player_disconnected(id: int) -> void:
	GameManager.remove_player(id)
	_update_player_list()

@rpc("any_peer")
func send_player(id: int, player_name: String) -> void:
	if not GameManager.players.has(id):
		GameManager.add_player(id, {"id": id, "name": player_name})
	
	if multiplayer.is_server():
		for player_id in GameManager.players:
			var player_data = GameManager.get_player(player_id)
			send_player.rpc(player_id, player_data.name)
	
	_update_player_list()

func _update_player_list() -> void:
	player_list.clear()
	for player in GameManager.get_all_players():
		player_list.add_item(player.name)

@rpc("any_peer", "call_local")
func start_game() -> void:
	var scene: Node = load("uid://n36pcq02ew6").instantiate()
	get_tree().root.add_child(scene)
	self.hide()
	
	GameManager.start_game()

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		start_game.rpc()
