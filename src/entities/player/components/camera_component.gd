extends Node2D
class_name CameraComponent

@onready var camera2d: Camera2D = $PlayerCamera
@onready var ui_canvas: CanvasLayer = $PlayerCamera/PlayerUI

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector
# Zoom and lookahead are fixed by ViewRules (weapon ranges depend on them).
var lookahead_distance: float = ViewRules.LOOKAHEAD
var zoom_out_factor: float = ViewRules.CTRL_ZOOM
var offset_disable_threshold: float = RULES.camera_center_radius
var transition_speed: float = RULES.camera_follow_speed
var zoom_transition_speed: float = RULES.camera_zoom_speed

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
	
	# Every player scene carries a HUD; only the local player's may be shown,
	# otherwise the CanvasLayers of all players stack on screen.
	if ui_canvas:
		ui_canvas.visible = is_authority

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
		var target_offset = Vector2.ZERO
		if aim_direction.length_squared() > 0.1:
			target_offset = aim_direction * lookahead_distance
		camera2d.offset = camera2d.offset.lerp(target_offset, transition_speed * delta)

func get_camera() -> Camera2D:
	return camera2d

func get_ui_canvas() -> CanvasLayer:
	return ui_canvas
