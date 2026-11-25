@tool
extends Node2D
class_name GameMap
## Root of a playable map: puts its rooms together, spawns the players and
## owns map-level network objects such as dropped weapon pickups.
##
## Making a map: duplicate res://src/scenes/map_template.tscn into
## res://src/scenes/maps/ (every scene there is listed in the lobby). A map is
## one scene with its rooms painted in place:
##   - MapRoom nodes, each with its own Floor and Walls tile layers (any size
##     and shape) and RoomDoor nodes at the gaps in its walls
##   - RoomLink nodes: which rooms get a corridor between them (with a chance)
##   - swap groups and RoomSpot nodes: rooms that trade places each match
##   - spawn points, weapon spots and card areas, next to the rooms (in
##     SpawnLocations, WeaponDrops, CardDrops) or inside them: each belongs to
##     the room it stands in and moves with it
## Each match the corridors are carved between doorways around the rooms, by the
## Layout Rules on this node; "Reroll layout preview" shows a layout in the
## editor. Maps without rooms (tutorial, debug arena) are used as painted.
## Either way a map needs:
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
## How the rooms are put together: corridor width and tiles.
@export var layout_rules: MapLayoutRules:
	set(value):
		layout_rules = value
		update_configuration_warnings()
@export_tool_button("Reroll layout preview", "RandomNumberGenerator") var reroll_preview := _preview_layout
@export_tool_button("Clear layout preview", "Remove") var clear_preview := _clear_preview

## The rooms, once put together for this match.
var rooms: Array[MapRoom] = []
## Spawn points, weapon spots and card areas placed next to the rooms (not in
## them) -> the room they stand in; they move with it. Filled by build_layout.
var _room_of := {}
## Room -> how far build_layout moved it, in tiles.
var _built_offsets := {}
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
	if has_layout():
		build_layout(GameManager.map_seed)

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

# --- Rooms --------------------------------------------------------------------------

func has_layout() -> bool:
	return not map_rooms().is_empty()

## The map's MapRoom nodes, in a fixed order (by path) so every peer agrees.
func map_rooms() -> Array[MapRoom]:
	var out: Array[MapRoom] = []
	for node in find_children("*", "MapRoom", true, false):
		if not _in_preview(node):
			out.append(node)
	out.sort_custom(func(a, b): return String(get_path_to(a)) < String(get_path_to(b)))
	return out

func _corridor_width() -> int:
	return layout_rules.corridor_tiles if layout_rules else 3

## A room's top-left tile in the map (rooms sit on the tile grid).
func _room_origin(room: MapRoom) -> Vector2i:
	return Vector2i((_map_point(room) / MapRoom.TILE).round())

## What the planner needs to know about the map (see LayoutPlanner.plan).
func layout_input() -> Dictionary:
	var width := _corridor_width()
	var rooms_in: Array = []
	for room in map_rooms():
		var origin := _room_origin(room)
		var cells := {}
		for cell in room.cells():
			cells[cell + origin] = true
		var rect := room.used_rect()
		var doors: Array = []
		for door in room.doors():
			var door_cells: Array[Vector2i] = []
			for cell in door.cells(door.gap_width()):
				door_cells.append(cell + origin)
			doors.append({"cells": door_cells, "facing": int(door.facing)})
		rooms_in.append({"id": String(get_path_to(room)), "cells": cells, "anchor": origin + rect.get_center(),
			"group": room.swap_group, "gated": room.gated, "doors": doors})
	var spots := {}
	for spot in find_children("*", "RoomSpot", true, false):
		if spot.group != &"":
			spots.get_or_add(spot.group, []).append(Vector2i((_map_point(spot) / MapRoom.TILE).floor()))
	var links: Array = []
	for link in find_children("*", "RoomLink", true, false):
		var a: MapRoom = link.from_room()
		var b: MapRoom = link.to_room()
		if a and b:
			links.append({"a": String(get_path_to(a)), "b": String(get_path_to(b)), "chance": link.chance, "width": link.width})
	var settings := {"width": width}
	if layout_rules:
		settings["turn_cost"] = layout_rules.turn_cost
		settings["max_detour"] = layout_rules.max_detour
		settings["padding"] = layout_rules.padding_tiles
	return {"rooms": rooms_in, "spots": spots, "links": links, "settings": settings}

## The layout for `seed_value`, without building it.
func plan_layout(seed_value: int) -> Dictionary:
	return LayoutPlanner.plan(layout_input(), seed_value)

