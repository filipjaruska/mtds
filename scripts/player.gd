extends CharacterBody2D

@onready var weapon_manager = $Node2D/WeaponManager
@onready var camera2d = $Camera2D
@onready var dash_timer = $Timers/DashTimer
@onready var dash_cooldown = $Timers/DashCooldown

@export var speed: float = 200.0
@export var camera_lookahead_distance: float = 150.0
@export var offset_disable_threshold: float = 200.0
@export var transition_speed: float = 5.0


func _ready():
	var authority_id: int = str(name).to_int()
	$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)
	var is_authority = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	$Camera2D.enabled = is_authority
	$Camera2D/UI/Ammo.visible = is_authority
	$Camera2D/UI/Health.visible = is_authority

func _process(delta):
	var input_vector: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized() * speed
	velocity = input_vector
	move_and_slide()
	weapon_manager._process(delta)
	dashing()
	update_camera_offset(delta)
	
func _physics_process(_delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction: Vector2 = (get_global_mouse_position() - global_position).normalized()
		$Node2D.rotation = direction.angle()

func set_player_name(player_name: String):
	$Label.text = player_name 

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

	camera2d.offset = camera2d.offset.lerp(target_offset, transition_speed * delta)

func dashing():
	if Input.is_action_just_pressed("Dash") && dash_cooldown.is_stopped() && dash_timer.is_stopped():
		speed = 700.0
		dash_cooldown.start()
		dash_timer.start()

func _on_dash_timer_timeout():
	dash_timer.stop()
	speed = 200.0

func _on_dash_cooldown_timeout():
	dash_cooldown.stop()
	

