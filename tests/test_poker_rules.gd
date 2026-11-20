extends "res://tests/test_case.gd"

## Card from text like "Ks", "10h", "Ad" (s/h/d/c).
func _c(text: String) -> int:
	var suit := "shdc".find(text.right(1))
	var rank := PokerRules.RANKS.find(text.left(text.length() - 1))
	return suit * 13 + rank

func _hand(texts: Array) -> int:
	var cards: Array = []
	for t in texts:
		cards.append(_c(t))
	return PokerRules.evaluate(cards).rank

func test_card_encoding() -> void:
	check_eq(PokerRules.card_text(_c("Ks")), "K♠")
	check_eq(PokerRules.card_text(_c("10h")), "10♥")
	check(PokerRules.is_red(_c("2d")), "diamonds are red")
	check(not PokerRules.is_red(_c("2c")), "clubs are black")

func test_every_hand_with_five_cards() -> void:
	check_eq(_hand(["2s", "7h", "9d", "Jc", "Ks"]), PokerRules.Hand.HIGH_CARD)
	check_eq(_hand(["7s", "7h", "9d", "Jc", "Ks"]), PokerRules.Hand.PAIR)
	check_eq(_hand(["7s", "7h", "Kd", "Kc", "2s"]), PokerRules.Hand.TWO_PAIR)
	check_eq(_hand(["7s", "7h", "7d", "Kc", "2s"]), PokerRules.Hand.THREE_OF_A_KIND)
	check_eq(_hand(["5s", "6h", "7d", "8c", "9s"]), PokerRules.Hand.STRAIGHT)
	check_eq(_hand(["As", "2h", "3d", "4c", "5s"]), PokerRules.Hand.STRAIGHT, "ace plays low")
	check_eq(_hand(["10s", "Jh", "Qd", "Kc", "As"]), PokerRules.Hand.STRAIGHT, "ace plays high")
	check_eq(_hand(["Qs", "Kh", "Ad", "2c", "3s"]), PokerRules.Hand.HIGH_CARD, "no wrap-around straight")
	check_eq(_hand(["2h", "7h", "9h", "Jh", "Kh"]), PokerRules.Hand.FLUSH)
	check_eq(_hand(["7s", "7h", "7d", "Kc", "Ks"]), PokerRules.Hand.FULL_HOUSE)
	check_eq(_hand(["7s", "7h", "7d", "7c", "Ks"]), PokerRules.Hand.FOUR_OF_A_KIND)
	check_eq(_hand(["5h", "6h", "7h", "8h", "9h"]), PokerRules.Hand.STRAIGHT_FLUSH)

func test_partial_hands() -> void:
	check_eq(_hand(["7s"]), PokerRules.Hand.HIGH_CARD, "hole card alone")
	check_eq(_hand(["7s", "7h"]), PokerRules.Hand.PAIR)
	check_eq(_hand(["7s", "7h", "7d"]), PokerRules.Hand.THREE_OF_A_KIND)
	check_eq(_hand(["7s", "7h", "Kd", "Kc"]), PokerRules.Hand.TWO_PAIR)
	check_eq(_hand(["2h", "7h", "9h", "Jh"]), PokerRules.Hand.HIGH_CARD, "flush needs 5 cards")
	check_eq(_hand(["5s", "6h", "7d", "8c"]), PokerRules.Hand.HIGH_CARD, "straight needs 5 cards")

func test_stacks_per_hand() -> void:
	check_eq(PokerRules.evaluate([_c("7s")]).stacks, 1)
	check_eq(PokerRules.evaluate([_c("7s"), _c("7h"), _c("Kd"), _c("Kc")]).stacks, 2)
	check_eq(PokerRules.evaluate([_c("5s"), _c("6h"), _c("7d"), _c("8c"), _c("9s")]).stacks, 3)
	check_eq(PokerRules.evaluate([_c("7s"), _c("7h"), _c("7d"), _c("Kc"), _c("Ks")]).stacks, 4)
	check_eq(PokerRules.hand_with_board(_c("7s"), [_c("7h")]).name, "Pair")

func test_reveal_schedule() -> void:
	check_eq(PokerRules.revealed_count(0.0), 1)
	check_eq(PokerRules.revealed_count(14.9), 1)
	check_eq(PokerRules.revealed_count(15.0), 2)
	check_eq(PokerRules.revealed_count(30.0), 3)
	check_eq(PokerRules.revealed_count(45.0), 4)
	check_eq(PokerRules.revealed_count(59.9), 4)
	check_eq(PokerRules.round_of(59.9), 0)
	check_eq(PokerRules.round_of(60.0), 1, "new minute, new board")

func test_deck_draws_without_duplicates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var deck := PokerRules.new_deck(rng)
	check_eq(deck.size(), 52)
	var seen := {}
	for i in range(52):
		var result := PokerRules.draw(deck, [], rng)
		check(not seen.has(result.card), "card %d drawn twice" % result.card)
		seen[result.card] = true
		deck = result.deck
	check(deck.is_empty(), "deck used up")

func test_reshuffle_skips_board_cards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var board := [_c("As"), _c("Kh")]
	var empty: Array[int] = []
	var deck := empty
	for i in range(50):
		var result := PokerRules.draw(deck, board, rng)
		check(not board.has(result.card), "never deals a card that is on the board")
		deck = result.deck
