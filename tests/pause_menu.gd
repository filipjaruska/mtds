extends SceneTree
## Esc menu in a hosted match: open/close, input muted, Options on top and back,
## End match, and Leave (twice) back to the main menu.
##   godot --headless --path . -s res://tests/pause_menu.gd
var _started := false
var _fails := 0

func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func check(ok: bool, msg: String) -> void:
	print(("ok    " if ok else "FAIL  ") + msg)
	if not ok:
		_fails += 1

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

func esc() -> void:
	var event := InputEventAction.new()
	event.action = "pause_menu"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	var up := InputEventAction.new()
	up.action = "pause_menu"
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)

func _run() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(18742, 8)
	root.multiplayer.multiplayer_peer = peer
	root.get_node("GameManager").local_player_name = "Host"
	change_scene_to_file("res://src/ui/menus/lobby.tscn")
	await frames(10)
	var lobby = current_scene
	var menu = lobby.get_children().filter(func(c): return c is CanvasLayer and c.has_method("is_open"))[0]
	var input = root.get_node("InputManager")

	await esc()
	check(not menu.is_open(), "Esc does nothing in the lobby")

	lobby.start_game("res://tests/maps/test_arena.tscn")
	await frames(10)
	await esc()
	check(menu.is_open(), "Esc opens the menu in a match")
	check(input.menu_open and not input.is_shoot_pressed(), "gameplay input muted")

	menu._on_options()
	await frames(5)
	check(lobby.has_menu_overlay() and lobby._menu_overlay is CanvasLayer, "Options opens on its own layer")
	check(not lobby.visible, "lobby stays hidden in the match")
	var options: Node = lobby._menu_overlay.get_child(0)
	check(not options.get_node("%MenuNavBar").visible and options.get_node("%BackButton").visible, "in-match Options: no tab bar, a Back button")
	await esc()
	check(not lobby.has_menu_overlay() and menu.is_open() and menu._panel.visible, "Esc in Options goes back to the menu")
	menu._on_options()
	await frames(5)
	lobby._menu_overlay.get_child(0).get_node("%BackButton").pressed.emit()
	await frames(2)
	check(not lobby.has_menu_overlay() and menu.is_open() and menu._panel.visible, "Back in Options goes back to the menu")

	await esc()
	check(not menu.is_open() and not input.menu_open, "Esc again resumes")

	await esc()
	menu._on_end_match()
	await frames(10)
	check(root.get_node("GameManager").is_state(root.get_node("GameManager").GameState.GAME_OVER), "host can end the match")
	lobby.return_to_lobby()
	await frames(5)

	lobby.start_game("res://tests/maps/test_arena.tscn")
	await frames(10)
	await esc()
	menu._on_leave()
	check(current_scene == lobby and lobby.is_in_match(), "first Leave click only asks to confirm")
	menu._on_leave()
	await frames(10)
	check(current_scene != null and current_scene.scene_file_path.ends_with("main.tscn"), "second click leaves to the main menu (%s)" % [current_scene.scene_file_path if current_scene else "none"])
	check(root.multiplayer.multiplayer_peer == null or root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "disconnected")
	check(not input.menu_open, "input no longer muted")

	print("PAUSE CHECK: %d failures" % _fails)
	quit(1 if _fails else 0)
