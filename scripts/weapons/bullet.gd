extends RigidBody2D

@export var speed: float = 5000.0
@export var damage: float = 10.0

func _ready():
    pass

@rpc("any_peer")
func network_update(position: Vector2, rotation: float):
    global_position = position
    global_rotation = rotation

func _process(delta):
    var velocity = Vector2(speed, 0).rotated(rotation)
    global_position += velocity * delta
    if is_multiplayer_authority():
        rpc("network_update", global_position, rotation)
