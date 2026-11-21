extends Control
class_name TopBarSlot
## One player in the top bar (TopBarUI): their sprite in their colour, the first
## letter of their name on a tab, a thin HP bar, greyed out while dead, and the
## anchor their chat bubbles hang from. Layout in top_bar_slot.tscn.

const SIZE := 34.0
const BUBBLE_TOP := 43.0 # under the HP bar

var side := "left"
var index := 0
var bubble: ChatBubbleView

@onready var _frame: Panel = $Frame
@onready var _icon: TextureRect = $Frame/Icon
@onready var _badge: PanelContainer = $Badge
@onready var _letter: Label = $Badge/Letter
@onready var _hp_track: Panel = $HpTrack
@onready var _hp: ColorRect = $Hp
@onready var anchor: Control = $BubbleAnchor

## Left of the clock the letter tab and the bubbles sit on the outer (left)
## side, right of it on the right, so nothing grows towards the clock.
func setup(color: Color, mine: bool, left_side: bool, initial: String) -> void:
	side = "left" if left_side else "right"
	var frame_style: StyleBoxFlat = _frame.get_theme_stylebox("panel").duplicate()
	frame_style.border_color = UiPalette.ACCENT if mine else color.darkened(0.35)
	_frame.add_theme_stylebox_override("panel", frame_style)
	var tab_style: StyleBoxFlat = _badge.get_theme_stylebox("panel").duplicate()
	tab_style.border_color = frame_style.border_color
	_badge.add_theme_stylebox_override("panel", tab_style)
	_icon.modulate = color
	_letter.text = initial
	_badge.position.x = -4.0 if left_side else SIZE - 9.0
	anchor.position = Vector2(SIZE if left_side else 0.0, BUBBLE_TOP)
	bubble = ChatBubbleView.create(11, 160.0, ChatBubbleView.Align.RIGHT_EDGE if left_side else ChatBubbleView.Align.LEFT_EDGE, false)
	anchor.add_child(bubble)

func show_health(fraction: float, dead: bool) -> void:
	_hp.size.x = _hp_track.size.x * fraction
	_hp.color = UiPalette.GOOD if fraction > 0.5 else (UiPalette.WARN if fraction > 0.25 else UiPalette.BAD)
	var tint := Color(0.4, 0.4, 0.42) if dead else Color.WHITE # greyed, still solid
	_frame.modulate = tint
	_badge.modulate = tint
