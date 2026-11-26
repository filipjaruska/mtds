extends Node2D
class_name PlayerController

@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var sprite = get_parent().get_node("PlayerSprite")
@onready var player_root: CharacterBody2D = get_parent()
@onready var camera_component: Node2D = get_parent().get_node("CameraComponent")
@onready var dash_cooldown_indicator = get_parent().get_node("%DashCooldownBar")
@onready var health: HealthComponent = get_parent().get_node("HealthComponent")

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector
var normal_speed: float = RULES.walk_speed
var dash_speed: float = RULES.dash_speed
var crouch_speed: float = RULES.crouch_speed
var base_dash_cooldown: float = RULES.dash_cooldown_seconds * 1000.0 # msec
var dash_cooldown: float = base_dash_cooldown # msec, after card bonuses
var dash_duration: float = RULES.dash_seconds
var _dash_cooldown_reduction: float = 0.0
var _move_bonus: float = 0.0 # cards (Swift Feet): 0.15 = 15% faster walking

enum PlayerState {
	NORMAL,
	DASHING,
	CROUCHING
}

var current_state: PlayerState = PlayerState.NORMAL
var current_speed: float
var slowness_factor: float = 1.0
var _fire_slow_mult: float = 1.0
var _fire_slow_until: int = 0
var last_dash_time: float = 0
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: SceneTreeTimer = null
## Owner: velocity pushed onto the player (Shoulder Charge), fades out quickly.
var _knockback := Vector2.ZERO
const KNOCKBACK_DECAY := 2600.0 # px/s per second
var _charged_this_dash := {} # target ids already hit during the current dash

func _ready():
	last_dash_time = Time.get_ticks_msec() - dash_cooldown
	var powerup_manager: PowerupManager = get_parent().get_node_or_null("PowerupManager")
	if powerup_manager:
		powerup_manager.active_changed.connect(func(_active: Array) -> void:
			_dash_cooldown_reduction = minf(float(powerup_manager.get_modifiers().get("dash_cooldown_reduction", 0.0)), 0.9)
			_recompute_dash_cooldown()
			_move_bonus = minf(float(powerup_manager.get_modifiers().get("move_speed_mult", 0.0)), 1.0)
			_recompute_current_speed()
		)
	_recompute_current_speed()
	# Deferred: the sibling components must be ready first.
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
	
	if current_state != PlayerState.DASHING:
		base_speed *= 1.0 + _move_bonus
	current_speed = base_speed * slowness_factor

func _setup_multiplayer_authority():
	var authority_id: int = str(player_root.name).to_int()
	player_root.get_node("MultiplayerSynchronizer").set_multiplayer_authority(authority_id)
	
	var is_authority = player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id()
	if camera_component:
		camera_component.set_camera_authority(is_authority)
	dash_cooldown_indicator.visible = is_authority

func _process(delta):
	if player_root.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id() and not health.is_dead:
		_update_fire_slow()
		_check_state_transitions()
		_process_current_state(delta)
	
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

	player_root.velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	player_root.move_and_slide()
	if current_state == PlayerState.DASHING:
		_check_charge_hits()

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
			_charged_this_dash.clear()
			dash_direction = InputManager.get_movement_vector()
			dash_timer = get_tree().create_timer(dash_duration)
			dash_timer.timeout.connect(_on_dash_timer_timeout)
	
	_recompute_current_speed()

func _process_normal_state():
	player_root.velocity = InputManager.get_movement_vector() * current_speed

func _process_dashing_state():
	player_root.velocity = dash_direction * dash_speed

func _process_crouching_state():
	player_root.velocity = InputManager.get_movement_vector() * current_speed

## Shoulder Charge: report every player this dash ran into; the host decides.
func _check_charge_hits() -> void:
	var effects := player_root.get_node_or_null("CardEffects") as CardEffects
	if effects == null or not effects.can_charge():
		return
	for i in range(player_root.get_slide_collision_count()):
		var other := player_root.get_slide_collision(i).get_collider() as Node
		if other == null or not other.is_in_group("Player") or other == player_root:
			continue
		var target_id := other.get_multiplayer_authority()
		if _charged_this_dash.has(target_id):
			continue
		_charged_this_dash[target_id] = true
		effects.request_charge_hit.rpc_id(1, target_id)

## Host -> owner: pushed by a Shoulder Charge.
@rpc("any_peer", "call_local", "reliable")
func apply_knockback(impulse: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_knockback = impulse

## Host -> owner: moved somewhere by an event (a seat at the blackjack table,
## back out to a spawn point). The owner moves its own player; its synchronizer
## tells everyone.
@rpc("any_peer", "call_local", "reliable")
func teleport(to: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not player_root.is_multiplayer_authority():
		return
	player_root.global_position = to
	player_root.velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	if current_state == PlayerState.DASHING:
		_change_state(PlayerState.NORMAL)

func _on_dash_timer_timeout():
	_change_state(PlayerState.NORMAL)

func _update_dash_cooldown_indicator():
	var cooldown_progress: float = clamp((Time.get_ticks_msec() - last_dash_time) / dash_cooldown, 0, 1)
	dash_cooldown_indicator.value = cooldown_progress

func get_current_state() -> PlayerState:
	return current_state

## Briefly slows movement after a shot. `speed_mult` comes from the WeaponDef
## (1.0 = no slow); a new shot refreshes the duration.
func apply_fire_slow(speed_mult: float, duration_seconds: float) -> void:
	if duration_seconds <= 0.0 or speed_mult >= 1.0:
		return
	_fire_slow_mult = speed_mult
	_fire_slow_until = Time.get_ticks_msec() + int(duration_seconds * 1000.0)
	_update_fire_slow()

func _update_fire_slow() -> void:
	var factor := _fire_slow_mult if Time.get_ticks_msec() < _fire_slow_until else 1.0
	if not is_equal_approx(factor, slowness_factor):
		slowness_factor = factor
		_recompute_current_speed()

func _recompute_dash_cooldown() -> void:
	dash_cooldown = base_dash_cooldown * (1.0 - _dash_cooldown_reduction)