## Moves the rooms, carves the corridors and walls up unused doorways for
## `seed_value`. Every peer gets the same seed (lobby start_game), so every
## peer builds the same map and RPCs inside it reach the same nodes.
func build_layout(seed_value: int) -> Dictionary:
	var plan := plan_layout(seed_value)
	if not plan.ok:
		push_warning("Map %s, layout %d: %s" % [name, seed_value, "; ".join(plan.problems)])
	rooms = map_rooms()
	_room_of = _rooms_under_loose_things()
	for node in _room_of:
		var moved: Vector2i = plan.offsets.get(String(get_path_to(_room_of[node])), Vector2i.ZERO)
		node.position += Vector2(moved) * MapRoom.TILE
	for room in rooms:
		var id := String(get_path_to(room))
		var doors := room.doors()
		for i in range(doors.size()):
			var used: Dictionary = plan.doors.get(LayoutPlanner.door_key(id, i), {})
			if used.is_empty():
				room.seal_door(doors[i])
				continue
			room.seal_door(doors[i], used.open) # the part of a wide doorway no corridor uses
			if used.state == LayoutPlanner.GATE:
				room.add_gate(doors[i], used.open)
		room.position += Vector2(plan.offsets.get(id, Vector2i.ZERO)) * MapRoom.TILE
		_built_offsets[room] = plan.offsets.get(id, Vector2i.ZERO)
	if layout_rules and layout_rules.tile_set:
		var corridors := Node2D.new()
		corridors.name = "Corridors"
		add_child(corridors)
		move_child(corridors, 0)
		var floor_layer := _tile_layer(corridors, "Floor", -10)
		var walls := _tile_layer(corridors, "Walls", 0)
		for cell in plan.floor:
			floor_layer.set_cell(cell, layout_rules.floor_source_id, layout_rules.floor_atlas_coords)
		if layout_rules.outdoors:
			# Roads have no walls: grass everywhere between, a wall round the map.
			var ground := _tile_layer(corridors, "Ground", -11)
			var area := outdoor_area(plan)
			for x in range(area.position.x, area.end.x):
				for y in range(area.position.y, area.end.y):
					var cell := Vector2i(x, y)
					if x == area.position.x or y == area.position.y or x == area.end.x - 1 or y == area.end.y - 1:
						walls.set_cell(cell, layout_rules.wall_source_id, layout_rules.wall_atlas_coords)
					else:
						ground.set_cell(cell, layout_rules.ground_source_id, layout_rules.ground_atlas_coords)
		else:
			for cell in plan.walls:
				walls.set_cell(cell, layout_rules.wall_source_id, layout_rules.wall_atlas_coords)
	return plan

