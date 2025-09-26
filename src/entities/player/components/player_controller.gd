extends Node2D
class_name PlayerController

@onready var weapon_manager = $WeaponManager
@onready var sprite = get_parent().get_node("PlayerSprite")
@onready var player_root: CharacterBody2D = get_parent()
@onready var camera_component: Node2D = get_parent().get_node("CameraComponent")
@onready var dash_cooldown_indicator = get_parent().get_node("CameraComponent/PlayerCamera/PlayerUI/DashCooldownBar")

# default settings
var normal_speed: float = 200.0
var dash_speed: float = 800.0
var crouch_speed: float = 100.0
var dash_duration: float = 0.3
var dash_cooldown: float = 3500.0

enum PlayerState {
	NORMAL,
	DASHING,
	CROUCHING
}

var current_state: PlayerState = PlayerState.NORMAL
var current_speed: float
var slowness_factor: float = 1.0
var last_dash_time: float = 0
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: SceneTreeTimer = null

func _ready():
	last_dash_time = Time.get_ticks_msec() - dash_cooldown
	_recompute_current_speed()
	# TODO: defers cool, ensures all components are ready
	call_deferred("_setup_multiplayer_authority")

func _recompute_current_speed():
	var base_speed: float
	match current_state:
		PlayerState.NORMAL:
			base_speed = normal_speed
		PlayerState.DASHING:
			base_speed = dash_speed
		PlayerState.CROUCHING:
			base_speed = crouch_speed
	
	current_speed = base_speed * slowness_factor

func _setup_multiplayer_authority():
	var authority_id: int = str(player_root.name).to_int()
	weapon_manager.multiplayer_sync.set_multiplayer_authority(authority_id)
	player_root.get_node("MultiplayerSynchronizer").set_multiplayer_authority(authority_id)
	
	var is_authority = player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id()
	if camera_component:
		camera_component.set_camera_authority(is_authority)
	dash_cooldown_indicator.visible = is_authority

func _process(delta):
	if player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id():
		_check_state_transitions()
		_process_current_state(delta)
		weapon_manager._process(delta)
	
	_update_dash_cooldown_indicator()

func _physics_process(_delta):
	if player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction: Vector2 = InputManager.get_aim_direction(player_root.global_position)
		rotation = direction.angle()
	
	sprite.rotation = rotation

func _check_state_transitions():
	if player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
		return
		
	match current_state:
		PlayerState.NORMAL:
			if InputManager.is_dash_pressed() and (Time.get_ticks_msec() - last_dash_time) >= dash_cooldown:
				_change_state(PlayerState.DASHING)
			elif InputManager.is_crouch_pressed():
				_change_state(PlayerState.CROUCHING)
		
		PlayerState.CROUCHING:
			if not InputManager.is_crouch_pressed():
				_change_state(PlayerState.NORMAL)

func _process_current_state(delta):
	match current_state:
		PlayerState.NORMAL:
			_process_normal_state()
			
		PlayerState.DASHING:
			_process_dashing_state()
			
		PlayerState.CROUCHING:
			_process_crouching_state()
	
	if camera_component:
		camera_component.update_zoom_for_state(current_state == PlayerState.CROUCHING, delta)

func _change_state(new_state: PlayerState):
	match current_state:
		PlayerState.DASHING:
			if dash_timer and dash_timer.time_left > 0:
				dash_timer.timeout.disconnect(_on_dash_timer_timeout)
			last_dash_time = Time.get_ticks_msec()
	
	current_state = new_state
	
	match new_state:
		PlayerState.DASHING:
			dash_direction = InputManager.get_movement_vector()
			dash_timer = get_tree().create_timer(dash_duration)
			dash_timer.timeout.connect(_on_dash_timer_timeout)
	
	_recompute_current_speed()

func _process_normal_state():
	var input_vector: Vector2 = InputManager.get_movement_vector() * current_speed
	player_root.velocity = input_vector
	player_root.move_and_slide()

func _process_dashing_state():
	player_root.velocity = dash_direction * dash_speed
	player_root.move_and_slide()

func _process_crouching_state():
	var input_vector: Vector2 = InputManager.get_movement_vector() * current_speed
	player_root.velocity = input_vector
	player_root.move_and_slide()

func _on_dash_timer_timeout():
	_change_state(PlayerState.NORMAL)

func _update_dash_cooldown_indicator():
	var cooldown_progress: float = clamp((Time.get_ticks_msec() - last_dash_time) / dash_cooldown, 0, 1)
	dash_cooldown_indicator.value = cooldown_progress

func get_current_state() -> PlayerState:
	return current_state

func apply_weapon_slowness(weapon_slowness: float):
	slowness_factor = weapon_slowness / normal_speed
	_recompute_current_speed()

func remove_weapon_slowness(_weapon_slowness: float):
	slowness_factor = 1.0
	_recompute_current_speed()
