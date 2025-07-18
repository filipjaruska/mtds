extends Node2D
class_name CameraComponent

@onready var camera2d: Camera2D = $Camera2D
@onready var ui_canvas: CanvasLayer = $Camera2D/UI

# default camera settings
var lookahead_distance: float = 175.0
var offset_disable_threshold: float = 200.0
var transition_speed: float = 5.0
var zoom_out_factor: float = 0.7
var zoom_transition_speed: float = 2.0

var player_root: CharacterBody2D

func _ready():
	player_root = get_parent()

func _process(delta):
	_update_camera_offset(delta)

func set_camera_authority(is_authority: bool):
	if not camera2d:
		await ready
	
	if camera2d:
		camera2d.enabled = is_authority
	
	# ui based on authority
	if ui_canvas:
		var ammo_label = ui_canvas.get_node_or_null("Ammo")
		var health_label = ui_canvas.get_node_or_null("Health")
		var weapon_slots = ui_canvas.get_node_or_null("WeaponSlots")
		
		if ammo_label:
			ammo_label.visible = is_authority
		if health_label:
			health_label.visible = is_authority
		if weapon_slots:
			weapon_slots.visible = is_authority

func update_zoom_for_state(is_crouching: bool, delta: float):
	if not camera2d:
		return
		
	var target_zoom = Vector2(1, 1)
	if is_crouching:
		target_zoom = Vector2(zoom_out_factor, zoom_out_factor)
	
	camera2d.zoom = camera2d.zoom.lerp(target_zoom, zoom_transition_speed * delta)

func _update_camera_offset(delta):
	if not camera2d or not player_root:
		return
		
	if InputManager.current_device == InputManager.InputDevice.KEYBOARD_MOUSE:
		var mouse_position: Vector2 = InputManager.get_global_mouse_position()
		var player_position: Vector2 = player_root.global_position
		var distance_to_mouse: float = player_position.distance_to(mouse_position)
		var target_offset: Vector2

		if distance_to_mouse < offset_disable_threshold:
			target_offset = Vector2.ZERO
		else:
			var direction: Vector2 = (mouse_position - player_position).normalized()
			target_offset = direction * lookahead_distance
			
		camera2d.offset = camera2d.offset.lerp(target_offset, transition_speed * delta)
	else:
		var aim_direction = InputManager.last_aim_direction
		if aim_direction.length_squared() > 0.1:
			var target_offset = aim_direction * lookahead_distance
			camera2d.offset = camera2d.offset.lerp(target_offset, transition_speed * delta)

func get_camera() -> Camera2D:
	return camera2d

func get_ui_canvas() -> CanvasLayer:
	return ui_canvas
