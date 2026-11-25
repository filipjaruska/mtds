@tool
extends Marker2D
class_name RoomSpot
## One more place a swap group's rooms may take (rooms already count their own
## painted place). The room's centre lands here. In the editor it shows the
## outlines of the group's rooms as they would sit here.

const TILE := 64

## The swap group (MapRoom.swap_group) this place is for.
@export var group: StringName = &"":
	set(value):
		group = value
		_changed()

func members() -> Array[MapRoom]:
	var out: Array[MapRoom] = []
	var node := get_parent()
	while node and not node is GameMap:
		node = node.get_parent()
	if node == null or group == &"":
		return out
	for room in node.find_children("*", "MapRoom", true, false):
		if room.swap_group == group:
			out.append(room)
	return out

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw() # follow rooms being edited

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.55, 0.75, 1.0)
	draw_line(Vector2(-40, 0), Vector2(40, 0), color, 6.0)
	draw_line(Vector2(0, -40), Vector2(0, 40), color, 6.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, -12), "⇄ " + String(group), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color)
	for room in members():
		var rect := room.used_rect()
		var size := Vector2(rect.size) * TILE
		_dashed_rect(Rect2(-size * 0.5, size), Color(color, 0.7))

func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 4.0, 24.0)

func _get_configuration_warnings() -> PackedStringArray:
	if group == &"":
		return ["Set the swap group this place is for."]
	if members().is_empty():
		return ["No room has the swap group \"%s\"." % group]
	return []
