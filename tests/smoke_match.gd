extends SceneTree
## Headless smoke test: hosts a match on the test arena (tests/maps/) and
## drives the local player through real input actions. The arena belongs to
## the tests, so editing game maps cannot break this.
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
	var map: Node = load("res://tests/maps/test_arena.tscn").instantiate()
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
	var pickup: Node2D = map.get_node("ShotgunPickup")
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
	await _event_blocks(map, player, holder)
	await _shady_fella(map, player)
	map.free()
	await frames(2)
	await _blackjack(game_manager)
	await _tutankhamun(game_manager)

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
	
	# Dual Wield: collect, use, empty both magazines.
	check(await _collect(map, player, "DualSpawner"), "dual wield pickup spawned")
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
	
	# Burst: one trigger pull empties the magazine.
	await tap("reload")
	await wait_until(func(): return LoadoutRules.active(holder.loadout).ammo == 16, 3.0)
	check(await _collect(map, player, "BurstSpawner"), "burst pickup spawned")
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

## What events are built from: cards the host gives and takes, cards dropped
## on the map, and no-fighting zones.
func _event_blocks(map: Node, player: Node2D, holder) -> void:
	var pm = player.get_node("PowerupManager")
	pm.take_all_cards.rpc_id(1)
	await frames(2)
	check(pm.hand_ids.is_empty(), "host sees the empty hand: %s" % [pm.hand_ids])
	pm.grant_card.rpc_id(1, &"armor")
	await frames(2)
	check(pm.inventory[0].def == &"armor", "the host gave a card, inventory=%s" % [pm.inventory])
	check(pm.hand_ids == ([&"armor"] as Array[StringName]), "the host knows the hand: %s" % [pm.hand_ids])
	pm.take_all_cards.rpc_id(1)
	await frames(2)
	check(pm.get_used_inventory_slots() == 0 and pm.hand_ids.is_empty(), "the host took the cards")

	map.spawn_card_pickup(&"damage_boost", player.global_position + Vector2(300, 0))
	await frames(2)
	check(map.has_node("DroppedCard_1"), "a dropped card lies on the map")

	# A no-fighting zone round the player: the trigger does nothing, cards stay in hand.
	var zone := PeaceZone.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 200.0
	zone.add_child(shape)
	zone.position = player.global_position
	map.add_child(zone)
	await frames(4)
	check(PeaceZone.covers(player), "the player stands in the zone")
	await wait_until(func(): return not WeaponRules.is_reloading(LoadoutRules.active(holder.loadout), Time.get_ticks_msec()), 3.0)
	await tap("reload")
	var full := await wait_until(func(): return LoadoutRules.active(holder.loadout).ammo == 16, 4.0)
	check(full, "reloading works in the zone")
	await tap("shoot")
	check(LoadoutRules.active(holder.loadout).ammo == 16, "no shooting in the zone, ammo=%s" % LoadoutRules.active(holder.loadout).ammo)
	pm.grant_card.rpc_id(1, &"armor")
	await frames(2)
	await tap("powerup_slot_1")
	check(pm.inventory[0].def == &"armor", "no cards played in the zone")
	var health = player.get_health_component()
	var before: float = health.current_health
	health.apply_damage(30.0, 0.0, 99)
	check(health.current_health == before, "nobody gets hurt by players in the zone")
	zone.active = false
	await tap("shoot")
	check(LoadoutRules.active(holder.loadout).ammo == 15, "shooting again once the zone is off")
	zone.queue_free()

