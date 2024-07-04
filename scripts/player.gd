extends CharacterBody2D

@export var speed: float = 200.0
@onready var weapon_manager = $Node2D/WeaponManager

func _ready():
	var authority_id = str(name).to_int()
	$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)
	var is_authority = $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()
	$Camera2D.enabled = is_authority
	$Camera2D/UI/Ammo.visible = is_authority

func _process(delta):
	var input_vector = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized() * speed
	velocity = input_vector
	move_and_slide()
	weapon_manager._process(delta)
	
func _physics_process(_delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction = (get_global_mouse_position() - global_position).normalized()
		$Node2D.rotation = direction.angle()

func set_player_name(player_name: String):
	$Label.text = player_name
