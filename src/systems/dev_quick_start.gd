extends Node
class_name DevQuickStart
## Editor-only quick start: skips the menus and drops straight into the debug
## map. Works with Godot's "Run Multiple Instances": the first instance hosts
## on DEV_PORT, every other one finds the port taken and joins it. The host
## starts the debug match once players stop joining, and restarts it when
## someone joins later, so every instance ends up in the same match.
##
## Never runs in exported builds. Turn it off with the project setting
## dev/quick_start = false, or launch once with the user argument --menu.

const DEV_PORT := 18080
const DEBUG_MAP := "res://src/scenes/debug.tscn"
const LOBBY_SCENE := "res://src/ui/menus/lobby.tscn"
## Wait this long after the last join before (re)starting the match.
const SETTLE_SECONDS := 2.5
## A dev match runs for an hour instead of the usual five minutes.
const MATCH_SECONDS := 3600.0

var _start_timer: Timer

static func enabled() -> bool:
	return OS.has_feature("editor") \
		and bool(ProjectSettings.get_setting("dev/quick_start", true)) \
		and not OS.get_cmdline_user_args().has("--menu")

## Called by the splash instead of opening the main menu.
static func launch(tree: SceneTree) -> void:
	var boot := DevQuickStart.new()
	boot.name = "DevQuickStart"
	tree.root.add_child.call_deferred(boot)

func _ready() -> void:
	GameManager.game_settings["match_duration_seconds"] = MATCH_SECONDS
	_start_timer = Timer.new()
	_start_timer.one_shot = true
	_start_timer.timeout.connect(_start_debug_match)
	add_child(_start_timer)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(DEV_PORT, GameManager.MAX_PLAYERS - 1) == OK:
		_host(peer)
	else:
		_join()

func _host(peer: ENetMultiplayerPeer) -> void:
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	GameManager.local_player_name = "Dev Host"
	print("[dev] hosting the debug match on port %d" % DEV_PORT)
	multiplayer.peer_connected.connect(func(_id: int) -> void: _start_timer.start(SETTLE_SECONDS))
	get_tree().change_scene_to_file(LOBBY_SCENE)
	_start_timer.start(SETTLE_SECONDS)

func _join() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", DEV_PORT) != OK:
		push_error("DevQuickStart: could not join the dev host on port %d" % DEV_PORT)
		get_tree().change_scene_to_file("res://src/ui/menus/main.tscn")
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		GameManager.local_player_name = "Dev %d" % multiplayer.get_unique_id()
		print("[dev] joined the dev host as %s" % GameManager.local_player_name)
		EventManager.connected_to_host.emit()
		get_tree().change_scene_to_file(LOBBY_SCENE), CONNECT_ONE_SHOT)

## Host: (re)start the debug match with everyone who has joined so far.
func _start_debug_match() -> void:
	var lobby := get_tree().get_first_node_in_group("Lobby")
	if lobby == null:
		_start_timer.start(0.5) # lobby not loaded yet
		return
	GameManager.set_map(DEBUG_MAP)
	print("[dev] starting the debug match with %d player(s)" % GameManager.get_player_count())
	lobby._broadcast_settings()
	lobby.start_game.rpc(DEBUG_MAP)
