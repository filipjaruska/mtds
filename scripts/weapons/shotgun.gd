extends RangedWeapon

@export var bullet_scene: PackedScene
@export var pellets: int = 5
@export var ammo: int = 5
@export var max_ammo: int = 5

func _ready():
	set_ammo_and_max_ammo(ammo, max_ammo)
	slowness = 40.0
	slowness_duration = 400.0
	fire_rate = 1
	animation_player = $AnimationPlayer
	shooting_animation = "Shooting"
	idle_animation = "Idle"
func _shoot_bullet():
	
	for i in range(pellets):
		var bullet: Area2D = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.set_bullet_damage(20, 0)
		
		var offset: Vector2 = Vector2(range / 10, 0).rotated(global_rotation)
		bullet.global_position = global_position + offset
		
		bullet.rotation = global_rotation + randf() * 0.1 - 0.05


func _on_animation_player_animation_finished(anim_name):
	if anim_name == shooting_animation:
		animation_player.play(idle_animation)
