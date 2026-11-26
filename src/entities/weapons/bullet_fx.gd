extends Node2D
class_name BulletFx
## The visible bullet. Purely cosmetic: hits are decided instantly by
## CombatServer's raycast; this only flies from the muzzle to the raycast's end
## point and plays an impact there (ImpactFx):
##   WALL    sparks bouncing back, a dust puff and a bullet hole that fades
##   PLAYER  a red splash along the shot
##   SHIELD  a bright blue ricochet
##   NONE    out of range: the bullet just fades
## Its look is fx/bullet.tscn: a "Slug" (the bullet itself, pointing along +x)
## and a "Trail" line behind it. Edit that scene to change it.

enum Impact { NONE, WALL, PLAYER, SHIELD }

const SCENE_PATH := "res://src/entities/weapons/fx/bullet.tscn"
const DEFAULT_SPEED := 2600.0 # px/s; each weapon sets its own (WeaponDef.bullet_speed)
const TRAIL_LENGTH := 70.0

var _from: Vector2
var _to: Vector2
var _dir: Vector2
var _distance := 0.0
var _travelled := 0.0
var _impact := Impact.NONE
var _speed := DEFAULT_SPEED
var _arrived := false

@onready var _trail: Line2D = $Trail
@onready var _slug: Node2D = $Slug

## `look`: the weapon's own shot scene (WeaponDef.bullet_scene), else a bullet.
static func spawn(parent: Node, from: Vector2, to: Vector2, impact: int, speed: float = DEFAULT_SPEED, look: PackedScene = null) -> BulletFx:
	var fx: BulletFx = (look if look else load(SCENE_PATH)).instantiate()
	fx._speed = maxf(speed, 1.0)
	fx.top_level = true
	fx._from = from
	fx._to = to
	fx._impact = impact
	parent.add_child(fx)
	return fx

func _ready() -> void:
	_distance = _from.distance_to(_to)
	_dir = (_to - _from).normalized() if _distance > 0.0 else Vector2.RIGHT
	_slug.rotation = _dir.angle()
	_update(0.0)

func _process(delta: float) -> void:
	if _arrived:
		return
	_update(delta)

func _update(delta: float) -> void:
	_travelled = minf(_travelled + _speed * delta, _distance)
	var head := _from + _dir * _travelled
	var tail := _from + _dir * maxf(_travelled - TRAIL_LENGTH, 0.0)
	_slug.position = head
	_trail.points = PackedVector2Array([tail, head])
	if _travelled >= _distance:
		_arrive()

func _arrive() -> void:
	_arrived = true
	_slug.visible = _impact == Impact.NONE
	ImpactFx.play(get_parent(), _to, _dir, _impact)
	# The trail catches up with the head and the bullet is gone.
	var tween := create_tween().set_parallel()
	tween.tween_method(func(t: float) -> void:
		_trail.points = PackedVector2Array([_trail.points[0].lerp(_to, t), _to]), 0.0, 1.0, 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
