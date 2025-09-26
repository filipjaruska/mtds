extends Control


@onready var resolution: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/Resolution as OptionButton
const RESOLUTION: Dictionary = {
		"1152 x 648": Vector2i(1152, 648),
		"1280 x 720": Vector2i(1280, 720),
		"1920 x 1080": Vector2i(1920, 1080),
}

func _ready():
	resolution.item_selected.connect(on_resolution_selected)
	for i in RESOLUTION:
		resolution.add_item(i)
	
func on_resolution_selected(index: int):
	var selected_text = resolution.get_item_text(index)
	if RESOLUTION.has(selected_text):
		DisplayServer.window_set_size(RESOLUTION[selected_text])
	else:
		return

func _on_exit_pressed():
	get_tree().change_scene_to_file("res://src/ui/menus/main.tscn")

func _on_check_button_toggled(toggled_on):
	if !toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
