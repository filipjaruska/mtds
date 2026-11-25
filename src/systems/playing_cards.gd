extends RefCounted
class_name PlayingCards
## A standard 52-card deck, as plain ints. Pure functions: nothing here touches
## nodes or the network.
##
## A playing card is an int 0..51: rank = card % 13 (0 = 2 ... 8 = 10,
## 9 = J, 10 = Q, 11 = K, 12 = A), suit = card / 13 (spades, hearts, diamonds, clubs).
## -1 means a face-down card.

const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["♠", "♥", "♦", "♣"]
const SUIT_NAMES := ["spades", "hearts", "diamonds", "clubs"]

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

## All 52 cards, shuffled with `rng` (seed it in tests).
static func new_deck(rng: RandomNumberGenerator) -> Array[int]:
	var deck: Array[int] = []
	for card in range(52):
		deck.append(card)
	# Fisher-Yates.
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck

## Takes the top card. An empty deck is rebuilt (minus the cards `in_play`)
## and shuffled. Returns {card: int, deck: Array[int]}.
static func draw(deck: Array[int], in_play: Array, rng: RandomNumberGenerator) -> Dictionary:
	var next: Array[int] = deck.duplicate()
	if next.is_empty():
		for card in new_deck(rng):
			if not in_play.has(card):
				next.append(card)
	var card: int = next.pop_back()
	return {"card": card, "deck": next}
