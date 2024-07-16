extends Area2D

@export var weapon_scene: PackedScene
var player = null


func _ready() -> void:
	$Sprite2D.visible = false
	add_child(weapon_scene.instantiate())
	
func _process(delta):
	if player != null and Input.is_action_just_pressed("interact"):
		player.weapon_manager.on_weapon_picked_up(weapon_scene)
		queue_free()
		# show something to indicate to the player how to pick it up or something
	pass
	
func _on_body_entered(body):
	if not body.is_in_group("Player"):
		return
	player = body

func _on_body_exited(body):
	if not body.is_in_group("Player"):
		return
	player = null