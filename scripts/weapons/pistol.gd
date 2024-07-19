extends RangedWeapon

@export var bullet_scene = preload("res://nodes/weapons/bullet.tscn")
@export var ammo: int = 18
@export var max_ammo: int = 18


func _ready():
	set_ammo_and_max_ammo(ammo, max_ammo)
	fire_rate = 2.5
	slowness = 20.0
	slowness_duration = 300.0
	muzzle = $Sprite2D/Muzzle
	shooting_animation = "Shooting"
	idle_animation = "Idle"
	animation_player = $AnimationPlayer
	animation_player.play(idle_animation)
	sprite = $Sprite2D

func _shoot_bullet():
	var bullet: Area2D = bullet_scene.instantiate()
	get_parent().get_parent().get_parent().add_child(bullet)
	bullet.set_bullet_damage(10, 0)
	
	var offset: Vector2 = Vector2(range / 10, 0).rotated(global_rotation)
	bullet.global_position = muzzle.global_position + offset
	bullet.rotation = global_rotation


func _on_animation_player_animation_finished(anim_name):
	if anim_name == shooting_animation:
		animation_player.play(idle_animation)
