extends SceneTree
## Rebuilds the project theme from UiPalette and saves it. Run after changing
## src/ui/theme/ui_palette.gd:
##   godot --headless --path . -s res://tools/build_theme.gd

const OUT := "res://src/ui/theme/main_theme.tres"

func _init() -> void:
	var palette = load("res://src/ui/theme/ui_palette.gd")
	var err := ResourceSaver.save(palette.build_theme(), OUT)
	print("theme -> ", OUT, " ", error_string(err))
	quit(0 if err == OK else 1)
