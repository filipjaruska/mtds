extends "res://tests/test_case.gd"
## Every playable map, the map template and every room pass the checks the
## editor shows (configuration warnings), and slot maps work for many layouts.

const MAPS_DIR := "res://src/scenes/maps/"
const ROOMS_DIR := "res://src/scenes/rooms/"
## Layouts tried per slot map.
const SEEDS := 40

func _maps() -> Array[String]:
	var out: Array[String] = ["res://src/scenes/map_template.tscn"]
	for file in ResourceLoader.list_directory(MAPS_DIR):
		if file.ends_with(".tscn"):
			out.append(MAPS_DIR + file)
	return out

func _rooms(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with("/"):
			out.append_array(_rooms(dir + file))
		elif file.ends_with(".tscn"):
			out.append(dir + file)
	return out

func test_maps_are_complete() -> void:
	for path in _maps():
		var map: Node = load(path).instantiate()
		var warnings: PackedStringArray = map._get_configuration_warnings()
		check(warnings.is_empty(), "%s: %s" % [path.get_file(), " / ".join(warnings)])
		for spawner in map.find_children("*", "WeaponSpawner", true, false):
			check(spawner.weapon_def != null, "%s: weapon spot %s has no weapon" % [path.get_file(), spawner.name])
		map.free()

func test_slot_maps_work_for_many_layouts() -> void:
	for path in _maps():
		var map: GameMap = load(path).instantiate()
		if map.has_slots():
			var problems := map.layout_problems(range(1, SEEDS + 1), true)
			check(problems.is_empty(), "%s: %s" % [path.get_file(), " / ".join(problems)])
		else:
			var problems := map.layout_problems([0], true)
			check(problems.is_empty(), "%s: %s" % [path.get_file(), " / ".join(problems)])
		map.free()

func test_rooms_are_complete() -> void:
	for path in _rooms(ROOMS_DIR):
		var room: Node = load(path).instantiate()
		check(room is MapRoom, "%s: root is not a MapRoom" % path.get_file())
		if room is MapRoom:
			var warnings: PackedStringArray = room._get_configuration_warnings()
			check(warnings.is_empty(), "%s: %s" % [path.get_file(), " / ".join(warnings)])
		room.free()

## What a built layout looks like, to compare two builds.
func _fingerprint(map: GameMap) -> String:
	var parts := PackedStringArray()
	for room in map.rooms:
		parts.append("%s %s %s" % [room.name, room.scene_file_path.get_file(), room.transform])
		var walls := room.walls_layer()
		parts.append(str(walls.get_used_cells().size()) if walls else "-")
	return "\n".join(parts)

func test_same_seed_builds_the_same_rooms() -> void:
	for path in _maps():
		var a: GameMap = load(path).instantiate()
		if not a.has_slots():
			a.free()
			continue
		var b: GameMap = load(path).instantiate()
		var plan := a.build_layout(7, a)
		b.build_layout(7, b)
		check(plan.ok, "%s: %s" % [path.get_file(), plan.problems])
		check_eq(a.rooms.size(), plan.rooms.size(), "%s: one room per filled slot" % path.get_file())
		check_eq(_fingerprint(a), _fingerprint(b), "%s: same seed, same rooms" % path.get_file())
		check(a.spawn_points().size() >= GameManager.MAX_PLAYERS, "%s: enough spawn points (%d)" % [path.get_file(), a.spawn_points().size()])
		var teams := a.spawn_teams_of(a.spawn_points())
		check(teams.has(0) and teams.has(1), "%s: both teams get spawn points" % path.get_file())
		a.free()
		b.free()

func test_rooms_land_inside_their_slots() -> void:
	var map: GameMap = load("res://src/scenes/maps/crypts.tscn").instantiate()
	for seed_value in range(1, 6):
		for room in map.rooms:
			room.free()
		map.build_layout(seed_value, map)
		var size := map.layout_rules.slot_pixels()
		for room in map.rooms:
			var parts := String(room.name).split("_")
			var slot := Rect2(Vector2(int(parts[1]), int(parts[2])) * size, size)
			var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)].map(func(c): return room.transform * c)
			for corner in corners:
				check(slot.grow(0.5).has_point(corner), "seed %d: %s corner %s outside its slot %s" % [seed_value, room.name, corner, slot])
	map.free()
