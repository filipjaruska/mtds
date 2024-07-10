extends RangedWeapon

@export var bullet_scene: PackedScene
@export var pellets: int = 5
@export var ammo: int = 5
@export var max_ammo: int = 5

func _ready():
	set_ammo_and_max_ammo(ammo, max_ammo)

func _shoot_bullet():
	for i in range(pellets):
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.bulletDamage = 30
		var offset = Vector2(range / 10, 0).rotated(global_rotation)
		bullet.global_position = global_position + offset
		
		# Spread of the shotgun pellets
		bullet.rotation = global_rotation + randf() * 0.1 - 0.05
