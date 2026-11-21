extends PanelContainer
class_name ChatBubbleView
## A speech bubble that types its messages out one after another (ChatRules
## timing and queue). Used above players (ChatBubble) and under the icons in
## the top bar (TopBarUI). The bubble keeps itself anchored to its parent's
## origin as its size changes: `align` is where the origin sits horizontally,
## `grow_up` makes it extend upwards (above a player) instead of downwards.

enum Align { CENTER, LEFT_EDGE, RIGHT_EDGE }

const SCENE_PATH := "res://src/ui/library/chat_bubble_view.tscn"

@export var align := Align.CENTER
@export var grow_up := true
@export var max_width := 180.0

@onready var _label: Label = $Text

var _queue: Array = []
var _showing := false
var _tween: Tween

## A bubble from chat_bubble_view.tscn (the look lives there and in the theme).
static func create(font_size: int, width: float, alignment: Align, upwards: bool) -> ChatBubbleView:
	var view: ChatBubbleView = load(SCENE_PATH).instantiate()
	view.max_width = width
	view.align = alignment
	view.grow_up = upwards
	view.get_node("Text").add_theme_font_size_override("font_size", font_size)
	return view

## Queues a message; it is typed out once the ones before it are done.
func push(text: String) -> void:
	_queue = ChatRules.enqueue(_queue, text)
	if not _showing:
		_play_next()

func is_showing() -> bool:
	return _showing

func _play_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var text: String = _queue.pop_front()
	_label.text = text
	_label.visible_characters = 0
	# Wrap at max_width, but shrink to fit short messages.
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_label.custom_minimum_size = Vector2(minf(text_width + 2.0, max_width), 0)
	reset_size()
	visible = true
	modulate.a = 1.0
	scale = Vector2(0.85, 0.85)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_reveal, 0.0, float(text.length()), ChatRules.reveal_seconds(text))
	# Keep up when more messages are waiting.
	var hold := ChatRules.hold_seconds(text) if _queue.is_empty() else 1.2
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, ChatRules.FADE_SECONDS)
	_tween.tween_callback(_play_next)

func _reveal(characters: float) -> void:
	_label.visible_characters = int(characters)

func _process(_delta: float) -> void:
	if not visible:
		return
	# Stay anchored as the panel resizes; scale from the anchored corner.
	var x := -size.x * 0.5
	if align == Align.LEFT_EDGE:
		x = 0.0
	elif align == Align.RIGHT_EDGE:
		x = -size.x
	position = Vector2(x, -size.y if grow_up else 0.0)
	pivot_offset = Vector2(-x, size.y if grow_up else 0.0)
