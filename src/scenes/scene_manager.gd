@tool
extends Node2D
class_name GameMap
## Root of a playable map: builds its rooms, spawns the players and owns
## map-level network objects such as dropped weapon pickups.
##
## Making a map: duplicate res://src/scenes/map_template.tscn into
## res://src/scenes/maps/ (every scene there is listed in the lobby). There are
## two kinds:
##   - slot maps (the template): MapSlot nodes on a grid, each with the rooms it
##     may use (scenes made from res://src/scenes/rooms/room_template.tscn).
##     Every match picks rooms, turns them and opens doorways at random, by the
##     Layout Rules on this node; "Reroll layout preview" shows one in the editor.
##   - fixed maps: everything painted in the map itself (catacombs, tutorial).
## Either way the map needs, in its rooms or in itself:
##   - spawn points (SpawnPoint nodes), one per player at least
##   - walls painted with a tile set whose physics layer is on layer 3
##     "walls", so shots and players stop at them
##   - weapon spots (WeaponSpawner) and card areas (PowerupSpawner), optional;
##     weapons marked "one location" (the katana) exactly once
## The scene tree shows a warning on this node while something is missing.

const RULES: GameRules = preload("res://src/game_rules.tres")

const WEAPON_PICKUP_SCENE := preload("res://src/entities/weapons/weapon_pickup.tscn")
## How far from the dropping player a drop may land (guards against bogus requests).
const MAX_DROP_DISTANCE := 200.0

@export var playerScene: PackedScene
## Spawn points this map must have. 0 = the max players in game_rules.tres.
@export_range(0, 8) var spawn_points_needed: int = 0
## How the rooms of a slot map are put together (slot maps only).
@export var layout_rules: MapLayoutRules:
	set(value):
		layout_rules = value
		update_configuration_warnings()
@export_tool_button("Reroll layout preview", "RandomNumberGenerator") var reroll_preview := _preview_layout
@export_tool_button("Clear layout preview", "Remove") var clear_preview := _clear_preview

## The rooms built for this match (slot maps).
var rooms: Array[MapRoom] = []
var _dropped_pickup_count: int = 0

func _ready():
	if Engine.is_editor_hint():
		# Re-check the map whenever something in it changes.
		get_tree().node_added.connect(_on_editor_tree_changed)
		get_tree().node_removed.connect(_on_editor_tree_changed)
		get_tree().node_renamed.connect(_on_editor_tree_changed)
		return
	var combat := CombatServer.new()
	combat.name = "Combat"
	add_child(combat)
	if has_slots():
		build_layout(GameManager.map_seed, self)

	var team_mode := GameManager.is_team_mode()
	var spawns := spawn_points()
	var spawn_teams := spawn_teams_of(spawns)
	for player_id in GameManager.players:
		var data: Dictionary = GameManager.players[player_id]
		var currentPlayer = playerScene.instantiate()
		currentPlayer.name = str(player_id)
		currentPlayer.set_multiplayer_authority(player_id)
		currentPlayer.set_player_name(str(data.name))
		# Team matches show team colours instead of each player's own colour.
		var color: Color = TeamRules.COLORS[GameManager.get_team(player_id)] if team_mode else _player_color_from_data(data)
		currentPlayer.set_player_color(color)
		add_child(currentPlayer)
		var index := TeamRules.first_spawn(GameManager.players, player_id, team_mode, spawn_teams)
		if index >= 0:
			currentPlayer.global_position = spawns[index].global_position

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int) -> void:
	var player_node := get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()

func _player_color_from_data(player_data: Dictionary) -> Color:
	var color_value: Variant = player_data.get("color", Color.WHITE)
	if color_value is Color:
		var tint: Color = color_value
		tint.a = 1.0
		return tint
	if typeof(color_value) == TYPE_STRING:
		var tint := Color.html(str(color_value))
		tint.a = 1.0
		return tint
	return Color.WHITE

