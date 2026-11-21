extends Control
class_name PokerBoardUI
## The poker board under the match clock (Poker card rules only): four shared
## playing cards, dealt by the host one every 15 s and replaced every minute
## (GameManager.poker_board). A thin bar shows the time to the next card.
## This node sits at the top-centre of the screen; it only reads GameManager.

const SLOT_SIZE := Vector2(36, 50)
const GAP := 6.0

var _cards: Array[PlayingCardView] = []
var _shown_round := -1
var _shown: Array[int] = []
var _swept_at := -10.0 # time of the last sweep; reveals right after it wait for it
var _time := 0.0
var _bar_bg: ColorRect
var _bar: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := SLOT_SIZE.x * PokerRules.BOARD_SIZE + GAP * (PokerRules.BOARD_SIZE - 1)
	for i in range(PokerRules.BOARD_SIZE):
		var view := PlayingCardView.new(SLOT_SIZE)
		view.position = Vector2(-total * 0.5 + i * (SLOT_SIZE.x + GAP), 0)
		add_child(view)
		_cards.append(view)
	_bar_bg = ColorRect.new()
	_bar_bg.color = UiPalette.BORDER
	_bar_bg.position = Vector2(-total * 0.5, SLOT_SIZE.y + 5)
	_bar_bg.size = Vector2(total, 3)
	add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = UiPalette.ACCENT
	_bar.position = _bar_bg.position
	_bar.size = Vector2(0, 3)
	add_child(_bar)
	visible = false

func _process(delta: float) -> void:
	_time += delta
	var active := GameManager.is_poker_mode() and GameManager.is_state(GameManager.GameState.PLAYING)
	visible = active
	if not active:
		return
	var board: Array[int] = GameManager.poker_board
	if GameManager.poker_round != _shown_round:
		_new_round(GameManager.poker_round)
	for i in range(_shown.size(), board.size()):
		_reveal(i, board[i])
	_update_bar(board.size())

## A new minute: the old cards sweep away and fresh backs drop in.
func _new_round(round_index: int) -> void:
	var first := _shown_round == -1
	_shown_round = round_index
	_shown.clear()
	if not first:
		_swept_at = _time
	for i in range(_cards.size()):
		var view := _cards[i]
		if first:
			view.show_card(-1)
			continue
		var home := view.position
		var tween := view.create_tween()
		tween.tween_interval(i * 0.05)
		tween.tween_property(view, "position:y", home.y - 30.0, 0.15).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(view, "modulate:a", 0.0, 0.15)
		tween.tween_callback(view.show_card.bind(-1))
		tween.tween_property(view, "position:y", home.y, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "modulate:a", 1.0, 0.2)

func _reveal(index: int, value: int) -> void:
	_shown.append(value)
	var view := _cards[index]
	var delay := maxf(0.0, _swept_at + 0.45 - _time)
	view.flip_to(value, delay)
	# A little hop as it lands.
	var tween := view.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(view, "position:y", -6.0, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## Time until the next card (or until the new board after the 4th).
func _update_bar(revealed: int) -> void:
	var into := GameManager.get_poker_seconds_into_round()
	var next_at := revealed * PokerRules.REVEAL_INTERVAL
	var fraction := clampf(1.0 - (next_at - into) / PokerRules.REVEAL_INTERVAL, 0.0, 1.0)
	_bar.size.x = _bar_bg.size.x * fraction
