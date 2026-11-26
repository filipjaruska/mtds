@tool
extends Node2D
class_name TutankhamunSarcophagus
## Tutankhamun's sarcophagus. Put it in the room that is his tomb: for most of
## the match it is just a room with a coffin in it. When his event starts
## (TutankhamunEvent) the lid slides off and he steps out in front of it; he is
## held in the room the sarcophagus stands in until his time there is up.
##
## The look is placeholder art (a coffin image and its lid).

## Where he steps out, relative to the sarcophagus.
@export var wake_offset: Vector2 = Vector2(0, 90)

var opened := false

func wake_position() -> Vector2:
	return to_global(wake_offset)

## Every peer: the lid slides off.
func open() -> void:
	if opened:
		return
	opened = true
	var lid: Node2D = $Lid
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "position", lid.position + Vector2(56, 10), 0.8)
	tween.tween_property(lid, "rotation", 0.35, 0.8)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(wake_offset, 10.0, Color(1.0, 0.75, 0.2, 0.8), false, 3.0)

func _get_configuration_warnings() -> PackedStringArray:
	var room := get_parent()
	while room and not room is MapRoom:
		room = room.get_parent()
	if room == null:
		return ["Put it in a room (MapRoom): that room is his tomb."]
	return []
