extends CharacterBody2D

@onready var weapon_manager = $Node2D/WeaponManager
@onready var camera2d = $Camera2D
@onready var dash_cooldown_indicator = $Camera2D/UI/DashCooldownIndicator

# Movement speeds
@export var normal_speed: float = 200.0 # pixels per second
@export var dash_speed: float = 800.0 # pixels per second
@export var crouch_speed: float = 100.0 # pixels per second

# Dash settings
@export var dash_duration: float = 0.3 # seconds
@export var dash_cooldown: float = 3500.0 # milliseconds

# Camera settings
@export var camera_lookahead_distance: float = 175.0 # pixels
@export var offset_disable_threshold: float = 200.0 # pixels
@export var camera_transition_speed: float = 5.0 # interpolation factor
@export var camera_zoom_out_factor: float = 0.7 # zoom factor when crouching
@export var camera_zoom_transition_speed: float = 2.0 # zoom transition speed

var current_speed: float
var last_dash_time: float = 0 
var is_dashing: bool = false
var is_crouching: bool = false
var dash_direction: Vector2 = Vector2.ZERO

func _ready():
	current_speed = normal_speed

	var authority_id: int = str(name).to_int()
	weapon_manager.multiplayer_sync.set_multiplayer_authority(authority_id)
	$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)
	var is_authority = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	$Camera2D.enabled = is_authority
	$Camera2D/UI/Ammo.visible = is_authority
	$Camera2D/UI/Health.visible = is_authority
	$Camera2D/UI/WeaponSlots.visible = is_authority
	dash_cooldown_indicator.visible = is_authority

func _process(delta):
	handle_movement()
	handle_dashing()
	handle_crouching(delta)
	weapon_manager._process(delta)
	update_camera_offset(delta)
	update_dash_cooldown_indicator()

func _physics_process(_delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction: Vector2 = (get_global_mouse_position() - global_position).normalized()
		$Node2D.rotation = direction.angle()

func handle_movement():
	if not is_dashing:
		var input_vector: Vector2 = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		).normalized() * current_speed
		velocity = input_vector
		move_and_slide()

func handle_dashing():
	if Input.is_action_just_pressed("Dash") and not is_dashing and not is_crouching and (Time.get_ticks_msec() - last_dash_time) >= dash_cooldown:
		is_dashing = true
		current_speed = dash_speed
		dash_direction = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		).normalized()
		await get_tree().create_timer(dash_duration).timeout
		is_dashing = false
		current_speed = normal_speed
		last_dash_time = Time.get_ticks_msec()

	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()

func handle_crouching(delta):
	if Input.is_action_pressed("ui_crouch"):
		is_crouching = true
		current_speed = crouch_speed
		camera2d.zoom = camera2d.zoom.lerp(Vector2(camera_zoom_out_factor, camera_zoom_out_factor), camera_zoom_transition_speed * delta)
	else:
		is_crouching = false
		current_speed = normal_speed
		camera2d.zoom = camera2d.zoom.lerp(Vector2(1, 1), camera_zoom_transition_speed * delta)

func update_camera_offset(delta):
	var mouse_position: Vector2 = get_global_mouse_position()
	var player_position: Vector2 = global_position
	var distance_to_mouse: float = player_position.distance_to(mouse_position)
	var target_offset: Vector2

	if distance_to_mouse < offset_disable_threshold:
		target_offset = Vector2.ZERO
	else:
		var direction: Vector2 = (mouse_position - player_position).normalized()
		target_offset = direction * camera_lookahead_distance

	camera2d.offset = camera2d.offset.lerp(target_offset, camera_transition_speed * delta)

func update_dash_cooldown_indicator():
	var cooldown_progress: float = clamp((Time.get_ticks_msec() - last_dash_time) / dash_cooldown, 0, 1)
	dash_cooldown_indicator.value = cooldown_progress

func set_player_name(player_name: String):
	$Name.text = player_name
