extends CharacterBody2D

@export var speed: float = 200.0
var sync_position = Vector2(0, 0) # Alternative way to synchronize movement, not currently used
@onready var weapon_manager = $WeaponManager

func _ready():
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		$Camera2D.enabled = true
	else:
		$Camera2D.enabled = false

func _process(delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
		global_position = global_position.lerp(sync_position, 0.2)
	
	sync_position = global_position
	
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
		rotation = direction.angle()

func set_player_name(player_name: String):
	$Label.text = player_name
