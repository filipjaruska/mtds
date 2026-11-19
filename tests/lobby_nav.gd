extends SceneTree
## Headless test: menu tabs opened from a hosted lobby must not destroy it.
##   godot --headless --path . -s res://tests/lobby_nav.gd

var _failures: Array[String] = []
var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("FAIL ", message)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _nav_button(menu: Node, button_name: String) -> Button:
	return menu.get_node("MenuNavBar/HBoxContainer/" + button_name)

func _overlay() -> Node:
	for child in root.get_children():
		if child != current_scene and child.has_node("MenuNavBar"):
			return child
	return null

func _run() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(18735, 4)
	root.multiplayer.multiplayer_peer = peer
	change_scene_to_file("res://src/ui/menus/lobby.tscn")
	await frames(3)

	var lobby := current_scene
	var lobby_play := _nav_button(lobby, "Play")
	check(lobby_play.text == "LOBBY", "play reads LOBBY in a session, got %s" % lobby_play.text)
	check(lobby_play.disabled, "lobby tab is the active one")
	check(_nav_button(lobby, "Tutorial").disabled, "tutorial greyed out in the lobby")

	_nav_button(lobby, "Options").pressed.emit()
	await frames(2)
	var options := _overlay()
	check(options != null, "options opened on top of the lobby")
	check(is_instance_valid(lobby) and lobby.is_inside_tree(), "lobby still alive")
	check(not lobby.visible, "lobby hidden behind options")
	var overlay_play := _nav_button(options, "Play")
	check(overlay_play.text == "LOBBY" and not overlay_play.disabled, "LOBBY tab available from options")
	check(_nav_button(options, "Tutorial").disabled, "tutorial greyed out while in a session")

	_nav_button(options, "Profile").pressed.emit()
	await frames(2)
	var profile := _overlay()
	check(profile != null and profile != options, "switched to profile")
	check(not is_instance_valid(options), "options overlay freed")

	_nav_button(profile, "Play").pressed.emit()
	await frames(2)
	check(_overlay() == null, "overlay closed")
	check(lobby.visible, "back in the lobby")
	check(current_scene == lobby, "same lobby instance")

	print("LOBBY NAV: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
