@tool
extends Node2D
class_name RoomLink
## A corridor between two rooms, always or with a chance, of the map's width or
## its own. A link whose corridor would be a long way round is dropped for the
## match (Layout Rules: Max Detour). The game adds more corridors only when a
## room would otherwise be unreachable. In the editor it shows as a line
## between the rooms (dashed below 100%, thicker when wider).

## The two rooms (MapRoom nodes).
@export var from: NodePath:
	set(value):
		from = value
		_changed()
@export var to: NodePath:
	set(value):
		to = value
		_changed()
## How often this corridor is there (1 = every match).
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0:
	set(value):
		chance = value
		_changed()
## Corridor width in tiles; 0 = the map's corridor width.
@export_range(0, 8) var width: int = 0:
	set(value):
		width = value
		_changed()

func from_room() -> MapRoom:
	return get_node_or_null(from) as MapRoom if not from.is_empty() else null

func to_room() -> MapRoom:
	return get_node_or_null(to) as MapRoom if not to.is_empty() else null

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw() # follow rooms being moved

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

static func _centre(room: MapRoom) -> Vector2:
	var rect := room.used_rect()
	return room.global_transform * (Vector2(rect.get_center()) * MapRoom.TILE)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var a := from_room()
	var b := to_room()
	if a == null or b == null:
		return
	var start := to_local(_centre(a))
	var end := to_local(_centre(b))
	var color := Color(1.0, 0.85, 0.3)
	var thickness := 8.0 if width <= 0 else 4.0 + width * 3.0
	if chance >= 1.0:
		draw_line(start, end, color, thickness)
	else:
		draw_dashed_line(start, end, color, thickness, 40.0)
	var label := PackedStringArray()
	if chance < 1.0:
		label.append("%d%%" % roundi(chance * 100.0))
	if width > 0:
		label.append("%d wide" % width)
	draw_string(ThemeDB.fallback_font, (start + end) * 0.5 + Vector2(12, -12), "  ".join(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, color)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if from_room() == null or to_room() == null:
		warnings.append("Pick two rooms (MapRoom nodes) in From and To.")
	elif from_room() == to_room():
		warnings.append("From and To are the same room.")
	return warnings
