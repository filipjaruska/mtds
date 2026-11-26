@tool
extends Node2D
class_name BossLair
## Where a boss sleeps (Tutankhamun's sarcophagus...). Put it in the room that
## is his lair: for most of the match it is just a room with this prop in it.
## When his event (BossEvent) starts, the lair opens (a child named Lid slides
## off, if there is one) and he steps out at `wake_offset`. While he is held
## there, he stays in the room the lair stands in.

## The boss this lair is for (BossEvent.lair): several bosses can share a map.
@export var boss: StringName = &""
## Where he steps out, relative to the lair.
@export var wake_offset: Vector2 = Vector2(0, 90):
	set(value):
		wake_offset = value
		queue_redraw()

var opened := false

func wake_position() -> Vector2:
	return to_global(wake_offset)

## Every peer: the lid slides off.
func open() -> void:
	if opened:
		return
	opened = true
	var lid := get_node_or_null("Lid") as Node2D
	if lid:
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(lid, "position", lid.position + Vector2(56, 10), 0.8)
		tween.tween_property(lid, "rotation", 0.35, 0.8)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(wake_offset, 10.0, Color(1.0, 0.75, 0.2, 0.8), false, 3.0)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if boss == &"":
		warnings.append("Set Boss: the name the boss's event looks for (BossEvent > Lair).")
	var room := get_parent()
	while room and not room is MapRoom:
		room = room.get_parent()
	if room == null:
		warnings.append("Put it in a room (MapRoom): that room is his lair.")
	return warnings
