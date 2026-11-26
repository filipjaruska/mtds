extends RefCounted
class_name BlackjackRules
## The blackjack table's game, as pure functions: nothing here touches nodes or
## the network. Cards are PlayingCards ints. Nobody makes choices (the game has
## to be quick): players draw while under their stand-on total, then the dealer
## draws while under 17. A player wins only by beating the dealer: a higher
## total without going bust, or any total when the dealer busts. Ties lose.

const DEALER := -1
const LIMIT := 21

## Points of one card: 2-10 face value, J Q K 10, A 11 (hand_value counts an
## ace as 1 when 11 would bust).
static func card_points(card: int) -> int:
	var rank := PlayingCards.rank_of(card)
	if rank <= 8:
		return rank + 2
	return 11 if rank == 12 else 10

## Total of a hand; face-down cards (-1) do not count.
static func hand_value(cards: Array) -> int:
	var total := 0
	var soft_aces := 0
	for card in cards:
		if card < 0:
			continue
		total += card_points(card)
		if PlayingCards.rank_of(card) == 12:
			soft_aces += 1
	while total > LIMIT and soft_aces > 0:
		total -= 10
		soft_aces -= 1
	return total

static func is_bust(cards: Array) -> bool:
	return hand_value(cards) > LIMIT

static func should_draw(cards: Array, stand_on: int) -> bool:
	return hand_value(cards) < stand_on

## True when `player` beats `dealer`.
static func wins(player: Array, dealer: Array) -> bool:
	if is_bust(player):
		return false
	return is_bust(dealer) or hand_value(player) > hand_value(dealer)

## Plays a whole game for `seats` players. Returns
##   players: Array of hands (Array[int]), one per seat
##   dealer:  the dealer's hand
##   wins:    Array[bool], one per seat
##   steps:   the order the cards show up at the table, [seat, card index, face up];
##            seat DEALER is the dealer. The dealer's second card comes face down
##            and is turned over (a second step for it) before the dealer draws.
static func play(seats: int, player_stand_on: int, dealer_stand_on: int, rng: RandomNumberGenerator) -> Dictionary:
	var table := {"deck": PlayingCards.new_deck(rng), "in_play": [], "steps": [], "rng": rng}
	var players: Array = []
	for seat in range(seats):
		players.append([] as Array[int])
	var dealer: Array[int] = []
	for round_number in range(2):
		for seat in range(seats):
			_deal(table, players[seat], seat, true)
		_deal(table, dealer, DEALER, round_number == 0)
	for seat in range(seats):
		while should_draw(players[seat], player_stand_on):
			_deal(table, players[seat], seat, true)
	table.steps.append([DEALER, 1, true])
	while should_draw(dealer, dealer_stand_on):
		_deal(table, dealer, DEALER, true)
	var results: Array[bool] = []
	for hand in players:
		results.append(wins(hand, dealer))
	return {"players": players, "dealer": dealer, "wins": results, "steps": table.steps}

static func _deal(table: Dictionary, hand: Array[int], seat: int, face_up: bool) -> void:
	var drawn := PlayingCards.draw(table.deck, table.in_play, table.rng)
	table.deck = drawn.deck
	hand.append(drawn.card)
	table.in_play.append(drawn.card)
	table.steps.append([seat, hand.size() - 1, face_up])

## What the table shows of `hand` (seat `seat`) after the first `shown` steps:
## each card as itself when face up, -1 face down; cards not dealt yet are left out.
static func showing(hand: Array, seat: int, steps: Array, shown: int) -> Array[int]:
	var faces: Array[int] = []
	for i in range(mini(shown, steps.size())):
		var step: Array = steps[i]
		if step[0] != seat or step[1] >= hand.size():
			continue
		if step[1] >= faces.size():
			faces.resize(step[1] + 1)
		faces[step[1]] = hand[step[1]] if step[2] else -1
	return faces