## Owner -> host: put a weapon the sender is carrying on the ground.
## Must be sent before the owner syncs its new loadout, so the host's mirror of
## the sender's loadout still contains the weapon when this arrives.
@rpc("any_peer", "call_local", "reliable")
func request_weapon_drop(def_id: StringName, pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var player := get_node_or_null(str(multiplayer.get_remote_sender_id()))
	if player == null or not WeaponDefs.has(def_id):
		return
	var holder: WeaponHolder = player.get_weapon_holder()
	if holder == null or not holder.has_weapon(def_id):
		return
	if pos.distance_to(player.global_position) > MAX_DROP_DISTANCE:
		pos = player.global_position
	_dropped_pickup_count += 1
	_spawn_weapon_pickup.rpc(def_id, pos, "DroppedWeapon_%d" % _dropped_pickup_count)

## Pickups get the same name on every peer so their RPCs resolve everywhere,
## and live under the map so they disappear with it.
@rpc("authority", "call_local", "reliable")
func _spawn_weapon_pickup(def_id: StringName, pos: Vector2, node_name: String) -> void:
	var def := WeaponDefs.get_def(def_id)
	if def == null or has_node(node_name):
		return
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	pickup.name = node_name
	pickup.position = pos
	pickup.setup(def)
	add_child(pickup)

# --- Rooms (slot maps) -------------------------------------------------------------

func has_slots() -> bool:
	return not slots().is_empty()

func slots() -> Array[MapSlot]:
	var out: Array[MapSlot] = []
	for node in find_children("*", "MapSlot", true, false):
		out.append(node)
	return out

## The planner's view of this map's slots. Room scenes are opened once to read
## their sides, spawn points and weapons (see MapRoom.summary).
func slot_descriptions() -> Array:
	var out: Array = []
	var summaries := {}
	var tiles := layout_rules.slot_tiles if layout_rules else Vector2i(16, 16)
	for slot in slots():
		var choices: Array = []
		for choice in slot.choices:
			if choice == null or choice.scene == null:
				continue
			var key := choice.scene.resource_path
			if not summaries.has(key):
				summaries[key] = _room_summary(choice.scene)
			var summary: Dictionary = summaries[key]
			if summary.is_empty():
				continue
			choices.append({"key": key, "scene": choice.scene, "weight": choice.weight, "max": choice.max_per_map,
				"edges": summary.edges, "gated": summary.gated, "spawns": summary.spawns, "weapons": summary.weapons,
				"size_tiles": summary.size_tiles, "door_tiles": summary.door_tiles})
		out.append({"cell": slot.cell(), "name": String(slot.name), "choices": choices, "empty_chance": slot.empty_chance,
			"rotate": slot.allow_rotate, "flip": slot.allow_flip, "required": slot.required, "square": tiles.x == tiles.y})
	return out

static func _room_summary(scene: PackedScene) -> Dictionary:
	var room := scene.instantiate()
	var summary: Dictionary = room.summary() if room is MapRoom else {}
	room.free()
	return summary

## The layout for `seed_value` (see LayoutPlanner.plan), without building it.
func plan_layout(seed_value: int) -> Dictionary:
	var chance := layout_rules.extra_door_chance if layout_rules else 0.35
	var needed := maxi(_spawns_needed() - _fixed_spawn_count(), 0)
	return LayoutPlanner.plan(slot_descriptions(), seed_value, chance, needed)

## Builds the rooms for `seed_value` under `parent`. Every peer gets the same
## seed (lobby start_game), so every peer builds the same rooms with the same
## node names (Room_<x>_<y>), and RPCs inside them reach the same nodes.
func build_layout(seed_value: int, parent: Node) -> Dictionary:
	var plan := plan_layout(seed_value)
	if not plan.ok:
		push_warning("Map %s, seed %d: %s" % [name, seed_value, "; ".join(plan.problems)])
	var size := layout_rules.slot_pixels() if layout_rules else Vector2(1024, 1024)
	rooms.clear()
	for cell: Vector2i in plan.rooms:
		var placed: Dictionary = plan.rooms[cell]
		var room: MapRoom = placed.choice.scene.instantiate()
		room.name = "Room_%d_%d" % [cell.x, cell.y]
		# Turn and mirror around the room's centre, then move it into its slot.
		var centre := size * 0.5
		var xform := Transform2D(placed.rot * PI * 0.5, Vector2(-1.0 if placed.flip else 1.0, 1.0), 0.0, Vector2.ZERO)
		xform.origin = Vector2(cell) * size + centre - xform.basis_xform(centre)
		room.transform = xform
		for side in range(4):
			var state: int = plan.sides.get(LayoutPlanner.side_key(cell, side), LayoutPlanner.Side.NONE)
			room.apply_side(LayoutPlanner.own_side(side, placed.rot, placed.flip), state)
		parent.add_child(room)
		rooms.append(room)
	return plan

## Host -> everyone: open or close the gates of every room with this gate name.
@rpc("authority", "call_local", "reliable")
func set_gate_open(gate: StringName, open: bool) -> void:
	for room in rooms:
		if room.gate == gate:
			room.set_gates_open(open)

func _preview_layout() -> void:
	_clear_preview()
	var seed_value := layout_rules.preview_seed if layout_rules and layout_rules.preview_seed != 0 else randi()
	var holder := Node2D.new()
	holder.name = "LayoutPreview"
	add_child(holder) # no owner: never saved with the scene
	var plan := build_layout(seed_value, holder)
	print("Layout preview of %s, seed %d%s" % [name, seed_value, "" if plan.ok else ": " + "; ".join(plan.problems)])

func _clear_preview() -> void:
	var holder := get_node_or_null("LayoutPreview")
	if holder:
		remove_child(holder)
		holder.queue_free()
	rooms.clear()

# --- Spawn points -----------------------------------------------------------------

## Spawn points players may use right now: everything in the map and its rooms
## except closed semi-permanent rooms. Fixed maps keep their 0, 1, 2 ... order.
func spawn_points() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in find_children("*", "", true, false):
		if not (node is SpawnPoint or node.is_in_group("PlayerSpawnLocation")):
			continue
		if _in_closed_room(node) or _in_preview(node):
			continue
		out.append(node)
	if out.all(func(n): return String(n.name).is_valid_int()):
		out.sort_custom(func(a, b): return String(a.name).to_int() < String(b.name).to_int())
	return out

## Team of each spawn point (TeamRules team index): its own setting, else even
## and odd numbers on fixed maps, else the half of the map it is in (Red west).
func spawn_teams_of(spawns: Array[Node2D]) -> Array[int]:
	var teams: Array[int] = []
	var numbered := spawns.all(func(n): return String(n.name).is_valid_int())
	var xs: Array = spawns.map(func(n): return _map_point(n).x)
	xs.sort()
	var middle := 0.0
	if not xs.is_empty():
		@warning_ignore("integer_division")
		middle = (float(xs[(xs.size() - 1) / 2]) + float(xs[xs.size() / 2])) * 0.5
	for spawn in spawns:
		if spawn is SpawnPoint and spawn.team != SpawnPoint.Team.AUTO:
			teams.append(spawn.team)
		elif numbered:
			teams.append(String(spawn.name).to_int() % TeamRules.TEAM_COUNT)
		else:
			teams.append(0 if _map_point(spawn).x <= middle else 1)
	return teams

## Where a player comes back after dying (host). Team matches use their side.
func random_spawn_position(player_id: int) -> Vector2:
	var spawns := spawn_points()
	if spawns.is_empty():
		return Vector2.ZERO
	var choices := TeamRules.respawn_choices(GameManager.get_team(player_id), spawn_teams_of(spawns), GameManager.is_team_mode())
	return spawns[choices.pick_random()].global_position

func _in_closed_room(node: Node) -> bool:
	var parent := node.get_parent()
	while parent and parent != self:
		if parent is MapRoom and parent.is_closed():
			return true
		parent = parent.get_parent()
	return false

func _in_preview(node: Node) -> bool:
	var preview := get_node_or_null("LayoutPreview")
	return preview != null and preview.is_ancestor_of(node)

## Position in the map's own coordinates (works outside the scene tree too).
func _map_point(node: Node2D) -> Vector2:
	var pos := Vector2.ZERO
	var current: Node = node
	while current and current != self and current is Node2D:
		pos = (current as Node2D).transform * pos
		current = current.get_parent()
	return pos

func _spawns_needed() -> int:
	# In the editor GameRules' script is not running; read the value as plain data.
	var max_players = RULES.get("max_players")
	return spawn_points_needed if spawn_points_needed > 0 else (int(max_players) if max_players != null else 8)

## Spawn points painted in the map itself, outside rooms.
func _fixed_spawn_count() -> int:
	var count := 0
	for node in find_children("*", "", true, true):
		if (node is SpawnPoint or node.is_in_group("PlayerSpawnLocation")) and not _in_preview(node):
			count += 1
	return count

## Weapon spots painted in the map itself, by weapon id.
func _fixed_weapons() -> Dictionary:
	var out := {}
	for node in find_children("*", "WeaponSpawner", true, true):
		if node.weapon_def and not _in_preview(node):
			out[node.weapon_def.id] = out.get(node.weapon_def.id, 0) + 1
	return out

## Problems with this map's layouts, tried with `seeds`: rooms that do not fit
## the layout rules, layouts that fail, and "one location" weapons that appear
## more or less than once (`exactly_once`: maps in the lobby need each one once).
func layout_problems(seeds: Array, exactly_once: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if has_slots():
		if layout_rules == null:
			out.append("Slot map without Layout Rules: set Layout Rules on this node.")
			return out
		out.append_array(layout_rules.problems())
		for slot in slot_descriptions():
			for choice in slot.choices:
				if choice.size_tiles != layout_rules.slot_tiles or choice.door_tiles != layout_rules.door_tiles:
					out.append("%s is %s tiles with %d-tile doorways; this map's slots are %s with %d." % [
						String(choice.key).get_file(), choice.size_tiles, choice.door_tiles, layout_rules.slot_tiles, layout_rules.door_tiles])
	var fixed := _fixed_weapons()
	var one_location: Array = WeaponDefs.all().filter(func(d): return d.one_location).map(func(d): return d.id)
	for seed_value in seeds:
		var counts := fixed.duplicate()
		if has_slots():
			var plan := plan_layout(seed_value)
			if not plan.ok:
				out.append("Layout %d fails: %s." % [seed_value, "; ".join(plan.problems)])
				continue
			for cell in plan.rooms:
				var weapons: Dictionary = plan.rooms[cell].choice.weapons
				for id in weapons:
					counts[id] = counts.get(id, 0) + weapons[id]
		for id in one_location:
			var n: int = counts.get(id, 0)
			if n > 1 or (exactly_once and n != 1):
				out.append("%s must be in exactly one place, found %d%s. Put its weapon spot in one room used by one required slot (max 1 per map)." % [
					WeaponDefs.get_def(id).display_name, n, (" in layout %d" % seed_value) if has_slots() else ""])
		if not has_slots():
			break
	var unique := {}
	for line in out:
		unique[line] = true
	return PackedStringArray(unique.keys())

# --- Editor checks ----------------------------------------------------------------

func _on_editor_tree_changed(node: Node) -> void:
	if is_ancestor_of(node):
		update_configuration_warnings.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if playerScene == null:
		warnings.append("Player Scene is empty: set it to res://src/entities/player/player.tscn.")
	if has_slots():
		# A few layouts, like the ones matches will get (the tests try many more).
		warnings.append_array(layout_problems(range(1, 9), false))
		return warnings
	var needed := _spawns_needed()
	var count := _fixed_spawn_count()
	if count < needed:
		warnings.append("Needs at least %d spawn points (SpawnPoint nodes), has %d." % [needed, count])
	if not _has_walls():
		warnings.append("No walls: paint walls with a tile set whose physics layer is on layer 3 \"walls\" (like src/assets/maps/catacombs/tiles.tres), or shots and players pass through.")
	warnings.append_array(layout_problems([0], false))
	return warnings

## Some painted tile is solid on the "walls" physics layer.
func _has_walls() -> bool:
	for layer: TileMapLayer in find_children("*", "TileMapLayer", true, false):
		var tiles := layer.tile_set
		if tiles == null:
			continue
		for i in range(tiles.get_physics_layers_count()):
			if not tiles.get_physics_layer_collision_layer(i) & CombatServer.WALL_LAYER:
				continue
			for cell in layer.get_used_cells():
				var data := layer.get_cell_tile_data(cell)
				if data and data.get_collision_polygons_count(i) > 0:
					return true
	return false
