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
		var problems := map.layout_problems(range(1, SEEDS + 1), true)
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
