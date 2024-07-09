extends RangedWeapon

@export var bullet_scene: PackedScene
@export var ammo: int = 18
@export var max_ammo: int = 18

func _ready():
	set_ammo_and_max_ammo(ammo, max_ammo)
func _shoot_bullet():
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.bulletDamage = 25
	var offset = Vector2(range / 10, 0).rotated(global_rotation)
	bullet.global_position = global_position + offset
	bullet.rotation = global_rotation
	bullet.apply_impulse(Vector2(), Vector2(speed, 0).rotated(bullet.rotation))
	print("Pistol fired.")
