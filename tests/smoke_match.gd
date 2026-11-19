extends SceneTree
## Headless smoke test: hosts a match on the debug map and drives the local
## player through real input actions.
##   godot --headless --path . -s res://tests/smoke_match.gd

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
		await physics_frame
		await process_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)

func _run() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(18733, 4)
	root.multiplayer.multiplayer_peer = peer

	var game_manager = root.get_node("GameManager")
	game_manager.add_player(1, {"id": 1, "name": "Host", "color": Color.WHITE})
	var map: Node = load("res://src/scenes/debug.tscn").instantiate()
	root.add_child(map)
	await frames(5)

	var player: Node2D = map.get_node("1")
	var holder = player.get_weapon_holder()
	var primary := LoadoutRules.active(holder.loadout)
	check(primary.get("def") == &"pistol", "starts with pistol, got %s" % primary)
	check(primary.get("ammo") == 16, "pistol full")

	# Fire one shot.
	await tap("shoot")
	check(LoadoutRules.active(holder.loadout).ammo == 15, "one shot fired, ammo=%s" % LoadoutRules.active(holder.loadout).ammo)
	check(player.get_player_controller().slowness_factor < 1.0, "firing slows movement")

	# Reload.
	await tap("reload")
	check(WeaponRules.is_reloading(LoadoutRules.active(holder.loadout), Time.get_ticks_msec()), "reload started")

	# Walk onto the shotgun pickup and take it.
	var pickup: Node2D = map.get_node("WeaponPickup2")
	player.global_position = pickup.global_position
	await frames(4)
	await tap("interact")
	await frames(3)
	check(LoadoutRules.active(holder.loadout).def == &"shotgun", "picked up shotgun, loadout=%s" % [holder.loadout.slots])
	check(holder.loadout.slots.size() == 2, "two weapons carried")
	check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "pickup despawned")

	# Drop it again: a named pickup appears under the map.
	await tap("ui_drop_weapon")
	await frames(3)
	check(holder.loadout.slots.size() == 1, "shotgun dropped")
	check(map.has_node("DroppedWeapon_1"), "dropped pickup spawned under map")

	# Death resets to the default weapon and drops the extra one.
	player.global_position = map.get_node("DroppedWeapon_1").global_position
	await frames(4)
	await tap("interact")
	await frames(3)
	check(holder.has_weapon(&"shotgun"), "picked shotgun back up")
	holder.reset_on_death()
	await frames(3)
	check(holder.loadout.slots.size() == 1 and LoadoutRules.active(holder.loadout).def == &"pistol", "reset to pistol on death")
	check(map.has_node("DroppedWeapon_2"), "death dropped the shotgun")

	print("SMOKE: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
