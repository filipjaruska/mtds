extends Node2D
class_name RangedWeapon

@export var fire_rate: float = 1.0
@export var range: float = 500.0
@export var AMMO: int
@export var MAX_AMMO: int
@export var slowness: float = 20.0
@export var slowness_duration: float = 300.0
@export var animation_player: AnimationPlayer
@export var shooting_animation: String
@export var idle_animation: String

var last_shot_time: float = 0.0

func _ready():
	last_shot_time = Time.get_ticks_msec()

func shoot():
	if Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate:
		if AMMO > 0:
			animation_player.play(shooting_animation)
			_shoot_bullet()
			rpc("network_shoot")
			last_shot_time = Time.get_ticks_msec()
			AMMO -= 1
@rpc("any_peer")

func network_shoot():
	_shoot_bullet()

func _shoot_bullet():
	pass

func reload():
	AMMO = MAX_AMMO
	print("Weapon reloaded.")

func set_ammo_and_max_ammo(a: int, b: int):
	AMMO = a
	MAX_AMMO = b
