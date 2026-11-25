@tool
extends Node2D
class_name MapSlot
## One place in a slot map's grid (see GameMap). Each match it gets one of its
## `choices`, picked by weight, turned and mirrored if allowed, or stays empty.
## Put its top-left corner on the grid: a multiple of the slot size from the
## map's origin. In the editor it shows as a box with the rooms it may use.

## Rooms this slot may use.
@export var choices: Array[RoomChoice] = []:
	set(value):
		choices = value
		_changed()
## Chance that the slot stays empty (ignored when `required`).
@export_range(0.0, 1.0, 0.05) var empty_chance: float = 0.0:
	set(value):
		empty_chance = value
		_changed()
## The room may be turned (quarter turns for square slots, half turns otherwise).
@export var allow_rotate: bool = true:
	set(value):
		allow_rotate = value
		_changed()
## The room may be mirrored east-west.
@export var allow_flip: bool = true:
	set(value):
		allow_flip = value
		_changed()
## Always gets a room.
@export var required: bool = false:
	set(value):
		required = value
		_changed()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()

## The map this slot belongs to.
func map() -> Node:
	var node := get_parent()
	while node and not node is GameMap:
		node = node.get_parent()
	return node

func rules() -> MapLayoutRules:
	var m := map()
	return m.layout_rules if m and m.layout_rules else null

## Position relative to the map's origin.
func map_position() -> Vector2:
	var pos := position
	var node := get_parent()
	var m := map()
	while node and node != m and node is Node2D:
		pos = (node as Node2D).transform * pos
		node = node.get_parent()
	return pos

## Grid cell of this slot (its top-left corner, rounded to the grid).
func cell() -> Vector2i:
	var r := rules()
	var size := r.slot_pixels() if r else Vector2(1024, 1024)
	return Vector2i((map_position() / size).round())

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := rules()
	var size := r.slot_pixels() if r else Vector2(1024, 1024)
	var color := Color(1.0, 0.85, 0.3) if required else Color(0.75, 0.8, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-10), Color(color, 0.08))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-10), color, false, 4.0)
	var font := ThemeDB.fallback_font
	var lines := PackedStringArray([String(name) + ("  (required)" if required else "")])
	for choice in choices:
		if choice and choice.scene:
			var line := "%s  x%s" % [choice.scene.resource_path.get_file().get_basename(), str(choice.weight)]
			if choice.max_per_map > 0:
				line += "  max %d" % choice.max_per_map
			lines.append(line)
	if empty_chance > 0.0 and not required:
		lines.append("empty %d%%" % roundi(empty_chance * 100.0))
	var flags := PackedStringArray()
	if allow_rotate:
		flags.append("turns")
	if allow_flip:
		flags.append("mirrors")
	if not flags.is_empty():
		lines.append(", ".join(flags))
	for i in range(lines.size()):
		draw_string(font, Vector2(30, 60 + i * 36), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 28, color)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if map() == null:
		warnings.append("Must be inside a map (a GameMap root).")
		return warnings
	if rules() == null:
		warnings.append("The map has no Layout Rules.")
		return warnings
	var size := rules().slot_pixels()
	var snapped := Vector2(cell()) * size
	if not map_position().is_equal_approx(snapped):
		warnings.append("Not on the grid: move its top-left corner to %s (slot size %s)." % [snapped, size])
	if choices.is_empty() or choices.all(func(c): return c == null or c.scene == null):
		warnings.append("No rooms to choose from: add Room Choices with a scene.")
	for choice in choices:
		if choice and choice.scene and choice.scene.get_state().get_node_type(0) != &"" and not _is_room(choice.scene):
			warnings.append("%s is not a room (its root needs map_room.gd)." % choice.scene.resource_path.get_file())
	return warnings

static func _is_room(scene: PackedScene) -> bool:
	var state := scene.get_state()
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == &"script":
			var script: Script = state.get_node_property_value(0, i)
			return script != null and script.resource_path == "res://src/scenes/layout/map_room.gd"
	return false
