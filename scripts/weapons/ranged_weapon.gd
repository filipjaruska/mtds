
extends Node2D
class_name RangedWeapon

@export var fire_rate: float = 1.0
@export var range: float = 500.0
@export var AMMO: int
@export var MAX_AMMO: int
@export var speed: float = 500.0

var last_shot_time: float = 0.0

func _ready():
    last_shot_time = Time.get_ticks_msec()

func shoot():
    if Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate:
        if AMMO > 0:
            _shoot_bullet()
            last_shot_time = Time.get_ticks_msec()
            AMMO -= 1
        else:
            print("Out of AMMO!")
    else:
        print("Weapon on cooldown!")

func _shoot_bullet():
	# for children
    pass

func reload():
    AMMO = MAX_AMMO
    print("Weapon reloaded.")

func set_ammo_and_max_ammo(a: int, b: int):
    AMMO = a
    MAX_AMMO = b