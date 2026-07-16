extends Node

const SECTION := "game"
const KEYBINDS_SECTION := "keybinds"

## Actions shown in Options > Keybinds (keyboard/mouse).
const REBINDABLE_ACTIONS: Array[String] = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"shoot",
	"reload",
	"switch_weapon",
	"dash",
	"interact",
	"ui_crouch",
	"ui_drop_weapon",
	"powerup_slot_1",
	"powerup_slot_2",
	"powerup_slot_3",
	"powerup_slot_4",
	"powerup_details",
	"scoreboard",
]

const MOVEMENT_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

var skip_splash: bool = true
var _settings_path: String = ""
var _default_keybinds: Dictionary = {}


func _ready() -> void:
	_settings_path = _resolve_settings_path()
	_store_default_keybinds()
	load_settings()


func _resolve_settings_path() -> String:
	if OS.has_environment("APPDATA"):
		var app_name: String = ProjectSettings.get_setting("application/config/name", "Multiplayer Top-down Shooter")
		var config_dir := OS.get_environment("APPDATA").path_join(app_name)
		DirAccess.make_dir_recursive_absolute(config_dir)
		return config_dir.path_join("settings.cfg")

	return "user://settings.cfg"


func _store_default_keybinds() -> void:
	_default_keybinds.clear()
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event.duplicate())
		_default_keybinds[action] = events


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_settings_path) != OK:
		save_settings()
		return

	skip_splash = bool(config.get_value(SECTION, "skip_splash", false))
	_load_keybinds(config)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(_settings_path)
	config.set_value(SECTION, "skip_splash", skip_splash)
	_save_keybinds(config)
	config.save(_settings_path)


func set_skip_splash(enabled: bool) -> void:
	skip_splash = enabled
	save_settings()


func _save_keybinds(config: ConfigFile) -> void:
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var serialized: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data := serialize_event(event)
			if not data.is_empty():
				serialized.append(data)
		config.set_value(KEYBINDS_SECTION, action, serialized)


func _load_keybinds(config: ConfigFile) -> void:
	if not config.has_section(KEYBINDS_SECTION):
		return

	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if not config.has_section_key(KEYBINDS_SECTION, action):
			continue

		var serialized: Variant = config.get_value(KEYBINDS_SECTION, action, [])
		if typeof(serialized) != TYPE_ARRAY:
			continue

		InputMap.action_erase_events(action)
		for item: Variant in serialized:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var event := deserialize_event(item)
			if event:
				InputMap.action_add_event(action, event)


func reset_keybinds_to_defaults() -> void:
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var defaults: Array = _default_keybinds.get(action, [])
		for event: InputEvent in defaults:
			InputMap.action_add_event(action, event.duplicate())
	save_settings()


func rebind_action(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	if new_event == null:
		return

	_remove_event_from_other_actions(action, new_event)

	var kept: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			kept.append(event)
		elif action in MOVEMENT_ACTIONS and event is InputEventKey and _is_arrow_key(event):
			kept.append(event)

	InputMap.action_erase_events(action)
	for event: InputEvent in kept:
		InputMap.action_add_event(action, event)
	InputMap.action_add_event(action, new_event.duplicate())
	save_settings()


func _remove_event_from_other_actions(except_action: String, new_event: InputEvent) -> void:
	for action: String in REBINDABLE_ACTIONS:
		if action == except_action or not InputMap.has_action(action):
			continue
		var remaining: Array[InputEvent] = []
		var removed := false
		for event: InputEvent in InputMap.action_get_events(action):
			if _events_match(event, new_event):
				removed = true
				continue
			remaining.append(event)
		if removed:
			InputMap.action_erase_events(action)
			for event: InputEvent in remaining:
				InputMap.action_add_event(action, event)


func get_action_binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"

	var parts: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			continue
		if action in MOVEMENT_ACTIONS and event is InputEventKey and _is_arrow_key(event):
			continue
		var label := _event_display_name(event)
		if not label.is_empty() and label not in parts:
			parts.append(label)

	if parts.is_empty():
		return "—"
	return " / ".join(parts)


func serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"keycode": int(key_event.keycode),
			"physical_keycode": int(key_event.physical_keycode),
			"device": int(key_event.device),
		}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": int(mouse_event.button_index),
			"device": int(mouse_event.device),
		}
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": int(joy_event.button_index),
			"device": int(joy_event.device),
		}
	return {}


func deserialize_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.keycode = data.get("keycode", 0) as Key
			key_event.physical_keycode = data.get("physical_keycode", 0) as Key
			key_event.device = int(data.get("device", -1))
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = data.get("button_index", 0) as MouseButton
			mouse_event.device = int(data.get("device", -1))
			return mouse_event
		"joy_button":
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = data.get("button_index", 0) as JoyButton
			joy_event.device = int(data.get("device", -1))
			return joy_event
	return null


func _event_display_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Mouse Button"
			MOUSE_BUTTON_RIGHT:
				return "Right Mouse Button"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Mouse Button"
			MOUSE_BUTTON_XBUTTON1:
				return "Mouse Button 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Mouse Button 5"
			_:
				return event.as_text()
	return event.as_text()


func _is_arrow_key(event: InputEventKey) -> bool:
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]


func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var a_key := a as InputEventKey
		var b_key := b as InputEventKey
		var a_code: Key = a_key.physical_keycode if a_key.physical_keycode != KEY_NONE else a_key.keycode
		var b_code: Key = b_key.physical_keycode if b_key.physical_keycode != KEY_NONE else b_key.keycode
		return a_code != KEY_NONE and a_code == b_code
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	return false
