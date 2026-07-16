extends Control

const LABEL_COLOR := Color(0.82, 0.82, 0.86, 1)
const BINDING_COLOR := Color(0.65, 0.65, 0.7, 1)

const RESOLUTION: Dictionary = {
	"1152 x 648": Vector2i(1152, 648),
	"1280 x 720": Vector2i(1280, 720),
	"1920 x 1080": Vector2i(1920, 1080),
}

@onready var _tab_container: TabContainer = $MarginContainer/ContentPanel/TabContainer
@onready var skip_splash: CheckButton = $MarginContainer/ContentPanel/TabContainer/GameSettings/VBoxContainer/SkipSplash
@onready var resolution: OptionButton = $MarginContainer/ContentPanel/TabContainer/Graphics/VBoxContainer/ResolutionRow/Resolution
@onready var fullscreen: CheckButton = $MarginContainer/ContentPanel/TabContainer/Graphics/VBoxContainer/Fullscreen


func _ready() -> void:
	skip_splash.set_pressed_no_signal(GameSettings.skip_splash)
	_tab_container.set_tab_title(0, "Game")
	resolution.item_selected.connect(on_resolution_selected)
	for label: String in RESOLUTION:
		resolution.add_item(label)

	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_apply_options_theme()


func _on_skip_splash_toggled(toggled_on: bool) -> void:
	GameSettings.set_skip_splash(toggled_on)


func on_resolution_selected(index: int) -> void:
	var selected_text := resolution.get_item_text(index)
	if RESOLUTION.has(selected_text):
		DisplayServer.window_set_size(RESOLUTION[selected_text])


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_options_theme() -> void:
	_style_control(skip_splash)
	_style_control(resolution)
	_style_control(fullscreen)

	for tab_index: int in _tab_container.get_tab_count():
		_style_binding_rows(_tab_container.get_tab_control(tab_index))


func _style_binding_rows(root: Node) -> void:
	for row: HBoxContainer in root.find_children("*", "HBoxContainer", true, false):
		var action := row.get_node_or_null("Action") as Label
		var binding := row.get_node_or_null("Binding") as Label
		if action == null or binding == null:
			continue

		row.custom_minimum_size.y = 36
		action.add_theme_color_override("font_color", LABEL_COLOR)
		action.add_theme_font_size_override("font_size", 15)
		binding.add_theme_color_override("font_color", BINDING_COLOR)
		binding.add_theme_font_size_override("font_size", 14)


func _style_control(control: Control) -> void:
	if control is CheckButton or control is OptionButton:
		control.add_theme_color_override("font_color", LABEL_COLOR)
		control.add_theme_font_size_override("font_size", 15)
