extends "res://tests/test_case.gd"
## Every playable map and the map template pass the checks the editor shows
## on the map's root node (GameMap._get_configuration_warnings).

const MAPS_DIR := "res://src/scenes/maps/"

func _check_map(path: String) -> void:
	var map: Node = load(path).instantiate()
	var warnings: PackedStringArray = map._get_configuration_warnings()
	check(warnings.is_empty(), "%s: %s" % [path.get_file(), " / ".join(warnings)])
	for spawner in map.find_children("*", "WeaponSpawner", true, false):
		check(spawner.weapon_def != null, "%s: weapon spot %s has no weapon" % [path.get_file(), spawner.name])
	map.free()

func test_maps_are_complete() -> void:
	for file in ResourceLoader.list_directory(MAPS_DIR):
		if file.ends_with(".tscn"):
			_check_map(MAPS_DIR + file)

func test_template_is_complete() -> void:
	_check_map("res://src/scenes/map_template.tscn")
