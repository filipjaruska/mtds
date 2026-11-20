extends RefCounted
class_name ImpactFx
## One-shot effects where a bullet stops (see BulletFx.Impact). Everything is
## placed before it is added to the tree: particles start emitting on entering
## the tree, from wherever they are at that moment.

static func play(parent: Node, at: Vector2, dir: Vector2, impact: int) -> void:
	match impact:
		BulletFx.Impact.WALL:
			_burst(parent, at, -dir, 55.0, 12, Color(1.0, 0.8, 0.35), Color(1.0, 0.35, 0.05, 0.0), 140.0, 300.0, 0.25, 1.6)
			_burst(parent, at, -dir, 80.0, 6, Color(0.6, 0.55, 0.5, 0.6), Color(0.5, 0.45, 0.4, 0.0), 20.0, 60.0, 0.5, 4.0)
			_hole(parent, at)
		BulletFx.Impact.PLAYER:
			_burst(parent, at, dir, 35.0, 10, Color(0.85, 0.08, 0.08), Color(0.45, 0.0, 0.0, 0.0), 80.0, 220.0, 0.3, 2.5)
		BulletFx.Impact.SHIELD:
			_burst(parent, at, -dir, 70.0, 14, Color(0.75, 0.9, 1.0), Color(0.3, 0.55, 1.0, 0.0), 180.0, 360.0, 0.22, 1.6)
			_flash(parent, at, Color(0.6, 0.8, 1.0, 0.8))

static func _burst(parent: Node, at: Vector2, dir: Vector2, spread: float, amount: int,
		start: Color, end: Color, speed_min: float, speed_max: float, lifetime: float, size: float) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.position = at
	p.z_index = 4
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = speed_min * 2.0
	p.damping_max = speed_max * 2.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, end)
	p.color_ramp = ramp
	p.emitting = true
	p.finished.connect(p.queue_free)
	parent.add_child(p)

static func _hole(parent: Node, at: Vector2) -> void:
	var hole := Polygon2D.new()
	hole.top_level = true
	hole.position = at
	hole.z_index = 1
	var points := PackedVector2Array()
	for i in range(8):
		var a := TAU * i / 8.0
		points.append(Vector2(cos(a), sin(a)) * randf_range(2.0, 3.2))
	hole.polygon = points
	hole.color = Color(0.05, 0.04, 0.04, 0.85)
	parent.add_child(hole)
	var tween := hole.create_tween()
	tween.tween_interval(BulletFx.HOLE_SECONDS)
	tween.tween_property(hole, "modulate:a", 0.0, 1.0)
	tween.tween_callback(hole.queue_free)

static func _flash(parent: Node, at: Vector2, color: Color) -> void:
	var flash := Polygon2D.new()
	flash.top_level = true
	flash.position = at
	flash.z_index = 5
	var points := PackedVector2Array()
	for i in range(12):
		var a := TAU * i / 12.0
		points.append(Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 4.0))
	flash.polygon = points
	flash.color = color
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = additive
	parent.add_child(flash)
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(flash.queue_free)
