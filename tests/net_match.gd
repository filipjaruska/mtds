extends SceneTree
## Two-process network test through the real lobby flow. Run both:
##   godot --headless --path . -s res://tests/net_match.gd -- --role=host
##   godot --headless --path . -s res://tests/net_match.gd -- --role=client
## Each process exits 0 when all of its checks passed.

const PORT := 18734
const MAP_NAME := "Main"

var _failures: Array[String] = []
var _started := false
var _role := "host"

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

func _run_host() -> void:
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
	current_scene._on_start_pressed()
	check(await wait_until(func(): return _player(1) != null and _player(client_id) != null, 5.0), "players spawned")
	await seconds(1.0)

	var client_holder = _player(client_id).get_weapon_holder()
	check(LoadoutRules.active(client_holder.loadout).get("def") == &"pistol", "host mirrors client loadout")

	# The client shoots the host once (see _run_client).
	var host_health = _player(1).get_health_component()
	check(await wait_until(func(): return host_health.current_health < 100.0, 6.0), "client shot damaged host")
	check(is_equal_approx(host_health.current_health, 90.0), "host took 10 damage, has %s" % host_health.current_health)
	check(is_equal_approx(gm.match_stats.get(client_id, {}).get("damage_dealt", 0.0), 10.0), "damage stat recorded for client")

	# Host kills the client; the host decides the respawn.
	var client_health = _player(client_id).get_health_component()
	client_health.apply_damage(500.0, 0.0, 1)
	check(client_health.is_dead, "client dead on host")
	check(gm.match_stats.get(1, {}).get("kills", 0) == 1, "kill recorded for host")
	check(await wait_until(func(): return not client_health.is_dead, 4.0), "client respawned")
	check(is_equal_approx(client_health.current_health, 100.0), "client respawned with full health")

	await seconds(2.0) # let the client finish its checks
	finish()

func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	root.multiplayer.multiplayer_peer = peer
	check(await wait_until(func(): return root.multiplayer.get_unique_id() > 1 and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 10.0), "connected")
	root.get_node("GameManager").local_player_name = "Client"
	change_scene_to_file("res://src/ui/menus/lobby.tscn")

	var my_id := root.multiplayer.get_unique_id()
	check(await wait_until(func(): return _player(1) != null and _player(my_id) != null, 20.0), "match started on client")
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

	var my_health = me.get_health_component()
	check(await wait_until(func(): return my_health.is_dead, 6.0), "client sees own death")
	check(not me.visible, "dead player hidden")
	check(await wait_until(func(): return not my_health.is_dead, 4.0), "client sees own respawn")
	check(is_equal_approx(my_health.current_health, 100.0), "client full health after respawn")
	check(me.visible, "respawned player visible")
	finish()
