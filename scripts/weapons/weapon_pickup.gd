extends Area2D

@export var weapon_scene: PackedScene

func _ready() -> void:
	$Sprite2D.visible = false
	var idkfuckingknowanymorewhatthefuckwasievendoingwhytrytousesignalswhenthierdocumentationsucksassandimnotafanofthemanyway: Node = weapon_scene.instantiate()
	add_child(idkfuckingknowanymorewhatthefuckwasievendoingwhytrytousesignalswhenthierdocumentationsucksassandimnotafanofthemanyway)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.weapon_manager.on_weapon_picked_up(weapon_scene)
		queue_free()