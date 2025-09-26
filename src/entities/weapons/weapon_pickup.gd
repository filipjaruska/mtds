extends Area2D

@export var weapon_scene: PackedScene
@export var weapon_name: String
@onready var label = $Label
var player: Node = null
var current_weapon_instance: Node = null

func _ready() -> void:
	label.visible = false
	$Sprite2D.visible = false
	if weapon_scene:
		spawn_weapon_scene()

func spawn_weapon_scene() -> void:
	if current_weapon_instance and is_instance_valid(current_weapon_instance):
		current_weapon_instance.queue_free()
		current_weapon_instance = null
	
	if weapon_scene:
		current_weapon_instance = weapon_scene.instantiate()
		add_child(current_weapon_instance)
	
func _process(_delta):
	if player and InputManager.is_interact_pressed():
		var weapon_manager = player.get_weapon_manager()
		if weapon_manager:
			weapon_manager.on_weapon_picked_up(weapon_scene)
			rpc("delete_pickup")
			queue_free()

@rpc("any_peer", "reliable")
func delete_pickup() -> void:
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

func set_weapon_scene(scene: PackedScene, weapon_label: String) -> void:
	weapon_scene = scene
	label.text = weapon_label
	label.visible = true
	$Sprite2D.visible = true
	spawn_weapon_scene()
