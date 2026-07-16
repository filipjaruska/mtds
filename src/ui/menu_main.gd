extends Control

@onready var _preview: TextureRect = $MarginContainer/ContentPanel/ScrollContainer/HBoxContainer/PreviewPanel/Padding/VBox/Preview
@onready var _color_picker: ColorPicker = $MarginContainer/ContentPanel/ScrollContainer/HBoxContainer/PickerPanel/Padding/VBox/ColorPicker
@onready var _reset_button: Button = $MarginContainer/ContentPanel/ScrollContainer/HBoxContainer/PickerPanel/Padding/VBox/ResetButton


func _ready() -> void:
	var color := GameSettings.player_color
	color.a = 1.0
	_preview.modulate = color
	_color_picker.edit_alpha = false
	_color_picker.sampler_visible = false
	_color_picker.color_modes_visible = false
	_color_picker.presets_visible = false
	_color_picker.hex_visible = false
	_color_picker.can_add_swatches = false
	_color_picker.color = color
	_color_picker.color_changed.connect(_on_color_changed)
	_reset_button.pressed.connect(_on_reset_pressed)


func _on_color_changed(color: Color) -> void:
	color.a = 1.0
	_preview.modulate = color
	GameSettings.set_player_color(color)


func _on_reset_pressed() -> void:
	var color := Color.WHITE
	_color_picker.color = color
	_preview.modulate = color
	GameSettings.set_player_color(color)
