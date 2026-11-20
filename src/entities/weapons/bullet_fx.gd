extends Node2D
class_name BulletFx
## The visible bullet. Purely cosmetic: hits are decided instantly by
## CombatServer's raycast; this only flies from the muzzle to the raycast's end
## point and plays an impact there. A glowing slug with a tapered trail, then:
##   WALL    sparks bouncing back, a dust puff and a bullet hole that fades
##   PLAYER  a red splash along the shot
##   SHIELD  a bright blue ricochet
##   NONE    out of range: the bullet just fades

enum Impact { NONE, WALL, PLAYER, SHIELD }

const SPEED := 2600.0 # px/s
const TRAIL_LENGTH := 70.0
const HOLE_SECONDS := 5.0

var _from: Vector2
var _to: Vector2
var _dir: Vector2
var _distance := 0.0
var _travelled := 0.0
var _impact := Impact.NONE
var _arrived := false
var _trail: Line2D
var _slug: Node2D

static func spawn(parent: Node, from: Vector2, to: Vector2, impact: int) -> BulletFx:
	var fx := BulletFx.new()
	fx.top_level = true
	fx.z_index = 5
	fx._from = from
	fx._to = to
	fx._impact = impact
	parent.add_child(fx)
	return fx

func _ready() -> void:
	_distance = _from.distance_to(_to)
	_dir = (_to - _from).normalized() if _distance > 0.0 else Vector2.RIGHT
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_trail = Line2D.new()
	_trail.width = 4.0
	_trail.material = additive
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.45, 0.1, 0.0))
	fade.set_color(1, Color(1.0, 0.85, 0.45, 0.9))
	_trail.gradient = fade
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.15))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper
	add_child(_trail)

	# The slug: an orange glow around a white-hot core, pointing along the shot.
	_slug = Node2D.new()
	_slug.rotation = _dir.angle()
	var glow := Polygon2D.new()
	glow.polygon = _capsule(9.0, 3.5)
	glow.color = Color(1.0, 0.6, 0.2, 0.45)
	glow.material = additive
	_slug.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _capsule(6.0, 1.6)
	core.color = Color(1.0, 0.97, 0.85)
	_slug.add_child(core)
	add_child(_slug)
	_update(0.0)

func _process(delta: float) -> void:
	if _arrived:
		return
	_update(delta)

func _update(delta: float) -> void:
	_travelled = minf(_travelled + SPEED * delta, _distance)
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

static func _capsule(half_length: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(7):
		var a := -PI / 2.0 + PI * i / 6.0
		points.append(Vector2(half_length - radius, 0) + Vector2(cos(a), sin(a)) * radius)
	for i in range(7):
		var a := PI / 2.0 + PI * i / 6.0
		points.append(Vector2(-half_length + radius, 0) + Vector2(cos(a), sin(a)) * radius)
	return points
