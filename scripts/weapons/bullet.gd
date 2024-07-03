extends RigidBody2D

@export var speed: float = 5000.0

func _ready():
	# Initial impulse
	apply_impulse(Vector2(), Vector2(speed, 0).rotated(rotation))

func _process(delta):
	# only needed to adjust the velocity each frame
	self.linear_velocity = Vector2(speed, 0).rotated(rotation)
