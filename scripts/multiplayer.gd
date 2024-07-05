extends Control

var address: String = "0.0.0.0"
@export var port: int = 8080
var peer

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	if "--server" in OS.get_cmdline_args():
		host_game()

func _on_player_connected(id: int):
	print("Player connected: ", id)

func _on_player_disconnected(id: int):
	print("Player disconnected: ", id)
	GameManager.players.erase(id)
	for player in get_tree().get_nodes_in_group("Player"):
		if player.name == str(id):
			player.queue_free()

func _on_connected_to_server():
	send_player.rpc_id(
		1,
		multiplayer.get_unique_id(),
		$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit.text
	)

@rpc("any_peer")
func send_player(id: int, name):
	if not GameManager.players.has(id):
		GameManager.players[id] = {"id": id, "name": name}
	
	if multiplayer.is_server():
		for player_id in GameManager.players:
			send_player.rpc(player_id, GameManager.players[player_id].name)

	_update_player_list()
	print("Current players: ", GameManager.players)

func _update_player_list():
	var item_list = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ItemList
	item_list.clear()
	for player in GameManager.players.values():
		item_list.add_item(player.name)

@rpc("any_peer", "call_local")
func start_game():
	var scene: Node = load("res://nodes/scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 4)
	if error != OK:
		print("Server creation failed: ", error)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_start_pressed():
	start_game.rpc()

func _on_host_pressed():
	host_game()
	send_player(
		multiplayer.get_unique_id(),
		$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit.text
	)
	_disable_ui()

func _on_join_pressed():
	peer = ENetMultiplayerPeer.new()
	address = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit2.text.strip_edges()
	if address.to_lower() == "localhost":
		address = "127.0.0.1"
	port = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit3.text.strip_edges().to_int()
	peer.create_client(address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	_disable_ui()

func _disable_ui():
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Start.disabled = false
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/LineEdit.editable = false
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit2.editable = false	
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit3.editable = false
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Host.visible = false
	$MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/Join.visible = false