## Shady Fella: trade with him, one card each, shoot him and he drops a card and runs.
func _shady_fella(map: Node, player: Node2D) -> void:
	var pm = player.get_node("PowerupManager")
	var input_manager = root.get_node("InputManager")
	pm.take_all_cards.rpc_id(1)
	var director = map.get_node("Events") # untyped: the script loads before the autoloads
	director.start_now(0)
	await frames(3)
	var event = director.get_node_or_null("Event_1")
	check(event != null, "Shady Fella appeared")
	if event == null:
		return
	check(event.offer.size() == 3, "he offers 3 cards: %s" % [event.offer])
	var fella: Node2D = event.fella
	player.global_position = fella.global_position + Vector2(70, 0)
	await frames(5)
	await tap("interact")
	await frames(3)
	check(input_manager.choosing_card, "the trade opened")
	check(event.state == ShadyFellaRules.State.BUSY, "he waits while you choose")
	var first: StringName = event.offer[0]
	await tap("powerup_slot_1")
	await frames(4)
	check(pm.inventory[0].def == first, "got the card I picked: %s, hand %s" % [first, pm.inventory])
	check(event.offer.size() == 2 and not event.offer.has(first), "he has the other two left")
	check(not input_manager.choosing_card, "the trade closed")
	await tap("interact")
	await frames(3)
	check(not input_manager.choosing_card, "one card each")

	# Shoot him: a card drops where he stands, he runs off and is gone.
	player.global_position = fella.global_position + Vector2(-250, 0)
	await frames(3)
	var dropped_before := map.get_children().filter(func(c): return String(c.name).begins_with("DroppedCard_")).size()
	map.get_node("Combat").fire(player, player.global_position, PackedFloat32Array([0.0]), &"pistol", 600.0)
	check(await wait_until(func(): return event.state == ShadyFellaRules.State.FLEEING, 2.0), "shot: he runs")
	var dropped_after := map.get_children().filter(func(c): return String(c.name).begins_with("DroppedCard_")).size()
	check(dropped_after == dropped_before + 1, "one of his cards dropped")
	check(await wait_until(func(): return not is_instance_valid(event), 6.0), "and he is gone")
	check(director.active.is_empty(), "no event running")

## The blackjack room on its own test map: opens, locks the player in, deals,
## keeps or takes the cards, sends the player out, and stays open afterwards.
func _blackjack(game_manager) -> void:
	game_manager.map_seed = 3
	var map: Node = load("res://tests/maps/events_test.tscn").instantiate()
	root.add_child(map)
	await frames(5)
	var player: Node2D = map.get_node("1")
	var director = map.get_node("Events")
	var room = map.get_node("Rooms/BlackjackRoom")
	check(room.is_closed(), "the blackjack room starts closed")
	check(not room.gates.is_empty(), "with gates in its doorways")
	director.start_now(0)
	await frames(3)
	var event = director.get_node_or_null("Event_1")
	check(event != null and event.table != null, "the blackjack event found its room and table")
	if event == null or event.table == null:
		return
	check(not room.is_closed(), "the doors open")
	var area: Rect2 = event.room_area()
	player.global_position = area.get_center() + Vector2(0, 220)
	var pm = player.get_node("PowerupManager")
	check(pm.get_used_inventory_slots() == 0, "the player comes with no cards")
	check(not map.get_node("CardDrops/CardsBlackjack").enabled, "no cards in the room before the game")
	await frames(4)
	check(PeaceZone.covers(player), "no fighting in the room")
	event.lock_now()
	check(await wait_until(func(): return event.phase == event.Phase.PLAYING, 2.0), "the doors shut and the game starts")
	check(room.is_closed(), "locked in")
	check(event.seated == ([1] as Array[int]), "the player sits at the table: %s" % [event.seated])
	await frames(3)
	var seat: Vector2 = event.table.seats()[event.seats[0]].global_position
	check(player.global_position.distance_to(seat) < 2.0, "moved to the seat")
	check(pm.get_used_inventory_slots() > 0, "given a stake: %s" % [pm.inventory])
	check(await wait_until(func(): return event.phase == event.Phase.RESULT, 20.0), "the result is in")
	await frames(3)
	var won: bool = event.results[0]
	check((pm.get_used_inventory_slots() > 0) == won, "won keeps the cards, lost loses them (won=%s, hand %s)" % [won, pm.inventory])
	var table = event.table
	check(await wait_until(func(): return not is_instance_valid(event), 10.0), "the event ends")
	await frames(3)
	check(not area.has_point(player.global_position), "sent back out: %s" % player.global_position)
	check(not is_instance_valid(table), "the table is gone")
	check(not room.is_closed() and room.gates.all(func(g): return g.is_open()), "the room stays open")
	var cards = map.get_node("CardDrops")
	check(await wait_until(func(): return cards.get_children().any(func(c): return String(c.name).begins_with("Powerup_CardsBlackjack_")), 4.0), "a card turns up in the room afterwards")
	check(not director._can_run(0), "once per match")
	map.free()

