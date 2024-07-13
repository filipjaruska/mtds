extends RangedWeapon

@export var bullet_scene: PackedScene
@export var ammo: int = 18
@export var max_ammo: int = 18


func _ready():
	set_ammo_and_max_ammo(ammo, max_ammo)
	fire_rate = 3
	slowness = 20.0
	slowness_duration = 300.0

func _shoot_bullet():
	var bullet: Area2D = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.set_bullet_damage(10, 0)
	
	var offset: Vector2 = Vector2(range / 10, 0).rotated(global_rotation)
	bullet.global_position = global_position + offset
	bullet.rotation = global_rotation