extends Line2D
class_name Tracer
## Purely visual bullet line that fades out. Hits are decided by CombatServer.

const LIFETIME := 0.15
const FADE := 0.15

static func spawn(parent: Node, from: Vector2, to: Vector2) -> Tracer:
	var tracer := Tracer.new()
	tracer.top_level = true
	tracer.width = 2.0
	tracer.default_color = Color(1, 1, 0, 1)
	tracer.points = PackedVector2Array([from, to])
	parent.add_child(tracer)
	return tracer

func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)
