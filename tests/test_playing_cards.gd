extends "res://tests/test_case.gd"

## Card from text like "Ks", "10h", "Ad" (s/h/d/c).
func _c(text: String) -> int:
	var suit := "shdc".find(text.right(1))
	var rank := PlayingCards.RANKS.find(text.left(text.length() - 1))
	return suit * 13 + rank

func test_card_text_and_colour() -> void:
	check_eq(PlayingCards.card_text(_c("Ks")), "K♠")
	check_eq(PlayingCards.card_text(_c("10h")), "10♥")
	check_eq(PlayingCards.card_text(-1), "?")
	check(PlayingCards.is_red(_c("2d")), "diamonds are red")
	check(not PlayingCards.is_red(_c("2c")), "clubs are black")

func test_deck_draws_without_duplicates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var deck := PlayingCards.new_deck(rng)
	check_eq(deck.size(), 52)
	var seen := {}
	for i in range(52):
		var result := PlayingCards.draw(deck, [], rng)
		check(not seen.has(result.card), "card %d drawn twice" % result.card)
		seen[result.card] = true
		deck = result.deck
	check(deck.is_empty(), "deck used up")

func test_reshuffle_skips_cards_in_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var in_play := [_c("As"), _c("Kh")]
	var empty: Array[int] = []
	var deck := empty
	for i in range(50):
		var result := PlayingCards.draw(deck, in_play, rng)
		check(not in_play.has(result.card), "never deals a card that is in play")
		deck = result.deck
