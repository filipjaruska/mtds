extends Area2D

@export var weapon_scene: PackedScene
@export var weapon_name: String
var label: Label
var pickup_sprite: Sprite2D
var player: Node = null
var current_weapon_instance: Node = null

func _ready() -> void:
	label = get_node_or_null("Label")
	pickup_sprite = get_node_or_null("Sprite2D")
	if label:
		label.visible = false
	if pickup_sprite:
		pickup_sprite.visible = false
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
	if label:
		label.visible = true

func _on_body_exited(body):
	if not body.is_in_group("Player"):
		return
	player = null
	if label:
		label.visible = false

func set_weapon_scene(scene: PackedScene, weapon_label: String = "") -> void:
	weapon_scene = scene
	if not label:
		label = get_node_or_null("Label")
	if label:
		if weapon_label.is_empty() and scene:
			label.text = scene.resource_path.get_file().get_basename().replace("_", " ").capitalize()
		else:
			label.text = weapon_label
		label.visible = true
	if not pickup_sprite:
		pickup_sprite = get_node_or_null("Sprite2D")
	if pickup_sprite:
		pickup_sprite.visible = true
	spawn_weapon_scene()
