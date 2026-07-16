extends Control

const MAIN_MENU_SCENE := "res://src/ui/menus/main.tscn"
const DISPLAY_DURATION := 2.0
const FADE_DURATION := 0.5


func _ready() -> void:
	if GameSettings.skip_splash:
		get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
		return

	await get_tree().create_timer(DISPLAY_DURATION).timeout

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
