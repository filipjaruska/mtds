extends Control

const LABEL_COLOR := Color(0.82, 0.82, 0.86, 1)
const BINDING_COLOR := Color(0.65, 0.65, 0.7, 1)
const BINDING_HOVER_COLOR := Color(1, 1, 1, 1)
const LISTENING_COLOR := Color(0.98, 0.58, 0.08, 1)

const RESOLUTION: Dictionary = {
	"1152 x 648": Vector2i(1152, 648),
	"1280 x 720": Vector2i(1280, 720),
	"1920 x 1080": Vector2i(1920, 1080),
}

## Options Keybinds row node name -> InputMap action
const KEYBIND_ROWS: Dictionary = {
	"MoveUp": "ui_up",
	"MoveDown": "ui_down",
	"MoveLeft": "ui_left",
	"MoveRight": "ui_right",
	"Shoot": "shoot",
	"Reload": "reload",
	"SwitchWeapon": "switch_weapon",
	"Dash": "dash",
	"Interact": "interact",
	"Crouch": "ui_crouch",
	"DropWeapon": "ui_drop_weapon",
	"PowerupSlot1": "powerup_slot_1",
	"PowerupSlot2": "powerup_slot_2",
	"PowerupSlot3": "powerup_slot_3",
	"PowerupSlot4": "powerup_slot_4",
	"PowerupDetails": "powerup_details",
	"Scoreboard": "scoreboard",
}

@onready var _tab_container: TabContainer = $MarginContainer/ContentPanel/TabContainer
@onready var skip_splash: CheckButton = $MarginContainer/ContentPanel/TabContainer/GameSettings/VBoxContainer/SkipSplash
@onready var resolution: OptionButton = $MarginContainer/ContentPanel/TabContainer/Graphics/VBoxContainer/ResolutionRow/Resolution
@onready var fullscreen: CheckButton = $MarginContainer/ContentPanel/TabContainer/Graphics/VBoxContainer/Fullscreen
@onready var _keybinds_list: VBoxContainer = $MarginContainer/ContentPanel/TabContainer/Keybinds/ScrollContainer/VBoxContainer

var _binding_labels: Dictionary = {} # action -> Label
var _listening_action: String = ""
var _listening_label: Label = null
var _rebind_armed: bool = false


func _ready() -> void:
	set_process_input(false)
	skip_splash.set_pressed_no_signal(GameSettings.skip_splash)
	_tab_container.set_tab_title(0, "Game")
	resolution.item_selected.connect(on_resolution_selected)
	for label: String in RESOLUTION:
		resolution.add_item(label)

	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_setup_keybind_rows()
	_add_reset_keybinds_button()
	_refresh_all_binding_labels()
	_apply_options_theme()


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty() or not _rebind_armed:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		_finish_rebind(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_finish_rebind(event)
		get_viewport().set_input_as_handled()


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


func _setup_keybind_rows() -> void:
	_binding_labels.clear()
	for row_name: String in KEYBIND_ROWS:
		var action: String = KEYBIND_ROWS[row_name]
		var row: HBoxContainer = _keybinds_list.get_node_or_null(row_name) as HBoxContainer
		if row == null:
			continue
		var binding := row.get_node_or_null("Binding") as Label
		if binding == null:
			continue

		_binding_labels[action] = binding
		binding.mouse_filter = Control.MOUSE_FILTER_STOP
		binding.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		binding.gui_input.connect(_on_binding_gui_input.bind(action, binding))
		binding.mouse_entered.connect(_on_binding_mouse_entered.bind(binding))
		binding.mouse_exited.connect(_on_binding_mouse_exited.bind(binding))
		_ensure_row_scrollbar_pad(row)


func _ensure_row_scrollbar_pad(row: HBoxContainer) -> void:
	if row.get_node_or_null("ScrollPad") != null:
		return
	var pad := Control.new()
	pad.name = "ScrollPad"
	pad.custom_minimum_size = Vector2(28, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)


func _add_reset_keybinds_button() -> void:
	if _keybinds_list.get_node_or_null("ResetKeybinds") != null:
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_keybinds_list.add_child(spacer)

	var reset_button := Button.new()
	reset_button.name = "ResetKeybinds"
	reset_button.text = "Reset Keybinds to Defaults"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_on_reset_keybinds_pressed)
	_keybinds_list.add_child(reset_button)


func _on_reset_keybinds_pressed() -> void:
	_cancel_rebind()
	GameSettings.reset_keybinds_to_defaults()
	_refresh_all_binding_labels()


func _on_binding_gui_input(event: InputEvent, action: String, binding: Label) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_rebind(action, binding)
		accept_event()


func _on_binding_mouse_entered(binding: Label) -> void:
	if _listening_label == binding:
		return
	binding.add_theme_color_override("font_color", BINDING_HOVER_COLOR)


func _on_binding_mouse_exited(binding: Label) -> void:
	if _listening_label == binding:
		return
	binding.add_theme_color_override("font_color", BINDING_COLOR)


func _start_rebind(action: String, binding: Label) -> void:
	if _listening_action == action:
		_cancel_rebind()
		return

	_cancel_rebind()
	_listening_action = action
	_listening_label = binding
	_rebind_armed = false
	binding.text = "Press key... (Esc to cancel)"
	binding.add_theme_color_override("font_color", LISTENING_COLOR)
	set_process_input(true)
	call_deferred("_arm_rebind")


func _arm_rebind() -> void:
	if not _listening_action.is_empty():
		_rebind_armed = true


func _cancel_rebind() -> void:
	var previous_label := _listening_label
	_listening_action = ""
	_listening_label = null
	_rebind_armed = false
	set_process_input(false)
	if previous_label:
		_refresh_binding_label_for_node(previous_label)


func _finish_rebind(event: InputEvent) -> void:
	var action := _listening_action
	if action.is_empty():
		return

	GameSettings.rebind_action(action, event)
	_listening_action = ""
	_listening_label = null
	_rebind_armed = false
	set_process_input(false)
	_refresh_all_binding_labels()


func _refresh_all_binding_labels() -> void:
	for action: String in _binding_labels:
		var binding: Label = _binding_labels[action]
		binding.text = GameSettings.get_action_binding_text(action)
		binding.add_theme_color_override("font_color", BINDING_COLOR)


func _refresh_binding_label_for_node(binding: Label) -> void:
	for action: String in _binding_labels:
		if _binding_labels[action] == binding:
			binding.text = GameSettings.get_action_binding_text(action)
			binding.add_theme_color_override("font_color", BINDING_COLOR)
			return


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
