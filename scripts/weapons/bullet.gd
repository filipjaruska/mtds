extends Area2D

const SPEED: float = 5000.0
var LIFETIME: float = 1000
var _bullet_damage: float
var _bullet_armor_penetration: float
var _birth: float

func set_bullet_damage(damage: float, penetration: float) -> void:
	_bullet_damage = damage
	_bullet_armor_penetration = penetration

func _ready():
	_birth = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - _birth >= LIFETIME:
		queue_free()
		
	global_position += Vector2(SPEED, 0).rotated(rotation) * delta
		
func _on_area_entered(area: Area2D) -> void: 
	if area.is_in_group("bullet"): 
		return
	self.visible = false
	queue_free()
	if area.is_in_group("hitbox"):
		area.get_parent().damage(_bullet_damage, _bullet_armor_penetration)
		$CollisionShape2D.set_deferred("disabled", true)

func set_bullet_lifetime(lifetime: float) -> void:
	_birth = Time.get_ticks_msec()
	LIFETIME = lifetime * 1000  # Convert seconds to milliseconds		