func _tile_layer(parent: Node, layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = layout_rules.tile_set
	layer.z_index = z
	parent.add_child(layer)
	return layer

## Outdoor maps: the rectangle (or square) of ground, wall included, around
## every room and road of a layout.
func outdoor_area(plan: Dictionary) -> Rect2i:
	var rect := Rect2i()
	var first := true
	for room in map_rooms():
		var used := room.used_rect()
		var offset: Vector2i = plan.offsets.get(String(get_path_to(room)), Vector2i.ZERO)
		var placed := Rect2i(used.position + _painted_origin(room) + offset, used.size)
		rect = placed if first else rect.merge(placed)
		first = false
	for cell in plan.floor:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	rect = rect.grow(layout_rules.border_tiles + 1)
	if layout_rules.square:
		var side := maxi(rect.size.x, rect.size.y)
		rect = Rect2i(rect.get_center() - Vector2i(side, side) / 2, Vector2i(side, side))
	return rect

## A room's top-left tile where it is painted (before build_layout moves it).
func _painted_origin(room: MapRoom) -> Vector2i:
	var origin := _room_origin(room)
	if rooms.has(room) and _built_offsets.has(room):
		origin -= _built_offsets[room]
	return origin

## Host -> everyone: open or close the gates of every room with this gate name.
@rpc("authority", "call_local", "reliable")
func set_gate_open(gate: StringName, open: bool) -> void:
	for room in rooms:
		if room.gate == gate:
			room.set_gates_open(open)

func _preview_layout() -> void:
	_clear_preview()
	var seed_value := layout_rules.preview_seed if layout_rules and layout_rules.preview_seed != 0 else randi()
	var plan := plan_layout(seed_value)
	var preview: Node2D = load("res://src/scenes/layout/layout_preview.gd").new()
	preview.name = "LayoutPreview"
	preview.plan = plan
	if layout_rules and layout_rules.outdoors:
		preview.outdoor_area = outdoor_area(plan)
	for room in map_rooms():
		var id := String(get_path_to(room))
		var origin := _room_origin(room)
		var offset: Vector2i = plan.offsets.get(id, Vector2i.ZERO)
		var cells: Array = room.cells().keys().map(func(c): return c + origin)
		var rect := room.used_rect()
		preview.placed.append({"room": room, "offset": offset, "cells": cells, "rect": Rect2i(rect.position + origin, rect.size)})
		var doors := room.doors()
		for i in range(doors.size()):
			var used: Dictionary = plan.doors.get(LayoutPlanner.door_key(id, i), {})
			var gap := doors[i].cells(doors[i].gap_width())
			for k in range(gap.size()):
				var state: String = used.state if not used.is_empty() and used.open.has(k) else ""
				preview.doors.append({"cell": gap[k] + origin + offset, "state": state})
	add_child(preview) # no owner: never saved with the scene
	print("Layout preview of %s, seed %d: %d corridors%s" % [name, seed_value, plan.links.size(),
		"" if plan.ok else ". Problems: " + "; ".join(plan.problems)])

func _clear_preview() -> void:
	var holder := get_node_or_null("LayoutPreview")
	if holder:
		remove_child(holder)
		holder.queue_free()

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
## and odd numbers on maps without rooms, else the half of the map it is in
## after the rooms are put together (Red west).
func spawn_teams_of(spawns: Array[Node2D]) -> Array[int]:
	var teams: Array[int] = []
	# Numbers only count on maps used as painted: rooms trading places would
	# mix the sides up, so maps with rooms always split west / east.
	var numbered := not has_layout() and spawns.all(func(n): return String(n.name).is_valid_int())
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
	var room := room_of(node)
	return room != null and room.is_closed()

## The room a node belongs to: the MapRoom it is in, or for spawn points,
## weapon spots and card areas placed next to the rooms, the room they stand in.
func room_of(node: Node) -> MapRoom:
	var parent := node.get_parent()
	while parent and parent != self:
		if parent is MapRoom:
			return parent
		parent = parent.get_parent()
	if _room_of.has(node):
		return _room_of[node]
	if rooms.is_empty() and node is Node2D:
		# Not built yet (editor, checks): the room it stands in where painted.
		return _painted_rooms().get(Vector2i((_map_point(node) / MapRoom.TILE).floor()))
	return null

## Map cell -> room, where the rooms are painted.
func _painted_rooms() -> Dictionary:
	var out := {}
	for room in map_rooms():
		var origin := _room_origin(room)
		for cell in room.cells():
			out[cell + origin] = room
	return out

## Spawn points, weapon spots and card areas outside any MapRoom node.
func _loose_things() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in find_children("*", "", true, false):
		if not (node is SpawnPoint or node is WeaponSpawner or node is PowerupSpawner or node.is_in_group("PlayerSpawnLocation")):
			continue
		if _in_preview(node):
			continue
		var parent := node.get_parent()
		var inside_room := false
		while parent and parent != self:
			if parent is MapRoom:
				inside_room = true
			parent = parent.get_parent()
		if not inside_room:
			out.append(node)
	return out

func _rooms_under_loose_things() -> Dictionary:
	var painted := _painted_rooms()
	var out := {}
	for node in _loose_things():
		var room = painted.get(Vector2i((_map_point(node) / MapRoom.TILE).floor()))
		if room:
			out[node] = room
	return out

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

func _spawn_count() -> int:
	var count := 0
	for node in find_children("*", "", true, false):
		if (node is SpawnPoint or node.is_in_group("PlayerSpawnLocation")) and not _in_preview(node) and not _in_gated_room(node):
			count += 1
	return count

func _in_gated_room(node: Node) -> bool:
	var room := room_of(node)
	return room != null and room.gated

## Problems with this map's layouts, tried with `seeds`, and with weapons marked
## "one location" (`exactly_once`: maps in the lobby need each exactly once).
func layout_problems(seeds: Array, exactly_once: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var counts := {}
	for node in find_children("*", "WeaponSpawner", true, false):
		if node.weapon_def and not _in_preview(node):
			counts[node.weapon_def.id] = counts.get(node.weapon_def.id, 0) + 1
	for def in WeaponDefs.all():
		if not def.one_location:
			continue
		var n: int = counts.get(def.id, 0)
		if n > 1 or (exactly_once and n != 1):
			out.append("%s must be in exactly one place, found %d." % [def.display_name, n])
	if has_layout():
		var painted := _painted_rooms()
		for node in _loose_things():
			if not painted.has(Vector2i((_map_point(node) / MapRoom.TILE).floor())):
				out.append("%s stands outside every room: a corridor could be carved over it. Move it into a room." % node.name)
		if layout_rules == null:
			out.append("Map with rooms but no Layout Rules: set Layout Rules on this node.")
		elif layout_rules.tile_set == null:
			out.append("Layout Rules have no tile set for the corridors.")
		for seed_value in seeds:
			var plan := plan_layout(seed_value)
			if not plan.ok:
				out.append("Layout %d: %s." % [seed_value, "; ".join(plan.problems)])
	return out

# --- Editor checks ----------------------------------------------------------------

func _on_editor_tree_changed(node: Node) -> void:
	if is_ancestor_of(node):
		update_configuration_warnings.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if playerScene == null:
		warnings.append("Player Scene is empty: set it to res://src/entities/player/player.tscn.")
	var needed := _spawns_needed()
	var count := _spawn_count()
	if count < needed:
		warnings.append("Needs at least %d spawn points (SpawnPoint nodes) outside semi-permanent rooms, has %d." % [needed, count])
	if not _has_walls():
		warnings.append("No walls: paint walls with a tile set whose physics layer is on layer 3 \"walls\" (like src/assets/maps/catacombs/tiles.tres), or shots and players pass through.")
	# Two layouts, like the ones matches will get (the tests try many more);
	# the editor runs this after every change, so it has to stay quick.
	warnings.append_array(layout_problems([1, 2], false))
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
