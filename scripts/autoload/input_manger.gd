extends Node

signal input_device_changed(device: String)

enum InputDevice { KEYBOARD_MOUSE, GAMEPAD }
var current_device: InputDevice = InputDevice.KEYBOARD_MOUSE
var last_movement_input := Vector2.ZERO

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
    
    if input_vector != last_movement_input:
        last_movement_input = input_vector
    
    return input_vector

func is_moving() -> bool:
    return get_movement_vector().length_squared() > 0.1

func is_dash_pressed() -> bool:
    return Input.is_action_just_pressed("dash")

func is_shoot_pressed() -> bool:
    return Input.is_action_pressed("shoot")

func is_reload_pressed() -> bool:
    return Input.is_action_just_pressed("reload")

func is_crouch_pressed() -> bool:
    return Input.is_action_pressed("ui_crouch")

func is_interact_pressed() -> bool:
    return Input.is_action_just_pressed("interact")

func is_weapon_switch_pressed() -> bool:
    return Input.is_action_just_pressed("switch_weapon")

func is_weapon_1_pressed() -> bool:
    return Input.is_action_just_pressed("switch_weapon_1")

func is_weapon_2_pressed() -> bool:
    return Input.is_action_just_pressed("switch_weapon_2")

func is_drop_weapon_pressed() -> bool:
    return Input.is_action_just_pressed("ui_drop_weapon")

func get_global_mouse_position() -> Vector2:
    var viewport = get_viewport()
    if viewport:
        var camera = viewport.get_camera_2d()
        if camera:
            return camera.get_global_mouse_position()
    # Fallback to viewport position (for cutscenes/animations?)
    return get_viewport().get_mouse_position()

# TODO Fix - camera panning to the right; with controller; while not using right stick
# TODO Implement - rest of the controller inputs
func get_aim_direction(player_position: Vector2) -> Vector2:
    if current_device == InputDevice.KEYBOARD_MOUSE:
        var mouse_pos = get_global_mouse_position()
        return (mouse_pos - player_position).normalized()
    else:
        var aim_vector = Vector2(
            Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
            Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
        )
        
        # For deadzone
        if aim_vector.length_squared() > 0.1:
            return aim_vector.normalized()
        
        # Use movement direction or last known direction if right stick isn't being used
        var movement = get_movement_vector()
        return movement if movement.length_squared() > 0.1 else Vector2.RIGHT

# TODO Fix - Controller button inputs
func get_controller_button(button_name: String) -> bool:
    match button_name:
        "shoot": return Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
        "reload": return Input.is_joy_button_pressed(0, JOY_BUTTON_X)
        "dash": return Input.is_joy_button_pressed(0, JOY_BUTTON_A)
        "interact": return Input.is_joy_button_pressed(0, JOY_BUTTON_B)
    return false
