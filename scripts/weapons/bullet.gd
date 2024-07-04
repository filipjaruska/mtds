extends RigidBody2D

@export var SPEED: float = 5000.0

@rpc("any_peer")
func network_update(position: Vector2, rotation: float):
    global_position = position
    global_rotation = rotation

func _process(delta):
    var velocity = Vector2(SPEED, 0).rotated(rotation)
    global_position += velocity * delta
    if is_multiplayer_authority():
        rpc("network_update", global_position, rotation)

func _on_body_entered(body):
    queue_free()
    if body.has_method("damage"):
        body.damage(5, 0.1)