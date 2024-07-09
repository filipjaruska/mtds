extends RigidBody2D

@export var SPEED: float = 5000.0
var bulletDamage: float = 5

@rpc("any_peer")
func network_update(position: Vector2, rotation: float):
	global_position = position
	global_rotation = rotation

func _process(delta):
	var velocity = Vector2(SPEED, 0).rotated(rotation)
	global_position += velocity * delta
	if is_multiplayer_authority():
		rpc("network_update", global_position, rotation)

@rpc("any_peer")
func _on_area_2d_area_entered(area):
	if not area.is_in_group("bullet"):
		queue_free()
	if area.is_in_group("hitbox"):
		area.get_parent().currentHealth -= bulletDamage
		print("hit")
		$Area2D/CollisionShape2D.set_deferred("disabled", true)
