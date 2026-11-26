extends "res://tests/test_case.gd"
## Every playable map and the map template pass the checks the editor shows
## (configuration warnings), and maps with rooms work for many layouts.

const MAPS_DIR := "res://src/scenes/maps/"
## Layouts tried per map with rooms.
const SEEDS := 30

func _maps() -> Array[String]:
	var out: Array[String] = ["res://src/scenes/map_template.tscn"]
	for file in ResourceLoader.list_directory(MAPS_DIR):
		if file.ends_with(".tscn"):
			out.append(MAPS_DIR + file)
	return out

func _warnings(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in node.find_children("*", "", true, false):
		if child.has_method("_get_configuration_warnings"):
			for line in child._get_configuration_warnings():
				out.append("%s: %s" % [child.name, line])
	return out

func test_maps_are_complete() -> void:
	for path in _maps():
		var map: Node = load(path).instantiate()
		var warnings: PackedStringArray = map._get_configuration_warnings()
		warnings.append_array(_warnings(map)) # rooms, doorways, links, spots
		check(warnings.is_empty(), "%s: %s" % [path.get_file(), " / ".join(warnings)])
		for spawner in map.find_children("*", "WeaponSpawner", true, false):
			check(spawner.weapon_def != null, "%s: weapon spot %s has no weapon" % [path.get_file(), spawner.name])
		map.free()

func test_maps_work_for_many_layouts() -> void:
	for path in _maps():
		var map: GameMap = load(path).instantiate()
		var problems := map.layout_problems(range(1, SEEDS + 1))
		check(problems.is_empty(), "%s: %s" % [path.get_file(), " / ".join(problems)])
		map.free()

## What a built map looks like, to compare two builds.
func _fingerprint(map: GameMap) -> String:
	var parts := PackedStringArray()
	for room in map.rooms:
		parts.append("%s %s %d" % [room.name, room.position, room.walls_layer().get_used_cells().size()])
	var corridors := map.get_node_or_null("Corridors")
	if corridors:
		parts.append("%d %d" % [corridors.get_node("Floor").get_used_cells().size(), corridors.get_node("Walls").get_used_cells().size()])
	return "\n".join(parts)

func test_same_seed_builds_the_same_map() -> void:
	for path in _maps():
		var a: GameMap = load(path).instantiate()
		if not a.has_layout():
			a.free()
			continue
		var b: GameMap = load(path).instantiate()
		var plan := a.build_layout(7)
		b.build_layout(7)
		check(plan.ok, "%s: %s" % [path.get_file(), plan.problems])
		check_eq(_fingerprint(a), _fingerprint(b), "%s: same seed, same map" % path.get_file())
		check(a.get_node_or_null("Corridors") != null, "%s: corridors were carved" % path.get_file())
		check(a.spawn_points().size() >= GameManager.MAX_PLAYERS, "%s: enough spawn points (%d)" % [path.get_file(), a.spawn_points().size()])
		var teams := a.spawn_teams_of(a.spawn_points())
		check(teams.has(0) and teams.has(1), "%s: both teams get spawn points" % path.get_file())
		a.free()
		b.free()

## Spawn points, weapon spots and card areas placed next to the rooms move
## with the room they stand in when rooms trade places.
func test_things_move_with_their_room() -> void:
	for path in _maps():
		for seed_value in range(1, 6):
			var map: GameMap = load(path).instantiate()
			if not map.has_layout():
				map.free()
				break
			map.build_layout(seed_value)
			for node in map.find_children("*", "", true, false):
				if not (node is SpawnPoint or node is WeaponSpawner or node is PowerupSpawner):
					continue
				var room := map.room_of(node)
				check(room != null, "%s: %s belongs to a room" % [path.get_file(), node.name])
				if room:
					var cell := Vector2i((map._map_point(node) / MapRoom.TILE).floor()) - map._room_origin(room)
					check(room.cells().has(cell), "%s layout %d: %s is still inside %s" % [path.get_file(), seed_value, node.name, room.name])
			map.free()

## Outdoors: roads without walls, ground everywhere between, a wall round it all.
func test_outdoor_maps_are_one_walled_rectangle() -> void:
	# The setting is for future maps; try it on the template (catacombs tiles:
	# room floor as the ground, corridor floor as the roads).
	var map: GameMap = load("res://src/scenes/map_template.tscn").instantiate()
	var rules: MapLayoutRules = map.layout_rules.duplicate()
	rules.outdoors = true
	rules.square = true
	map.layout_rules = rules
	var plan := map.build_layout(3)
	var area := map.outdoor_area(plan)
	check_eq(area.size.x, area.size.y, "square")
	var corridors: Node = map.get_node("Corridors")
	var walls: TileMapLayer = corridors.get_node("Walls")
	var ground: TileMapLayer = corridors.get_node("Ground")
	check_eq(walls.get_used_cells().size(), (area.size.x + area.size.y) * 2 - 4, "the only corridor walls are the ring round the map")
	check_eq(ground.get_used_cells().size(), (area.size.x - 2) * (area.size.y - 2), "ground fills the inside")
	for room in map.rooms:
		var rect := room.used_rect()
		var placed := Rect2i(rect.position + map._room_origin(room), rect.size)
		check(area.grow(-1).encloses(placed), "%s is inside the walls" % room.name)
	map.free()

## The walk grid follows the real tiles: every spawn point can walk to every
## other one (so corridors really connect the doorways), and walls are solid.
func test_every_spawn_point_can_walk_to_every_other() -> void:
	for path in _maps():
		for seed_value in [1, 2, 3]:
			var map: GameMap = load(path).instantiate()
			var has_layout := map.has_layout()
			if has_layout:
				map.build_layout(seed_value)
			var spawns := map.spawn_points()
			var grid := map.walk_grid()
			for i in range(1, spawns.size()):
				var from: Vector2 = map._map_point(spawns[0])
				var to: Vector2 = map._map_point(spawns[i])
				var route := map.find_path(from, to)
				check(not route.is_empty(), "%s layout %d: no way from %s to %s" % [path.get_file(), seed_value, spawns[0].name, spawns[i].name])
				for point in route:
					check(not grid.is_point_solid(Vector2i((point / MapRoom.TILE).floor())), "%s: path through a wall" % path.get_file())
			map.free()
			if not has_layout:
				break
