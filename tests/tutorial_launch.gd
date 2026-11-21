extends SceneTree
## Tutorial from the main menu: one click, no hosting/joining, straight into the
## map; signs show real key bindings; targets take hits; Esc -> Leave tutorial
## returns to the menu.
##   godot --headless --path . -s res://tests/tutorial_launch.gd

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

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	change_scene_to_file("res://src/ui/menus/main.tscn")
	await frames(5)
	current_scene.get_node("MenuNavBar/HBoxContainer/Tutorial").pressed.emit()
	await frames(15)

	var map: Node = root.get_node_or_null("Tutorial")
	check(map != null, "the tutorial map is running")
	check(root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no hosting or joining")
	check(gm.tutorial_mode and gm.is_state(gm.GameState.PLAYING), "tutorial session playing")
	if map == null:
		quit(1)
		return
	var player: Node2D = map.get_node_or_null("1")
	check(player != null and player.global_position == map.get_node("SpawnLocations/0").global_position, "player spawned at the start")
	var sign_text: String = map.get_node("Signs/Sign1").text
	check(not sign_text.contains("{") and sign_text.contains("["), "signs show key bindings: " + sign_text.split("\n")[0])

	# Shoot the first target in the shooting room.
	var target: Node2D = map.get_node("Targets/Target1")
	player.global_position = target.global_position + Vector2(-250, 0)
	await physics_frame
	await physics_frame
	map.get_node("Combat").fire(player, player.global_position, PackedFloat32Array([0.0]), &"pistol", 650.0)
	await create_timer(0.4).timeout # the bullet has to fly there first
	check(target.hp < target.MAX_HP, "a shot damages the target (hp %.0f)" % target.hp)

	var menu = current_scene.get_children().filter(func(c): return c is CanvasLayer and c.has_method("is_open"))[0]
	menu._set_open(true)
	check(not menu._end_match.visible and menu._leave.text == "Leave tutorial", "Esc menu fits the tutorial")
	menu._on_leave()
	menu._on_leave()
	await frames(10)
	check(current_scene != null and current_scene.scene_file_path.ends_with("main.tscn"), "back in the main menu")
	check(not gm.tutorial_mode and is_equal_approx(gm.get_match_duration(), 300.0), "normal match settings restored")

	print("TUTORIAL CHECK: %d failures" % _fails)
	quit(1 if _fails else 0)