## Tutankhamun on the events test map: wakes in his tomb, shoots fire that
## burns, stays in his tomb until his time is up, and drops his staff and a
## card when killed. His staff costs health, not ammo.
func _tutankhamun(game_manager) -> void:
	game_manager.map_seed = 3
	var map: Node = load("res://tests/maps/events_test.tscn").instantiate()
	root.add_child(map)
	await frames(5)
	var player: Node2D = map.get_node("1")
	var health = player.get_health_component()
	var director = map.get_node("Events")
	director.start_now(1)
	await frames(3)
	var event = director.get_node_or_null("Event_1")
	check(event != null and event.sarcophagus != null, "Tutankhamun found his sarcophagus")
	if event == null or event.sarcophagus == null:
		map.free()
		return
	check(event.body.visible and event.sarcophagus.opened, "he wakes and the lid comes off")
	check(event.state == TutankhamunRules.State.BOUND, "held in his tomb")
	player.global_position = event.body.global_position + Vector2(-260, 0)
	check(await wait_until(func(): return health.current_health < 100.0, 4.0), "his fireball hit the player")
	check(health.is_burning(), "and set them burning")
	# Out of his sight: the burn keeps hurting for a while.
	player.global_position = Vector2(-2000, -2000)
	var after_hit: float = health.current_health
	await wait_until(func(): return false, 1.2)
	check(health.current_health < after_hit, "burning keeps hurting (%s -> %s)" % [after_hit, health.current_health])
	check(event.tomb.has_point(event.body.global_position), "still in his tomb")
	event.free_at_msec = 0
	check(await wait_until(func(): return event.state == TutankhamunRules.State.ROAMING, 2.0), "free after his time in the tomb")
	var where: Vector2 = event.body.global_position
	event.body.take_hit(10000.0, 1)
	await frames(3)
	check(event.state == TutankhamunRules.State.DEAD, "killed")
	var staff_pickup: Node2D = null
	var card_pickup: Node2D = null
	for child in map.get_children():
		if String(child.name).begins_with("DroppedWeapon_") and child.weapon_def.id == &"pharaoh_staff":
			staff_pickup = child
		if String(child.name).begins_with("DroppedCard_"):
			card_pickup = child
	check(staff_pickup != null and staff_pickup.global_position.distance_to(where) < 80.0, "he dropped his staff")
	check(card_pickup != null, "and a card")
	check(await wait_until(func(): return not is_instance_valid(event), 5.0), "and he is gone")
	if staff_pickup == null:
		map.free()
		return
	# The staff: fire costs health, there is no ammo.
	await wait_until(func(): return not health.is_burning() and not health.is_dead, 6.0)
	player.global_position = staff_pickup.global_position
	await frames(4)
	await tap("interact")
	await frames(3)
	var holder = player.get_weapon_holder()
	check(LoadoutRules.active(holder.loadout).def == &"pharaoh_staff", "picked up the staff: %s" % [holder.loadout.slots])
	var before: float = health.current_health
	var ammo_before: int = LoadoutRules.active(holder.loadout).ammo
	await tap("shoot")
	check(await wait_until(func(): return health.current_health < before, 2.0), "a fireball costs health (%s -> %s)" % [before, health.current_health])
	check(LoadoutRules.active(holder.loadout).ammo == ammo_before, "and no ammo")
	map.free()
