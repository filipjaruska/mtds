extends "res://tests/test_case.gd"
## Everyone sees the same view, and gun ranges stay tied to it (ViewRules).

func test_view_size_matches_project_settings() -> void:
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), int(ViewRules.VIEW_SIZE.x))
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), int(ViewRules.VIEW_SIZE.y))
	check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "same view on every screen size")
	check_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep_height", "same height on every aspect")

func test_player_camera_uses_view_rules() -> void:
	# The player scene stores its own copies of the camera values; they win at
	# runtime. Read them from the file: loading the scene here would compile
	# scripts that need autoloads.
	var text := FileAccess.get_file_as_string("res://src/entities/player/player.tscn")
	check_eq(_scene_value(text, "camera_zoom_out_factor", ViewRules.CTRL_ZOOM), ViewRules.CTRL_ZOOM, "Ctrl zoom")
	check_eq(_scene_value(text, "camera_lookahead_distance", ViewRules.LOOKAHEAD), ViewRules.LOOKAHEAD, "look-ahead")

func _scene_value(text: String, key: String, fallback: float) -> float:
	var regex := RegEx.create_from_string("(?m)^" + key + " = ([0-9.]+)$")
	var found := regex.search(text)
	return found.get_string(1).to_float() if found else fallback

func test_reach() -> void:
	check_eq(ViewRules.reach(1.0, &"vertical"), 432.0 + 175.0)
	check_eq(ViewRules.reach(1.0, &"sideways"), 768.0 + 175.0)
	check(ViewRules.reach(ViewRules.CTRL_ZOOM, &"vertical") > ViewRules.reach(1.0, &"vertical"), "Ctrl sees further")

func test_bands_are_ordered() -> void:
	var close := ViewRules.range_band(&"close")
	var standard := ViewRules.range_band(&"standard")
	var marksman := ViewRules.range_band(&"marksman")
	check_eq(close[1], standard[0], "standard starts where the default view ends")
	check(standard[1] < marksman[0], "marksman is beyond the Ctrl view")

func test_every_weapon_range_fits_its_band() -> void:
	var defs := WeaponDefs.all()
	check(defs.size() >= 5, "all weapons loaded")
	for def in defs:
		var band := ViewRules.range_band(def.range_class)
		check(band[1] > 0.0, "%s: unknown range_class '%s'" % [def.id, def.range_class])
		check(def.max_range >= band[0] and def.max_range <= band[1],
			"%s: range %.0f outside its %s band %.0f-%.0f" % [def.id, def.max_range, def.range_class, band[0], band[1]])
