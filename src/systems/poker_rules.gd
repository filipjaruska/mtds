extends RefCounted
class_name PokerRules
## Pure poker helpers for the Poker card rules. Nothing here touches nodes or
## the network.
##
## A playing card is an int 0..51: rank = card % 13 (0 = 2 ... 8 = 10,
## 9 = J, 10 = Q, 11 = K, 12 = A), suit = card / 13 (spades, hearts, diamonds, clubs).
##
## Every powerup picked up under Poker carries one card (its "hole" card). It is
## played together with the board (up to 4 shared cards under the clock): that
## makes a poker hand of up to 5 cards, and the hand decides the powerup's stacks.

const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["♠", "♥", "♦", "♣"]
const SUIT_NAMES := ["spades", "hearts", "diamonds", "clubs"]

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector

const BOARD_SIZE := 4
## Seconds between board cards, and how often the board starts over.
static var REVEAL_INTERVAL: float = RULES.poker_reveal_seconds
static var ROUND_SECONDS: float = RULES.poker_round_seconds

enum Hand { HIGH_CARD, PAIR, TWO_PAIR, THREE_OF_A_KIND, STRAIGHT, FLUSH, FULL_HOUSE, FOUR_OF_A_KIND, STRAIGHT_FLUSH }

const HAND_NAMES := ["High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush"]
## Fits on a card in the hand.
const HAND_SHORT_NAMES := ["High", "Pair", "2 Pair", "Trips", "Straight", "Flush", "Full house", "Quads", "Str. flush"]
## Stacks a powerup is played with, per hand (index = Hand).
const HAND_STACKS := [1, 1, 2, 2, 3, 3, 4, 4, 4]

static func rank_of(card: int) -> int:
	return card % 13

@warning_ignore("integer_division")
static func suit_of(card: int) -> int:
	return card / 13

static func is_red(card: int) -> bool:
	var suit := suit_of(card)
	return suit == 1 or suit == 2

static func card_text(card: int) -> String:
	if card < 0 or card > 51:
		return "?"
	return RANKS[rank_of(card)] + SUITS[suit_of(card)]

## The best hand in `cards` (1 to 5 cards). Straights and flushes need 5.
## Returns {rank: Hand, name: String, stacks: int}.
static func evaluate(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		var r := rank_of(card)
		counts[r] = counts.get(r, 0) + 1
	var groups: Array = counts.values()
	groups.sort()
	groups.reverse() # largest group first, e.g. [3, 2]

	# Pairs, trips etc. With 5 cards a straight or flush cannot also hold a pair
	# group that beats it (only a full house or quads beat a flush, and those
	# leave no room for 5 different ranks or one suit), so the max is the answer.
	var hand: int = _group_hand(groups)
	if cards.size() == 5:
		var flush := _is_flush(cards)
		var straight := counts.size() == 5 and _is_straight(counts.keys())
		if straight and flush:
			hand = Hand.STRAIGHT_FLUSH
		elif flush:
			hand = maxi(hand, Hand.FLUSH)
		elif straight:
			hand = maxi(hand, Hand.STRAIGHT)
	return {"rank": hand, "name": HAND_NAMES[hand], "short": HAND_SHORT_NAMES[hand], "stacks": HAND_STACKS[hand]}

static func _group_hand(groups: Array) -> int:
	if groups.is_empty():
		return Hand.HIGH_CARD
	if groups[0] >= 4:
		return Hand.FOUR_OF_A_KIND
	if groups[0] == 3:
		return Hand.FULL_HOUSE if groups.size() > 1 and groups[1] >= 2 else Hand.THREE_OF_A_KIND
	if groups[0] == 2:
		return Hand.TWO_PAIR if groups.size() > 1 and groups[1] == 2 else Hand.PAIR
	return Hand.HIGH_CARD

static func _is_flush(cards: Array) -> bool:
	for card in cards:
		if suit_of(card) != suit_of(cards[0]):
			return false
	return true

## Five distinct ranks in a row; the ace may also play low (A-2-3-4-5).
static func _is_straight(ranks: Array) -> bool:
	var sorted := ranks.duplicate()
	sorted.sort()
	if sorted == [0, 1, 2, 3, 12]:
		return true
	return sorted[4] - sorted[0] == 4

## The hand a hole card makes with the board right now.
static func hand_with_board(hole: int, board: Array) -> Dictionary:
	var cards: Array = [hole]
	cards.append_array(board)
	return evaluate(cards)

## Board cards that should be face up `seconds` into the current minute.
static func revealed_count(seconds_into_minute: float) -> int:
	return clampi(1 + int(floor(seconds_into_minute / REVEAL_INTERVAL)), 1, BOARD_SIZE)

## Which minute of the match `elapsed` seconds falls in (0-based).
static func round_of(elapsed: float) -> int:
	return int(floor(maxf(elapsed, 0.0) / ROUND_SECONDS))

# --- Deck --------------------------------------------------------------------------

static func new_deck(rng: RandomNumberGenerator) -> Array[int]:
	var deck: Array[int] = []
	for card in range(52):
		deck.append(card)
	# Fisher-Yates with the given rng, so tests can seed it.
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck

## Takes the top card. An empty deck is rebuilt (minus the cards on the
## board) and shuffled. Returns {card: int, deck: Array[int]}.
static func draw(deck: Array[int], board: Array, rng: RandomNumberGenerator) -> Dictionary:
	var next: Array[int] = deck.duplicate()
	if next.is_empty():
		for card in new_deck(rng):
			if not board.has(card):
				next.append(card)
	var card: int = next.pop_back()
	return {"card": card, "deck": next}
