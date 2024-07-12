extends Node2D
class_name RangedWeapon

@onready var player = $"."
@export var fire_rate: float = 1.0
@export var range: float = 500.0
@export var AMMO: int
@export var MAX_AMMO: int
@export var slow_player: bool
@export var slowness:float
@export var slowness_duration: float

var last_shot_time: float = 0.0


func _ready():
	last_shot_time = Time.get_ticks_msec()

func shoot():
	if Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate:
		if AMMO > 0:
			_shoot_bullet()
			rpc("network_shoot")
			last_shot_time = Time.get_ticks_msec()
			AMMO -= 1
		else:
			print("Out of AMMO!")

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

func _process(delta):
	can_slow()

func can_slow():
	if Time.get_ticks_msec() - last_shot_time >= slowness_duration:
		slow_player = false
	else:
		slow_player = true
