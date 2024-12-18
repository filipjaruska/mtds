extends Area2D

@export var weapon_scene: PackedScene
@export var weapon_name: String
@onready var label = $Label
var player: Node = null

func _ready() -> void:
	label.visible = false
	$Sprite2D.visible = false
	if weapon_scene:
		add_child(weapon_scene.instantiate())
	
func _process(_delta):
	if player and Input.is_action_just_pressed("interact"):
		player.weapon_manager.on_weapon_picked_up(weapon_scene)
		queue_free()
	
func _on_body_entered(body):
	if not body.is_in_group("Player"):
		return
	player = body
	label.visible = true

func _on_body_exited(body):
	if not body.is_in_group("Player"):
		return
	player = null
	label.visible = false

func set_weapon_scene(new_weapon_scene: PackedScene) -> void:
	weapon_scene = new_weapon_scene
	if weapon_scene:
		add_child(weapon_scene.instantiate())
