extends SceneTree
## Two-process network test through the real lobby flow. Run both:
##   godot --headless --path . -s res://tests/net_match.gd -- --role=host
##   godot --headless --path . -s res://tests/net_match.gd -- --role=client
## Each process exits 0 when all of its checks passed.

const PORT := 18734
const MAP_PATH := "res://tests/maps/test_arena.tscn"
const MAP_NAME := "TestArena"

var _failures: Array[String] = []
var _started := false
var _role := "host"
var _chat_log: Array = [] # [peer id, text] as received

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
	return root.get_node_or_null(MAP_NAME)

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
	lobby._on_card_rules_dropdown_item_selected(2) # poker
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

	await seconds(2.0) # let the client finish its checks
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
	check(gm.get_card_rules() == "poker", "client sees host's card rules, got %s" % gm.get_card_rules())
	check(gm.get_map() == MAP_PATH, "client sees host's map, got %s" % gm.get_map())
	var lobby = current_scene
	check(lobby.map_dropdown.get_item_text(lobby.map_dropdown.selected) == "test_arena", "client map dropdown shows the host's map")
	check(lobby.game_type_dropdown.selected == 1 and lobby.card_rules_dropdown.selected == 2, "client dropdowns show the host's settings")
	check(await wait_until(func(): return gm.poker_board.size() >= 1, 5.0), "client sees the poker board")
	check(gm.poker_board.all(func(c): return c >= 0 and c < 52), "board cards are valid: %s" % [gm.poker_board])
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
	finish()
