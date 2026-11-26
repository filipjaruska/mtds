extends SceneTree
## Two-process network test through the real lobby flow. Run both:
##   godot --headless --path . -s res://tests/net_match.gd -- --role=host
##   godot --headless --path . -s res://tests/net_match.gd -- --role=client
## Each process exits 0 when all of its checks passed.

const PORT := 18734
const MAP_PATH := "res://tests/maps/test_arena.tscn"
const MAP_NAME := "TestArena"
const EVENTS_MAP := "res://tests/maps/events_test.tscn"

var _failures: Array[String] = []
var _started := false
var _role := "host"
var _chat_log: Array = [] # [peer id, text] as received
var _map_name := MAP_NAME

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--role="):
				_role = arg.trim_prefix("--role=")
		if _role == "host":
			_run_host()
		else:
			_run_client()
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[%s] FAIL %s" % [_role, message])

func wait_until(condition: Callable, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false

func seconds(sec: float) -> void:
	await create_timer(sec).timeout

func finish() -> void:
	print("[%s] NET: %d failures" % [_role, _failures.size()])
	await seconds(0.5)
	quit(1 if not _failures.is_empty() else 0)

func _map() -> Node:
	return root.get_node_or_null(_map_name)

func _player(id: int) -> Node:
	var map := _map()
	return map.get_node_or_null(str(id)) if map else null

func _listen_to_chat() -> void:
	root.get_node("ChatManager").message_received.connect(func(id: int, text: String) -> void:
		_chat_log.append([id, text]))

func _chat_from(peer_id: int) -> Array:
	return _chat_log.filter(func(entry): return entry[0] == peer_id)

func _run_host() -> void:
	_listen_to_chat()
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 4)
	root.multiplayer.multiplayer_peer = peer
	root.get_node("GameManager").local_player_name = "Host"
	change_scene_to_file("res://src/ui/menus/lobby.tscn")

	var gm = root.get_node("GameManager")
	check(await wait_until(func(): return gm.players.size() == 2, 15.0), "client registered in lobby")
	var client_id: int = 0
	for id in gm.players:
		if id != 1:
			client_id = id
	# Host picks the lobby settings; the client must see all of them (see _run_client).
	var lobby = current_scene
	gm.set_map(MAP_PATH)
	lobby._on_gametype_dropdown_item_selected(1) # teams
	check(gm.get_team(1) != gm.get_team(client_id), "host and client on different teams")
	await seconds(0.5)
	lobby._on_start_pressed()
	check(await wait_until(func(): return _player(1) != null and _player(client_id) != null, 5.0), "players spawned")
	await seconds(1.0)

	var client_holder = _player(client_id).get_weapon_holder()
	check(LoadoutRules.active(client_holder.loadout).get("def") == &"pistol", "host mirrors client loadout")

	# The client shoots the host once (see _run_client).
	var host_health = _player(1).get_health_component()
	check(await wait_until(func(): return host_health.current_health < 100.0, 6.0), "client shot damaged host")
	check(is_equal_approx(host_health.current_health, 90.0), "host took 10 damage, has %s" % host_health.current_health)
	check(is_equal_approx(gm.match_stats.get(client_id, {}).get("damage_dealt", 0.0), 10.0), "damage stat recorded for client")

	# The client activates Armor and Dual Wield; the host must mirror both.
	var client_pm = _player(client_id).get_node("PowerupManager")
	check(await wait_until(func(): return not PowerupRules.find(client_pm.active, &"armor").is_empty(), 6.0), "host mirrors client's armor")
	check(await wait_until(func(): return LoadoutRules.is_dual(client_holder.loadout), 6.0), "host mirrors client's dual wield loadout")
	var client_health = _player(client_id).get_health_component()
	client_health.apply_damage(20.0, 0.0, 1)
	check(is_equal_approx(client_health.current_health, 83.0), "armor reduced damage on the host, hp=%s" % client_health.current_health)
	
	# Host kills the client; the host decides the respawn.
	client_health.apply_damage(500.0, 0.0, 1)
	check(client_health.is_dead, "client dead on host")
	check(gm.match_stats.get(1, {}).get("kills", 0) == 1, "kill recorded for host")
	check(await wait_until(func(): return not client_health.is_dead, 4.0), "client respawned")
	check(is_equal_approx(client_health.current_health, 100.0), "client respawned with full health")

	# Riot Shield across the network: the client must see it appear and shatter.
	_player(1).get_node("PowerupManager")._sync_activate.rpc(&"armor", 1)
	await seconds(1.5)
	var shield = _player(1).get_node_or_null("PlayerController/RiotShield")
	check(shield != null, "host raised its riot shield")
	if shield:
		shield.take_hit(9999.0)

	# Chat: the client said hello and then spammed (see _run_client).
	check(await wait_until(func(): return _chat_from(client_id).size() > 0, 6.0), "host received the client's chat")
	var from_client := _chat_from(client_id)
	check(not from_client.is_empty() and from_client[0][1] == "hello host", "chat text intact: %s" % [from_client])
	check(from_client.size() == 3, "spam cut to the rate limit (got %d)" % from_client.size())

	# Shady Fella: the host starts him, the client trades (see _run_client),
	# then the host shoots him.
	var director = _map().get_node("Events")
	director.start_now(0)
	check(await wait_until(func(): return director.has_node("Event_1"), 2.0), "Shady Fella started on the host")
	var fella_event = director.get_node_or_null("Event_1")
	if fella_event:
		check(await wait_until(func(): return fella_event.offer.size() == 2, 15.0), "the client took one of his 3 cards")
		check(await wait_until(func(): return client_pm.hand_ids.size() == 1, 4.0), "the host knows the client holds it: %s" % [client_pm.hand_ids])
		fella_event.fella.take_hit(10.0, 1)
		check(fella_event.state == ShadyFellaRules.State.FLEEING, "shot: he runs")

	await seconds(6.0) # let the client finish its checks

	# Blackjack: a new match on a map with the room. Both players go in, the
	# host shuts the doors, the cards are dealt (see _run_client).
	lobby.start_game.rpc(EVENTS_MAP, 3)
	_map_name = "EventsTest"
	check(await wait_until(func(): return _player(1) != null and _player(client_id) != null, 5.0), "blackjack map started")
	await seconds(1.0)
	director = _map().get_node("Events")
	director.start_now(0)
	check(await wait_until(func(): return director.has_node("Event_1"), 2.0), "blackjack started on the host")
	var table_event = director.get_node_or_null("Event_1")
	if table_event:
		var area: Rect2 = table_event.room_area()
		_player(1).global_position = area.get_center() + Vector2(-100, 220)
		check(await wait_until(func(): return table_event.players_inside().size() == 2, 10.0), "both players in the room: %s" % [table_event.players_inside()])
		table_event.lock_now()
		check(await wait_until(func(): return table_event.phase == table_event.Phase.RESULT, 25.0), "the game was played")
		var client_seat: int = table_event.seated.find(client_id)
		check(client_seat >= 0 and table_event.seated.has(1), "both at the table: %s" % [table_event.seated])
		var client_hand = _player(client_id).get_node("PowerupManager")
		if client_seat >= 0:
			var won: bool = table_event.results[client_seat]
			check(await wait_until(func(): return client_hand.hand_ids.is_empty() != won, 4.0), "the host knows what the client kept (won=%s, %s)" % [won, client_hand.hand_ids])
		check(await wait_until(func(): return not is_instance_valid(table_event), 10.0), "the blackjack event ended")
		check(await wait_until(func(): return not area.has_point(_player(client_id).global_position), 3.0), "the client went back out")
	await seconds(4.0) # let the client finish its blackjack checks

	# Tutankhamun: wakes, the client sees him; the host kills him, the client
	# sees his staff on the floor.
	director.start_now(1)
	check(await wait_until(func(): return director.has_node("Event_2"), 2.0), "Tutankhamun woke on the host")
	var tut = director.get_node_or_null("Event_2")
	await seconds(2.0)
	if tut:
		tut.body.take_hit(10000.0, 1)
		check(tut.state == TutankhamunRules.State.DEAD, "the host killed him")
	await seconds(4.0) # let the client finish its checks
	finish()

