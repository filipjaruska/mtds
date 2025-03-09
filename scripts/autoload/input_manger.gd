extends Node

signal input_device_changed(device: String)

enum InputDevice { KEYBOARD_MOUSE, GAMEPAD }
var current_device: InputDevice = InputDevice.KEYBOARD_MOUSE
var last_movement_input := Vector2.ZERO
var last_aim_direction := Vector2.RIGHT

# Switch input devices
func _process(_delta: float) -> void:
    if Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_B) or \
       abs(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.5 or abs(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) > 0.5:
        if current_device != InputDevice.GAMEPAD:
            current_device = InputDevice.GAMEPAD
            input_device_changed.emit("gamepad")
    elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or \
         Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or \
         Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D):
        if current_device != InputDevice.KEYBOARD_MOUSE:
            current_device = InputDevice.KEYBOARD_MOUSE
            input_device_changed.emit("keyboard_mouse")

func get_movement_vector() -> Vector2:
    var input_vector := Vector2(
        Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    ).normalized()
    
    if input_vector != Vector2.ZERO:
        last_movement_input = input_vector
    
    return input_vector

func is_moving() -> bool:
    return get_movement_vector().length_squared() > 0.1

func is_dash_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("dash")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_A)

func is_shoot_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_pressed("shoot")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)

func is_reload_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("reload")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_X)

func is_crouch_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_pressed("ui_crouch")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)

func is_interact_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("interact")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_B)

func is_weapon_switch_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("switch_weapon")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_Y)

func is_weapon_1_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("switch_weapon_1")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)

func is_weapon_2_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("switch_weapon_2")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)

func is_drop_weapon_pressed() -> bool:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        return Input.is_action_just_pressed("ui_drop_weapon")
    else:
        return Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)

func get_global_mouse_position() -> Vector2:
    var viewport = get_viewport()
    if viewport:
        var camera = viewport.get_camera_2d()
        if camera:
            return camera.get_global_mouse_position()
    # Fallback to viewport position (for cutscenes/animations?)
    return get_viewport().get_mouse_position()

func get_aim_direction(player_position: Vector2) -> Vector2:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        var mouse_pos = get_global_mouse_position()
        var direction = (mouse_pos - player_position).normalized()
        if direction != Vector2.ZERO:
            last_aim_direction = direction
        return last_aim_direction
    else:
        var aim_vector = Vector2(
            Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
            Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
        )
        
        # For deadzone
        if aim_vector.length_squared() > 0.2:
            last_aim_direction = aim_vector.normalized()
            return last_aim_direction
        
        # If no right stick input, keep last aim direction unless moving in new direction
        var movement = get_movement_vector()
        if movement.length_squared() > 0.1:
            last_aim_direction = movement
            
        return last_aim_direction
