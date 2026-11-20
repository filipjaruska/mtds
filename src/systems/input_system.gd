extends Node
## The manager automatically detects the current input device and provides
## device-agnostic methods for all game actions.
##
## Buttons and triggers are read through the InputMap (see project.godot), so
## both keyboard/mouse and gamepad bindings live in one place and "just pressed"
## semantics are the same for every device. Only analog sticks are read directly.

signal input_device_changed(device: String)

enum InputDevice {
	KEYBOARD_MOUSE,
	GAMEPAD
}

var current_device: InputDevice = InputDevice.KEYBOARD_MOUSE
var last_movement_input := Vector2.ZERO
var last_aim_direction := Vector2.RIGHT

const INPUT_THRESHOLD: float = 0.5
const AIM_DEADZONE: float = 0.2 # for gamepad
const MOVEMENT_DEADZONE: float = 0.1

## The gamepad that most recently produced input; sticks are read from it.
var _joy_device: int = 0

## Switch the active device based on whichever device actually produced input.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_joy_device = event.device
		_set_device(InputDevice.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > INPUT_THRESHOLD:
			_joy_device = event.device
			_set_device(InputDevice.GAMEPAD)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_device(InputDevice.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_set_device(InputDevice.KEYBOARD_MOUSE)

func _set_device(device: InputDevice) -> void:
	if current_device == device:
		return
	current_device = device
	input_device_changed.emit("gamepad" if device == InputDevice.GAMEPAD else "keyboard_mouse")

## Get the movement vector from input with proper analog magnitude and deadzone handling
##
## @return Vector2 representing the movement direction and magnitude
func get_movement_vector() -> Vector2:
	if _typing():
		return Vector2.ZERO
	var input_vector := Vector2.ZERO

	if current_device == InputDevice.GAMEPAD:
		input_vector = Vector2(
			Input.get_joy_axis(_joy_device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(_joy_device, JOY_AXIS_LEFT_Y)
		)
	else:
		input_vector = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)

	if input_vector.length() < MOVEMENT_DEADZONE:
		input_vector = Vector2.ZERO
	else:
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		last_movement_input = input_vector

	return input_vector

func is_moving() -> bool:
	return get_movement_vector() != Vector2.ZERO

func is_dash_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("dash")

func is_shoot_pressed() -> bool:
	return not _typing() and Input.is_action_pressed("shoot")

func is_reload_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("reload")

func is_crouch_pressed() -> bool:
	return not _typing() and Input.is_action_pressed("ui_crouch")

func is_interact_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("interact")

func is_weapon_switch_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("switch_weapon")

func is_weapon_1_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("switch_weapon_1")

func is_weapon_2_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("switch_weapon_2")

func is_drop_weapon_pressed() -> bool:
	return not _typing() and Input.is_action_just_pressed("ui_drop_weapon")

func is_powerup_details_held() -> bool:
	return not _typing() and Input.is_action_pressed("powerup_details")

func is_powerup_shuffle_held() -> bool:
	return not _typing() and Input.is_action_pressed("powerup_shuffle")

func is_scoreboard_held() -> bool:
	return not _typing() and Input.is_action_pressed("scoreboard")

func get_powerup_slot_use_index() -> int:
	if _typing():
		return -1
	if Input.is_action_just_pressed("powerup_slot_1"):
		return 0
	if Input.is_action_just_pressed("powerup_slot_2"):
		return 1
	if Input.is_action_just_pressed("powerup_slot_3"):
		return 2
	if Input.is_action_just_pressed("powerup_slot_4"):
		return 3
	return -1

## Get the global mouse position in world coordinates
##
## @return Vector2 representing the mouse position in world space
func get_global_mouse_position() -> Vector2:
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_2d()
		if camera:
			return camera.get_global_mouse_position()
	return get_viewport().get_mouse_position() # Fallback to viewport position (for #TODO: cutscenes/animations?)

## Get the aim direction based on current input device
##
## For keyboard/mouse: direction from player to mouse cursor
## For gamepad: right stick direction with deadzone handling
## @param player_position The current player position for mouse aiming
## @return Vector2 representing the normalized aim direction
func get_aim_direction(player_position: Vector2) -> Vector2:
	if current_device == InputDevice.KEYBOARD_MOUSE:
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - player_position).normalized()
		if direction != Vector2.ZERO:
			last_aim_direction = direction
		return last_aim_direction
	else:
		var aim_vector = Vector2(
			Input.get_joy_axis(_joy_device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(_joy_device, JOY_AXIS_RIGHT_Y)
		)

		if aim_vector.length_squared() > AIM_DEADZONE:
			last_aim_direction = aim_vector.normalized()
			return last_aim_direction

		var movement = get_movement_vector()
		if movement.length_squared() > MOVEMENT_DEADZONE:
			last_aim_direction = movement

		return last_aim_direction

## A chat message is being typed: gameplay input is muted (aim still works).
func _typing() -> bool:
	return ChatManager.is_typing
