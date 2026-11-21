extends StaticBody2D
class_name TrainingTarget
## A practice target for the tutorial and the debug arena. Solid like a wall
## (shots and players stop at it); every hit shows the damage dealt, and when
## its HP runs out it pops and comes back. Like everything else the host
## decides the hits (CombatServer calls take_hit) and every peer sees them.

const RADIUS := 22.0
const MAX_HP := 100.0
const RESPAWN_SECONDS := 1.5

var hp := MAX_HP
var _rings: Node2D

func _ready() -> void:
	collision_layer = CombatServer.WALL_LAYER
	collision_mask = 0
	add_to_group("training_target")
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# A bullseye: red and white rings.
	_rings = Node2D.new()
	add_child(_rings)
	for i in range(4):
		var ring := Polygon2D.new()
		var r := RADIUS * (1.0 - i * 0.24)
		var points := PackedVector2Array()
		for k in range(24):
			points.append(Vector2.RIGHT.rotated(TAU * k / 24.0) * r)
		ring.polygon = points
		ring.color = Color(0.85, 0.15, 0.15) if i % 2 == 0 else Color(0.95, 0.93, 0.9)
		_rings.add_child(ring)

## Host only: a shot or swing hit this target.
func take_hit(amount: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_show_hit.rpc(amount, hp)
	if hp <= 0.0:
		await get_tree().create_timer(RESPAWN_SECONDS).timeout
		if is_inside_tree():
			_respawn.rpc()

@rpc("authority", "call_local", "reliable")
func _show_hit(amount: float, hp_left: float) -> void:
	hp = hp_left
	var flash := create_tween()
	_rings.modulate = Color(2.0, 2.0, 2.0)
	flash.tween_property(_rings, "modulate", Color.WHITE, 0.15)
	_float_number(amount)
	if hp_left <= 0.0:
		collision_layer = 0
		var pop := create_tween().set_parallel()
		pop.tween_property(_rings, "scale", Vector2(1.5, 1.5), 0.15)
		pop.tween_property(_rings, "modulate:a", 0.0, 0.15)

@rpc("authority", "call_local", "reliable")
func _respawn() -> void:
	hp = MAX_HP
	collision_layer = CombatServer.WALL_LAYER
	_rings.scale = Vector2(0.3, 0.3)
	_rings.modulate = Color.WHITE
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(_rings, "scale", Vector2.ONE, 0.25)

func _float_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	UiPalette.world_text(label, 18, UiPalette.WARN)
	label.size = Vector2(60, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30 + randf_range(-10, 10), -RADIUS - 28)
	label.z_index = 10
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
