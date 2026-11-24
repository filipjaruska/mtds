@tool
extends Node2D
class_name WeaponSpawner
## A weapon spot on a map. Every peer places the first pickup when the map
## loads; after someone takes it, the host waits `respawn_time` seconds and
## tells every peer to place a new one. Pickups are children of the spawner,
## named Weapon_<n>, so their RPC paths match on every peer. In the editor it
## shows as a circle with the weapon's name.

const WEAPON_PICKUP_SCENE := preload("res://src/entities/weapons/weapon_pickup.tscn")

## The weapon placed here (a file from src/entities/weapons/defs).
@export var weapon_def: WeaponDef:
	set(value):
		weapon_def = value
		queue_redraw()
		update_configuration_warnings()
## Seconds until a new one appears after it is taken.
@export var respawn_time: float = 20.0

var _timer: Timer
var _count := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if weapon_def == null:
		push_warning("WeaponSpawner %s has no weapon_def" % name)
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_respawn_timeout)
	add_child(_timer)
	_place(0)

func _on_respawn_timeout() -> void:
	_respawn.rpc(_count + 1)

@rpc("authority", "call_local", "reliable")
func _respawn(index: int) -> void:
	_place(index)

func _place(index: int) -> void:
	_count = index
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	pickup.name = "Weapon_%d" % index
	pickup.setup(weapon_def)
	pickup.tree_exiting.connect(_on_pickup_taken)
	add_child(pickup)

func _on_pickup_taken() -> void:
	# Also fires when the whole map is freed; the timer is freed with it then.
	if multiplayer.is_server() and _timer.is_inside_tree():
		_timer.start(respawn_time)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(1.0, 0.6, 0.15) if weapon_def else Color.RED
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, color, 3.0)
	var label := weapon_def.get_display_name() if weapon_def else "no weapon"
	draw_string(ThemeDB.fallback_font, Vector2(-80, -38), label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, color)

func _get_configuration_warnings() -> PackedStringArray:
	if weapon_def == null:
		return PackedStringArray(["Pick a weapon in Weapon Def (a file from src/entities/weapons/defs)."])
	return PackedStringArray()