func _run_client() -> void:
	# Retry until the host is listening, so the client may start first.
	var connected := false
	var deadline := Time.get_ticks_msec() + 20000
	while not connected and Time.get_ticks_msec() < deadline:
		var peer := ENetMultiplayerPeer.new()
		peer.create_client("127.0.0.1", PORT)
		root.multiplayer.multiplayer_peer = peer
		connected = await wait_until(func(): return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 3.0)
		if not connected:
			peer.close()
	check(connected, "connected")
	root.get_node("GameManager").local_player_name = "Client"
	change_scene_to_file("res://src/ui/menus/lobby.tscn")

	var my_id := root.multiplayer.get_unique_id()
	check(await wait_until(func(): return _player(1) != null and _player(my_id) != null, 20.0), "match started on client")
	_listen_to_chat()
	var chat = root.get_node("ChatManager")
	chat.send("  hello   host ")
	for i in range(4):
		chat.send("spam %d" % i)
	check(await wait_until(func(): return _chat_from(my_id).size() > 0, 6.0), "client sees its own message come back")
	check(_chat_from(my_id)[0][1] == "hello host" if not _chat_from(my_id).is_empty() else false, "message was cleaned by the host")
	var gm = root.get_node("GameManager")
	check(gm.get_game_type() == "teams", "client sees host's game type, got %s" % gm.get_game_type())
	check(gm.get_map() == MAP_PATH, "client sees host's map, got %s" % gm.get_map())
	var lobby = current_scene
	check(lobby.map_dropdown.get_item_text(lobby.map_dropdown.selected) == "test_arena", "client map dropdown shows the host's map")
	check(lobby.game_type_dropdown.selected == 1, "client dropdown shows the host's game type")
	await seconds(1.5)

	var me: Node2D = _player(my_id)
	var host: Node2D = _player(1)
	check(LoadoutRules.active(host.get_weapon_holder().loadout).get("def") == &"pistol", "client mirrors host loadout")

	# Shoot straight at the host through the combat server.
	var direction := (host.global_position - me.global_position).normalized()
	var origin := me.global_position + direction * 40.0
	var combat = _map().get_node("Combat")
	combat.fire(me, origin, PackedFloat32Array([direction.angle()]), &"pistol", 2000.0)

	var host_health = host.get_health_component()
	check(await wait_until(func(): return host_health.current_health < 100.0, 6.0), "client sees host damaged")
	check(is_equal_approx(host_health.current_health, 90.0), "client sees host at 90, got %s" % host_health.current_health)
	
	var my_pm = me.get_node("PowerupManager")
	my_pm._sync_activate.rpc(&"armor", 1)
	my_pm._sync_activate.rpc(&"dual_wield", 1)
	check(LoadoutRules.is_dual(me.get_weapon_holder().loadout), "client dual wields")

	var my_health = me.get_health_component()
	check(await wait_until(func(): return my_health.is_dead, 6.0), "client sees own death")
	check(not me.visible, "dead player hidden")
	check(await wait_until(func(): return not my_health.is_dead, 4.0), "client sees own respawn")
	check(is_equal_approx(my_health.current_health, 100.0), "client full health after respawn")
	check(me.visible, "respawned player visible")

	check(await wait_until(func(): return host.has_node("PlayerController/RiotShield"), 8.0), "client sees the host's riot shield")
	check(await wait_until(func(): return not host.has_node("PlayerController/RiotShield"), 8.0), "client sees the shield shatter")

	# Shady Fella: walk up to him, open the trade, take his first card.
	var director = _map().get_node("Events")
	check(await wait_until(func(): return director.has_node("Event_1"), 15.0), "client sees Shady Fella")
	var fella_event = director.get_node_or_null("Event_1")
	if fella_event:
		var fella: Node2D = fella_event.fella
		check(await wait_until(func(): return fella_event.offer.size() == 3 and fella.position != Vector2.ZERO, 3.0), "his place and cards reached the client")
		me.global_position = fella.global_position + Vector2(60, 0)
		await seconds(0.5) # the host sees me arrive
		var input_manager = root.get_node("InputManager")
		fella_event.request_open.rpc_id(1)
		check(await wait_until(func(): return input_manager.choosing_card, 3.0), "the trade opened on the client")
		var first: StringName = fella_event.offer[0]
		fella_event.request_pick.rpc_id(1, 0)
		check(await wait_until(func(): return my_pm.inventory[0].def == first, 3.0), "client got %s: %s" % [first, my_pm.inventory])
		check(await wait_until(func(): return not input_manager.choosing_card, 3.0), "the trade closed")
		check(await wait_until(func(): return fella_event.state == ShadyFellaRules.State.FLEEING, 8.0), "client sees him run when shot")
		check(_map().get_children().any(func(c): return String(c.name).begins_with("DroppedCard_")), "client sees the card he dropped")
		check(await wait_until(func(): return not is_instance_valid(fella_event), 6.0), "client sees him go")

	# Blackjack on the next map (see _run_host): walk in, play, get sent out.
	_map_name = "EventsTest"
	check(await wait_until(func(): return _player(my_id) != null and _map().has_node("Events/Event_1"), 20.0), "client sees the blackjack room open")
	var table_event = _map().get_node_or_null("Events/Event_1")
	if table_event:
		me = _player(my_id)
		var room = _map().get_node("Rooms/BlackjackRoom")
		check(await wait_until(func(): return not room.is_closed(), 3.0), "the doors open on the client")
		var area: Rect2 = table_event.room_area()
		me.global_position = area.get_center() + Vector2(100, 220)
		check(await wait_until(func(): return table_event.phase == table_event.Phase.PLAYING, 15.0), "client sees the game start")
		check(room.is_closed(), "locked in on the client")
		check(table_event.seated.has(my_id), "client sits at the table")
		var seat_index: int = table_event.seated.find(my_id)
		if seat_index >= 0:
			var seat: Vector2 = table_event.table.seats()[table_event.seats[seat_index]].global_position
			check(await wait_until(func(): return me.global_position.distance_to(seat) < 2.0, 3.0), "client moved to its seat")
		var hand = me.get_node("PowerupManager")
		check(await wait_until(func(): return hand.get_used_inventory_slots() > 0, 3.0), "client was given a stake")
		check(await wait_until(func(): return table_event.phase == table_event.Phase.RESULT, 25.0), "client sees the result")
		if seat_index >= 0:
			var won: bool = table_event.results[seat_index]
			check(await wait_until(func(): return (hand.get_used_inventory_slots() > 0) == won, 3.0), "client kept its cards only if it won (won=%s)" % won)
		var table = table_event.table
		check(await wait_until(func(): return not is_instance_valid(table_event), 10.0), "client sees the event end")
		check(not area.has_point(me.global_position), "client sent back out: %s" % me.global_position)
		check(not is_instance_valid(table), "client sees the table gone")
		check(not room.is_closed(), "the room stays open on the client")

	# Tutankhamun (see _run_host).
	director = _map().get_node("Events")
	check(await wait_until(func(): return director.has_node("Event_2"), 10.0), "client sees Tutankhamun wake")
	var tut = director.get_node_or_null("Event_2")
	if tut:
		check(await wait_until(func(): return tut.body.visible and tut.sarcophagus.opened, 3.0), "client sees him step out of his sarcophagus")
		check(await wait_until(func(): return _map().get_children().any(func(c): return String(c.name).begins_with("DroppedWeapon_") and c.weapon_def.id == &"pharaoh_staff"), 8.0), "client sees the staff he dropped")
	finish()
