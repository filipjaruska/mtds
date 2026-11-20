extends Control
class_name PlayingCardView
## A small playing card (see PokerRules for the int encoding): a white face
## with rank and suit, or the card back. Used for the poker board under the
## clock and as the badge on powerup cards in the hand.

const CARD_BACK := preload("res://src/assets/cards/card_back.png")
const SUIT_ICONS := [
	preload("res://src/assets/cards/suits/spades.png"),
	preload("res://src/assets/cards/suits/hearts.png"),
	preload("res://src/assets/cards/suits/diamonds.png"),
	preload("res://src/assets/cards/suits/clubs.png"),
]
const FACE_COLOR := Color("f4f1ea")
const RED := Color("d62828")
const BLACK := Color("1c1c22")

var card := -1 # -1 = face down

var _face: Panel
var _rank: Label
var _suit: TextureRect
var _back: TextureRect

func _init(card_size: Vector2 = Vector2(36, 50)) -> void:
	size = card_size
	custom_minimum_size = card_size
	pivot_offset = card_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_back = TextureRect.new()
	_back.texture = CARD_BACK
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_SCALE
	_back.size = card_size
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)

	_face = Panel.new()
	_face.size = card_size
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FACE_COLOR
	style.set_corner_radius_all(int(card_size.x * 0.12))
	style.set_border_width_all(1)
	style.border_color = Color(0, 0, 0, 0.45)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 2
	_face.add_theme_stylebox_override("panel", style)
	add_child(_face)

	_rank = Label.new()
	_rank.position = Vector2(2, 0)
	_rank.size = Vector2(card_size.x - 2, card_size.y * 0.45)
	_rank.add_theme_font_size_override("font_size", int(card_size.y * 0.34))
	_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_rank)

	_suit = TextureRect.new()
	_suit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_suit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon := card_size.x * 0.62
	_suit.size = Vector2(icon, icon)
	_suit.position = Vector2(card_size.x - icon - 1, card_size.y - icon - 2)
	_suit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_suit)

	show_card(-1)

## Shows `value` face up, or the back for -1. No animation.
func show_card(value: int) -> void:
	card = value
	var face_up := value >= 0
	_face.visible = face_up
	_back.visible = not face_up
	if not face_up:
		return
	_rank.text = PokerRules.RANKS[PokerRules.rank_of(value)]
	_rank.add_theme_color_override("font_color", RED if PokerRules.is_red(value) else BLACK)
	_suit.texture = SUIT_ICONS[PokerRules.suit_of(value)]

## Turns the card over to show `value` (or its back for -1).
func flip_to(value: int, delay: float = 0.0) -> void:
	if value == card:
		return
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(show_card.bind(value))
	tween.tween_property(self, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
