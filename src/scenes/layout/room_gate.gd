extends StaticBody2D
class_name RoomGate
## A barrier in a doorway of a semi-permanent room (MapRoom.gated). Closed, it
## stops players and shots like a wall; GameMap.set_gate_open() opens it on
## every peer. Built in code by MapRoom when the layout puts a gate there.

const BAR_COLOR := Color(0.62, 0.46, 0.22)
const FRAME_COLOR := Color(0.25, 0.18, 0.1)

var _shape: CollisionShape2D
var _size: Vector2

## `rect` is in the room's own coordinates.
static func create(rect: Rect2) -> RoomGate:
	var gate := RoomGate.new()
	gate.position = rect.get_center()
	gate._size = rect.size
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	gate._shape = CollisionShape2D.new()
	gate._shape.shape = shape
	gate.add_child(gate._shape)
	gate.collision_mask = 0
	gate.set_open(false)
	return gate

func set_open(open: bool) -> void:
	collision_layer = 0 if open else CombatServer.WALL_LAYER
	visible = not open

func is_open() -> bool:
	return collision_layer == 0

func _draw() -> void:
	var half := _size * 0.5
	draw_rect(Rect2(-half, _size), FRAME_COLOR)
	# Vertical bars across the long side of the doorway.
	var across := _size.x >= _size.y
	var length := _size.x if across else _size.y
	var bars := maxi(int(length / 24.0), 2)
	for i in range(bars):
		var t := (i + 0.5) / bars * length - length * 0.5
		var bar := Rect2(Vector2(t - 4, -half.y + 4), Vector2(8, _size.y - 8)) if across else Rect2(Vector2(-half.x + 4, t - 4), Vector2(_size.x - 8, 8))
		draw_rect(bar, BAR_COLOR)
