extends CharacterBody2D

@onready var weapon_manager = $Node2D/WeaponManager
@onready var camera2d = $Camera2D
@onready var dash_cooldown_indicator = $Camera2D/UI/DashCooldownIndicator

@export_group("Movement")
@export var normal_speed: float = 200.0 	# pixels per second
@export var dash_speed: float = 800.0 		# pixels per second
@export var crouch_speed: float = 100.0 	# pixels per second

@export_group("Dash Settings")
@export var dash_duration: float = 0.3 		# seconds
@export var dash_cooldown: float = 3500.0 	# milliseconds

@export_group("Camera Settings")
@export var camera_lookahead_distance: float = 175.0 	# pixels
@export var offset_disable_threshold: float = 200.0	 	# pixels
@export var camera_transition_speed: float = 5.0 		# interpolation factor
@export var camera_zoom_out_factor: float = 0.7 		# zoom factor when crouching
@export var camera_zoom_transition_speed: float = 2.0 	# zoom transition speed

enum PlayerState {
	NORMAL,
	DASHING,
	CROUCHING
}

var current_state: PlayerState = PlayerState.NORMAL
var current_speed: float
var last_dash_time: float = 0 
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: SceneTreeTimer = null

func _ready():
	current_speed = normal_speed

	var authority_id: int = str(name).to_int()
	weapon_manager.multiplayer_sync.set_multiplayer_authority(authority_id)
	$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)
	var is_authority = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	camera2d.enabled = is_authority
	$Camera2D/UI/Ammo.visible = is_authority
	$Camera2D/UI/Health.visible = is_authority
	$Camera2D/UI/WeaponSlots.visible = is_authority
	dash_cooldown_indicator.visible = is_authority

func _process(delta):
	check_state_transitions()
	process_current_state(delta)
	weapon_manager._process(delta)
	update_camera_offset(delta)
	update_dash_cooldown_indicator()

func _physics_process(_delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction: Vector2 = InputManager.get_aim_direction(global_position)
		$Node2D.rotation = direction.angle()

func check_state_transitions():
	if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
		
	match current_state:
		PlayerState.NORMAL:
			if InputManager.is_dash_pressed() and (Time.get_ticks_msec() - last_dash_time) >= dash_cooldown:
				change_state(PlayerState.DASHING)
			elif InputManager.is_crouch_pressed():
				change_state(PlayerState.CROUCHING)
		
		PlayerState.CROUCHING:
			if not InputManager.is_crouch_pressed():
				change_state(PlayerState.NORMAL)

func process_current_state(delta):
	match current_state:
		PlayerState.NORMAL:
			process_normal_state()
			
		PlayerState.DASHING:
			process_dashing_state()
			
		PlayerState.CROUCHING:
			process_crouching_state()
	
	update_camera_zoom(delta)

func change_state(new_state: PlayerState):
	match current_state:
		PlayerState.DASHING:
			if dash_timer and dash_timer.time_left > 0:
				dash_timer.timeout.disconnect(_on_dash_timer_timeout)
			last_dash_time = Time.get_ticks_msec()
	
	current_state = new_state
	
	match new_state:
		PlayerState.NORMAL:
			current_speed = normal_speed
		
		PlayerState.DASHING:
			current_speed = dash_speed
			dash_direction = InputManager.get_movement_vector()
			dash_timer = get_tree().create_timer(dash_duration)
			dash_timer.timeout.connect(_on_dash_timer_timeout)
		
		PlayerState.CROUCHING:
			current_speed = crouch_speed

func process_normal_state():
	var input_vector: Vector2 = InputManager.get_movement_vector() * current_speed
	velocity = input_vector
	move_and_slide()

func process_dashing_state():
	velocity = dash_direction * dash_speed
	move_and_slide()

func process_crouching_state():
	var input_vector: Vector2 = InputManager.get_movement_vector() * current_speed
	velocity = input_vector
	move_and_slide()

func _on_dash_timer_timeout():
	change_state(PlayerState.NORMAL)

func update_camera_zoom(delta):
	var target_zoom = Vector2(1, 1)
	if current_state == PlayerState.CROUCHING:
		target_zoom = Vector2(camera_zoom_out_factor, camera_zoom_out_factor)
	
	camera2d.zoom = camera2d.zoom.lerp(target_zoom, camera_zoom_transition_speed * delta)

func update_camera_offset(delta):
	if InputManager.current_device == InputManager.InputDevice.KEYBOARD_MOUSE:
		var mouse_position: Vector2 = InputManager.get_global_mouse_position()
		var player_position: Vector2 = global_position
		var distance_to_mouse: float = player_position.distance_to(mouse_position)
		var target_offset: Vector2

		if distance_to_mouse < offset_disable_threshold:
			target_offset = Vector2.ZERO
		else:
			var direction: Vector2 = (mouse_position - player_position).normalized()
			target_offset = direction * camera_lookahead_distance
            
		camera2d.offset = camera2d.offset.lerp(target_offset, camera_transition_speed * delta)
	else:
		var aim_direction = InputManager.last_aim_direction
		if aim_direction.length_squared() > 0.1:
			var target_offset = aim_direction * camera_lookahead_distance
			camera2d.offset = camera2d.offset.lerp(target_offset, camera_transition_speed * delta)

func update_dash_cooldown_indicator():
	var cooldown_progress: float = clamp((Time.get_ticks_msec() - last_dash_time) / dash_cooldown, 0, 1)
	dash_cooldown_indicator.value = cooldown_progress

func set_player_name(player_name: String):
	$Name.text = player_name