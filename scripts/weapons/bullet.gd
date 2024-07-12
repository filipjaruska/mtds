extends Area2D

@export var SPEED: float = 5000.0
var bullet_damage: float
var birth: float

func _ready():
	birth = Time.get_ticks_msec()
	
# TODO FIX CACHE ERROR	
@rpc("any_peer")
func network_update(position: Vector2, rotation: float):
	global_position = position
	global_rotation = rotation

func _process(delta):
	if Time.get_ticks_msec() - birth >= 1000:
		queue_free()
	var velocity = Vector2(SPEED, 0).rotated(rotation)
	global_position += velocity * delta
	if is_multiplayer_authority():
		rpc("network_update", global_position, rotation)
		
func _on_area_entered(area):
	if not area.is_in_group("bullet"):
		queue_free()
	if area.is_in_group("hitbox"):
		area.get_parent().damage(bullet_damage, 0)
		print("hit")
		$CollisionShape2D.set_deferred("disabled", true)