extends RoomGameEvent
class_name BlackjackEvent
## The blackjack room (a room game, see RoomGameEvent): a quick blackjack game
## nobody makes choices in (BlackjackRules). Players draw to 17, then the
## dealer does; whoever beats the dealer keeps their cards, everyone else loses
## them (a tie loses). Everyone sees the same cards turn over on the table.

const CARD_SIZE := Vector2(30, 42)
const CARD_GAP := 14.0

@export_group("Blackjack")
## Time between two cards being dealt or turned over.
@export_range(0.1, 2.0, 0.05, "suffix:s") var deal_step_seconds: float = 0.6
## Players draw while their total is under this. 0: they keep their first two cards.
@export_range(0, 21) var player_stand_on: int = 17
## The dealer draws while under this.
@export_range(2, 21) var dealer_stand_on: int = 17

## Every peer, once dealt: the hands and the order the cards show up.
var hands: Array = []
var dealer_hand: Array[int] = []
var steps: Array = []

var _dealt_msec := 0
var _step_msec := 600
var _shown := 0
var _views: Array = [] # per hand (seated players, then the dealer): {root, cards, total}

func play_game(players: int) -> Dictionary:
	var game := BlackjackRules.play(players, player_stand_on, dealer_stand_on, rng)
	var outcome: Array[int] = []
	for won in game.wins:
		outcome.append(KEEP if won else LOSE_ALL)
	# One more step after the last card, so the dealer's total can be read.
	return {"results": outcome, "seconds": deal_step_seconds * (game.steps.size() + 2),
		"players": game.players, "dealer": game.dealer, "steps": game.steps, "step": deal_step_seconds}

func _game_started(game: Dictionary) -> void:
	hands = game.players
	dealer_hand.assign(game.dealer)
	steps = game.steps
	_step_msec = int(float(game.step) * 1000.0)
	_dealt_msec = Time.get_ticks_msec()
	_shown = 0
	for view in _views:
		view.root.queue_free()
	_views.clear()
	for i in range(seated.size()):
		_views.append(_hand_view(table.seat_spot(seats[i])))
	_views.append(_hand_view(table.host_spot()))

func _hand_view(spot: Vector2) -> Dictionary:
	var root := Node2D.new()
	root.z_index = 2
	add_child(root)
	root.global_position = spot
	var total := Label.new()
	total.size = Vector2(120, 20)
	total.position = Vector2(-60, CARD_SIZE.y * 0.5 + 2)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPalette.world_text(total, UiPalette.XS, UiPalette.TEXT)
	root.add_child(total)
	return {"root": root, "cards": [], "total": total}

## Turns over the cards that are due by now.
func _game_tick() -> void:
	if steps.is_empty() or _views.is_empty() or table == null:
		return
	var due := steps.size()
	if phase == Phase.PLAYING:
		due = mini(int((Time.get_ticks_msec() - _dealt_msec) / float(maxi(_step_msec, 1))) + 1, steps.size())
	if due == _shown and _shown > 0:
		return
	_shown = due
	for i in range(_views.size()):
		var dealer := i == seated.size()
		var hand: Array = dealer_hand if dealer else hands[i]
		var faces := BlackjackRules.showing(hand, BlackjackRules.DEALER if dealer else i, steps, _shown)
		_lay_cards(_views[i], faces)
		var total: Label = _views[i].total
		var value := BlackjackRules.hand_value(faces)
		if faces.is_empty():
			total.text = ""
		elif value > BlackjackRules.LIMIT:
			total.text = "BUST"
			total.add_theme_color_override("font_color", UiPalette.BAD)
		else:
			total.text = str(value)
	_update_hud()

func _lay_cards(view: Dictionary, faces: Array[int]) -> void:
	var cards: Array = view.cards
	var root: Node2D = view.root
	while cards.size() < faces.size():
		var card := PlayingCardView.new(CARD_SIZE)
		root.add_child(card)
		# Slides in from the dealer.
		card.position = root.to_local(table.host().global_position) - CARD_SIZE * 0.5
		cards.append(card)
	for k in range(cards.size()):
		var card: PlayingCardView = cards[k]
		var target := Vector2((k - (cards.size() - 1) * 0.5) * CARD_GAP, 0) - CARD_SIZE * 0.5
		if not card.position.is_equal_approx(target):
			create_tween().tween_property(card, "position", target, 0.18).set_ease(Tween.EASE_OUT)
		if card.card != faces[k]:
			card.flip_to(faces[k], 0.12)

func _game_over() -> void:
	_game_tick()
	for i in range(mini(seated.size(), _views.size())):
		var total: Label = _views[i].total
		total.text += "  " + result_text(results[i])
		total.add_theme_color_override("font_color", UiPalette.BAD if results[i] == LOSE_ALL else UiPalette.GOOD)

func hud_line(seat: int) -> String:
	var you := BlackjackRules.showing(hands[seat], seat, steps, _shown)
	var dealer := BlackjackRules.showing(dealer_hand, BlackjackRules.DEALER, steps, _shown)
	return "You %s  ·  Dealer %s" % [_total_text(you), _total_text(dealer)]

static func _total_text(faces: Array[int]) -> String:
	if faces.is_empty():
		return "-"
	var value := BlackjackRules.hand_value(faces)
	return "bust" if value > BlackjackRules.LIMIT else str(value)

func _game_cleared() -> void:
	for view in _views:
		view.root.queue_free()
	_views.clear()
