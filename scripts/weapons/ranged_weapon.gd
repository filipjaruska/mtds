extends Node2D
class_name RangedWeapon

@export var fire_rate: float = 1.0
@export var max_range: float = 500.0
@export var max_ammo: int = 10
@export var ammo: int = 10
@export var slowness: float = 20.0
@export var slowness_duration: float = 300.0
@export var animation_player: AnimationPlayer
@export var shooting_animation: String
@export var idle_animation: String
@onready var muzzle_flash = preload("res://nodes/scenes/muzzle_flash.tscn")
@export var muzzle = Marker2D
@export var sprite = Sprite2D
@export var can_rotate: bool
@export var bullet_scene: PackedScene
@export var pellets: int = 1

var last_shot_time: float = 0.0


func _ready():
	last_shot_time = Time.get_ticks_msec()

func shoot():
	if Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate:
		can_rotate = true
		if ammo > 0:
			animation_player.play(shooting_animation)
			_shoot_bullet()
			last_shot_time = Time.get_ticks_msec()
			ammo -= 1
			show_muzzle_flash()
	else:
		can_rotate = false

func _shoot_bullet():
	for i in range(pellets):
		if bullet_scene:
			var bullet: Area2D = bullet_scene.instantiate()
			get_parent().get_parent().get_parent().add_child(bullet)
			bullet.set_bullet_damage(10, 0)
			
			var offset: Vector2 = Vector2(max_range / 10, 0).rotated(global_rotation)
			bullet.global_position = muzzle.global_position + offset
			bullet.rotation = global_rotation + randf() * 0.1 - 0.05

func reload():
	ammo = max_ammo

func show_muzzle_flash():
	var muzzle_flash_instance = muzzle_flash.instantiate()
	muzzle_flash_instance.global_position = muzzle.global_position
	muzzle_flash_instance.rotation = get_parent().get_parent().rotation
	add_child(muzzle_flash_instance)
