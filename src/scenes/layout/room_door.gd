@tool
extends Marker2D
class_name RoomDoor
## A doorway of a MapRoom: put it in the middle of a gap in the room's border
## wall and point it outwards. The gap is as wide as the map's corridors unless
## `width` says otherwise (shown green while it is clear, red while walls are in
## it). Corridors attach here; a doorway no corridor uses is walled up for the
## match.

enum Facing { NORTH, EAST, SOUTH, WEST }

const TILE := 64

## The way out of the room.
@export var facing: Facing = Facing.SOUTH:
	set(value):
		facing = value
		_changed()
## Gap width in tiles; 0 = the map's corridor width. A corridor narrower than
## the gap leaves the rest of it walled up.
@export_range(0, 8) var width: int = 0:
	set(value):
		width = value
		_changed()

func room() -> MapRoom:
	var node := get_parent()
	while node and not node is MapRoom:
		node = node.get_parent()
	return node as MapRoom

## This doorway's gap width in tiles.
func gap_width() -> int:
	return width if width > 0 else map_width()

## The map's corridor width (3 when there is no map or no rules).
func map_width() -> int:
	var node := get_parent()
	while node and not node is GameMap:
		node = node.get_parent()
	if node and node.layout_rules:
		return node.layout_rules.corridor_tiles
	return 3

## Position in the room's own coordinates.
func room_position() -> Vector2:
	var pos := position
	var node := get_parent()
	var r := room()
	while node and node != r and node is Node2D:
		pos = (node as Node2D).transform * pos
		node = node.get_parent()
	return pos

## The doorway's tiles in the room's tile coordinates, in order along the wall.
func cells(door_width: int) -> Array[Vector2i]:
	var pos := room_position() / TILE
	var out: Array[Vector2i] = []
	if facing == Facing.NORTH or facing == Facing.SOUTH:
		var start := roundi(pos.x - door_width / 2.0)
		for i in range(door_width):
			out.append(Vector2i(start + i, floori(pos.y)))
	else:
		var start := roundi(pos.y - door_width / 2.0)
		for i in range(door_width):
			out.append(Vector2i(floori(pos.x), start + i))
	return out

func blocked_by_walls() -> bool:
	var r := room()
	var walls := r.walls_layer() if r else null
	if walls == null:
		return false
	for cell in cells(gap_width()):
		if walls.get_cell_source_id(cell) != -1:
			return true
	return false

# --- Editor ---------------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_changed()

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(1.0, 0.3, 0.3) if blocked_by_walls() else Color(0.3, 1.0, 0.45)
	var origin := room_position()
	for cell in cells(gap_width()):
		draw_rect(Rect2(Vector2(cell) * TILE - origin + Vector2(4, 4), Vector2(TILE - 8, TILE - 8)), color, false, 4.0)
	var out: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][facing]
	var tip := out * 90.0
	draw_line(Vector2.ZERO, tip, color, 6.0)
	draw_line(tip, tip - out.rotated(0.5) * 30.0, color, 6.0)
	draw_line(tip, tip - out.rotated(-0.5) * 30.0, color, 6.0)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if room() == null:
		warnings.append("Must be inside a MapRoom.")
	elif blocked_by_walls():
		warnings.append("Walls in the doorway: leave the %d border tiles shown in red empty." % gap_width())
	return warnings
