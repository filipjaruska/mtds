extends Resource
class_name WeaponDef
## Everything that makes a weapon *that* weapon, as plain data.
##
## To add a weapon: duplicate a file in res://src/entities/weapons/defs/, give it
## a new `id`, tweak the numbers and point `view_scene` at its art. It is picked
## up automatically (see WeaponDefs). No code needed unless you want a new
## `fire_pattern` (see WeaponRules.shot_offsets).

@export var id: StringName
@export var display_name: String = ""

@export_group("Firing")
@export_range(0.1, 30.0, 0.05, "suffix:shots/s") var fire_rate: float = 1.0
## Maximum deviation of a shot from the aim direction, to either side.
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread_degrees: float = 0.0
@export_range(1, 20) var pellets: int = 1
## How pellets are distributed inside the spread: &"random" or &"even".
@export var fire_pattern: StringName = &"random"

@export_group("Damage")
@export var damage: float = 10.0
@export_range(0.0, 1.0, 0.05) var armor_penetration: float = 0.0
@export_range(50.0, 2000.0, 10.0, "suffix:px") var max_range: float = 500.0
## Which band max_range must fall in, relative to what players can see
## (ViewRules.range_band): &"close", &"standard" or &"marksman".
## tests/test_view_rules.gd fails when a weapon's range leaves its band.
@export var range_class: StringName = &"standard"

@export_group("Ammo")
@export_range(1, 200) var mag_size: int = 10
@export_range(0.1, 10.0, 0.1, "suffix:s") var reload_time: float = 2.0

@export_group("Movement")
## Movement speed multiplier applied briefly after each shot (1.0 = no slow).
@export_range(0.1, 1.0, 0.05) var move_speed_mult: float = 1.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var slow_duration: float = 0.0

@export_group("Melee")
## A melee weapon swings instead of shooting: it hits the closest enemy within
## max_range (from the player's centre) inside arc_degrees in front, uses no
## ammo and never reloads. Walls and riot shields block the swing.
@export var melee: bool = false
@export_range(10.0, 360.0, 5.0, "suffix:°") var arc_degrees: float = 100.0
## Landed hits before the blade breaks and is gone (0 = never breaks). Misses
## don't count. The HUD shows the hits left. With Dual Wield each blade has its own.
@export_range(0, 50) var durability: int = 0

@export_group("Visuals")
## Scene with a WeaponView root (sprite, animations, muzzle marker).
@export var view_scene: PackedScene

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else String(id).capitalize()
