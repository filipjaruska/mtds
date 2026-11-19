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
	await _powerups(map, player, holder)

	print("SMOKE: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)

func wait_until(condition: Callable, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false

func _collect(map: Node, player: Node2D, spawner_name: String) -> bool:
	var found := await wait_until(func(): return _pickup_of(map, spawner_name) != null, 5.0)
	if not found:
		return false
	player.global_position = _pickup_of(map, spawner_name).global_position
	await frames(4)
	await tap("interact")
	await frames(3)
	return true

func _pickup_of(map: Node, spawner_name: String) -> Node2D:
	for child in map.get_children():
		if String(child.name).begins_with("Powerup_%s_" % spawner_name):
			return child
	return null

func _powerups(map: Node, player: Node2D, holder) -> void:
	var pm = player.get_node("PowerupManager")
	
	# Dual Wield (PowerupSpawner2): collect, use, empty both magazines.
	check(await _collect(map, player, "PowerupSpawner2"), "dual wield pickup spawned")
	check(pm.inventory[0].def == &"dual_wield", "dual wield in slot 1, inventory=%s" % [pm.inventory])
	await wait_until(func(): return not WeaponRules.is_reloading(LoadoutRules.active(holder.loadout), Time.get_ticks_msec()), 3.0)
	await tap("powerup_slot_1")
	check(LoadoutRules.is_dual(holder.loadout), "dual wield enabled by the powerup")
	check(holder.loadout.offhand.get("def") == &"pistol", "off hand mirrors the pistol")
	Input.action_press("shoot")
	await wait_until(func(): return not LoadoutRules.is_dual(holder.loadout), 25.0)
	Input.action_release("shoot")
	check(not LoadoutRules.is_dual(holder.loadout), "dual ends when both magazines are empty")
	check(PowerupRules.entry_with_ability(pm.active, &"dual_wield").is_empty(), "dual powerup expired with it")
	
	# Burst (PowerupSpawner3): one trigger pull empties the magazine.
	await tap("reload")
	await wait_until(func(): return LoadoutRules.active(holder.loadout).ammo == 16, 3.0)
	check(await _collect(map, player, "PowerupSpawner3"), "burst pickup spawned")
	await tap("powerup_slot_1")
	check(not PowerupRules.entry_with_ability(pm.active, &"burst").is_empty(), "burst active")
	await tap("shoot")
	check(await wait_until(func(): return LoadoutRules.active(holder.loadout).ammo == 0, 3.0), "burst emptied the magazine, ammo=%s" % LoadoutRules.active(holder.loadout).ammo)
	check(await wait_until(func(): return PowerupRules.entry_with_ability(pm.active, &"burst").is_empty(), 1.0), "burst used up")
	
	# Stat powerups are derived, not mutated: they apply and vanish cleanly.
	pm._sync_activate.rpc(&"damage_boost", 1)
	check(is_equal_approx(holder.stats_for(&"pistol").damage, 12.0), "damage boost applies")
	pm.expire(&"damage_boost")
	check(is_equal_approx(holder.stats_for(&"pistol").damage, 10.0), "damage back to base")
	
	var health = player.get_health_component()
	pm._sync_activate.rpc(&"health_boost", 1)
	check(is_equal_approx(health.max_health, 125.0), "health boost raises max health, got %s" % health.max_health)
	pm.expire(&"health_boost")
	check(is_equal_approx(health.max_health, 100.0), "max health back to base")
	print("powerup scenarios done, dual/burst/boosts checked")
