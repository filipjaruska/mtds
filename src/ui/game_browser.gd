extends Control
## The Play screen: host a game, or join one by address. A line under the
## buttons says what is happening ("Connecting...", or why it failed).
## The server list is a placeholder until there is a real one (see GAMES).

## Listed games. Placeholder: replace with a real server list.
const GAMES := [
	{"name": "Local Server", "address": "localhost", "port": 8080},
]

@export var default_port: int = 8080
## Seconds to wait for the host before giving up (ENet's own timeout is ~30 s).
@export var connection_timeout: float = 5.0

var peer: ENetMultiplayerPeer
var _connection_timer: Timer

@onready var player_name_input: LineEdit = %NameInput
@onready var address_input: LineEdit = %AddressInput
@onready var port_input: LineEdit = %PortInput
@onready var join_button: Button = %JoinButton
@onready var host_button: Button = %HostButton
@onready var game_list: ItemList = %GameList
@onready var refresh_button: Button = %RefreshButton
@onready var status_label: Label = %StatusLabel
@onready var nav_bar: MenuNavBar = $MenuNavBar

func _ready() -> void:
	_connection_timer = Timer.new()
	_connection_timer.one_shot = true
	_connection_timer.timeout.connect(_on_connection_timeout)
	add_child(_connection_timer)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	join_button.pressed.connect(_join_game)
	host_button.pressed.connect(_host_game)
	refresh_button.pressed.connect(_populate_game_list)
	game_list.item_activated.connect(_on_game_selected)

	_show_status("")
	_populate_game_list()

func _join_game() -> void:
	var address := address_input.text.strip_edges()
	if address.to_lower() == "localhost":
		address = "127.0.0.1"
	if address.is_empty():
		_show_status("Enter the host's address first.", true)
		return
	if player_name_input.text.strip_edges().is_empty():
		_show_status("Enter a name first.", true)
		return
	var port := _port()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_fail("Couldn't start connecting to %s:%d (%s)." % [address, port, error_string(error)])
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	_set_ui_enabled(false)
	_show_status("Connecting to %s:%d..." % [address, port])
	_connection_timer.start(connection_timeout)

func _host_game() -> void:
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		_show_status("Enter a name first.", true)
		return
	var port := _port()
	peer = ENetMultiplayerPeer.new()
	# ENet counts clients only; the host is the remaining player.
	var error := peer.create_server(port, GameManager.MAX_PLAYERS - 1)
	if error != OK:
		var reason := "the port is probably in use" if error == ERR_CANT_CREATE else error_string(error)
		_show_status("Couldn't host on port %d: %s." % [port, reason], true)
		return
	if peer.get_host():
		peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	GameManager.local_player_name = player_name
	get_tree().change_scene_to_file("res://src/ui/menus/lobby.tscn")

func _on_connected_to_server() -> void:
	_connection_timer.stop()
	EventManager.connected_to_host.emit()
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player %d" % multiplayer.get_unique_id()
	GameManager.local_player_name = player_name
	get_tree().change_scene_to_file("res://src/ui/menus/lobby.tscn")

func _on_connection_failed() -> void:
	_connection_timer.stop()
	_fail("Couldn't reach the host. Check the address and port, and that the game is hosted.")

func _on_connection_timeout() -> void:
	_fail("No answer from the host after %d s." % int(connection_timeout))

func _fail(message: String) -> void:
	multiplayer.multiplayer_peer = null
	EventManager.connection_failed.emit()
	_set_ui_enabled(true)
	_show_status(message, true)

func _show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.visible = message != ""
	status_label.add_theme_color_override("font_color", UiPalette.BAD.lightened(0.25) if is_error else UiPalette.TEXT_DIM)

func _port() -> int:
	var text := port_input.text.strip_edges()
	return text.to_int() if text.is_valid_int() else default_port

func _set_ui_enabled(enabled: bool) -> void:
	player_name_input.editable = enabled
	address_input.editable = enabled
	port_input.editable = enabled
	join_button.disabled = not enabled
	host_button.disabled = not enabled
	refresh_button.disabled = not enabled
	nav_bar.set_navigation_enabled(enabled)
	game_list.set_deferred("disabled", not enabled)

func _populate_game_list() -> void:
	game_list.clear()
	for game in GAMES:
		game_list.add_item("%s - %s:%d" % [game.name, game.address, game.port])

func _on_game_selected(index: int) -> void:
	if index < 0 or index >= GAMES.size():
		return
	address_input.text = GAMES[index].address
	port_input.text = str(GAMES[index].port)
