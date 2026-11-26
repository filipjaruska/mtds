extends "res://tests/test_case.gd"
## The blackjack table: totals, aces, busts, who wins and the dealer drawing.

# PlayingCards: card = suit * 13 + rank, rank 0 = "2" ... 8 = "10", 9 J, 10 Q, 11 K, 12 A.
const TWO := 0
const FIVE := 3
const SIX := 4
const SEVEN := 5
const NINE := 7
const TEN := 8
const KING := 11
const ACE := 12

func test_card_points() -> void:
	check_eq(BlackjackRules.card_points(TWO), 2)
	check_eq(BlackjackRules.card_points(TEN), 10)
	check_eq(BlackjackRules.card_points(KING + 13), 10, "faces count 10 in any suit")
	check_eq(BlackjackRules.card_points(ACE), 11)

func test_aces_count_one_or_eleven() -> void:
	check_eq(BlackjackRules.hand_value([ACE, KING]), 21)
	check_eq(BlackjackRules.hand_value([ACE, ACE + 13]), 12, "two aces: 11 + 1")
	check_eq(BlackjackRules.hand_value([ACE, NINE, FIVE]), 15, "the ace drops to 1 instead of busting")
	check_eq(BlackjackRules.hand_value([ACE, ACE + 13, ACE + 26, NINE]), 12)

func test_face_down_cards_do_not_count() -> void:
	check_eq(BlackjackRules.hand_value([KING, -1]), 10)

func test_bust() -> void:
	check(BlackjackRules.is_bust([KING, NINE, FIVE]), "24 is bust")
	check(not BlackjackRules.is_bust([KING, ACE]), "21 is not")

func test_who_wins() -> void:
	check(BlackjackRules.wins([KING, NINE], [KING, SEVEN]), "19 beats 17")
	check(not BlackjackRules.wins([KING, SEVEN], [KING, NINE]), "17 loses to 19")
	check(not BlackjackRules.wins([KING, SEVEN], [TEN, SEVEN]), "a tie loses")
	check(BlackjackRules.wins([KING, TWO], [KING, SIX, NINE]), "the dealer busts: any standing hand wins")
	check(not BlackjackRules.wins([KING, SIX, NINE], [KING, SIX, NINE + 13]), "both bust: the player loses")

func test_drawing() -> void:
	check(BlackjackRules.should_draw([KING, SIX], 17), "16 draws")
	check(not BlackjackRules.should_draw([KING, SEVEN], 17), "17 stands")
	check(not BlackjackRules.should_draw([TWO, TWO + 13], 0), "stand on 0: never draws")

func test_a_whole_game() -> void:
	var rng := RandomNumberGenerator.new()
	for game_seed in range(40):
		rng.seed = game_seed
		var game := BlackjackRules.play(3, 17, 17, rng)
		check_eq(game.players.size(), 3)
		check_eq(game.wins.size(), 3)
		var seen := {}
		for hand in game.players + [game.dealer]:
			check(hand.size() >= 2, "everyone gets two cards")
			for card in hand:
				check(not seen.has(card), "no card dealt twice")
				seen[card] = true
		for hand in game.players:
			check(BlackjackRules.hand_value(hand) >= 17, "players drew to 17: %s" % [hand])
			check_eq(BlackjackRules.hand_value(hand.slice(0, hand.size() - 1)) < 17 or hand.size() == 2, true, "and stopped there")
		check(BlackjackRules.hand_value(game.dealer) >= 17, "dealer drew to 17")
		for seat in range(3):
			check_eq(game.wins[seat], BlackjackRules.wins(game.players[seat], game.dealer))
		check_eq(game.steps.size(), seen.size() + 1, "a step per card, plus turning the dealer's card")

func test_seats_spread_round_the_table() -> void:
	check_eq(BlackjackRules.spread_seats(1, 8).size(), 1)
	for players in range(1, 9):
		var seats := BlackjackRules.spread_seats(players, 8)
		var taken := {}
		for seat in seats:
			check(seat >= 0 and seat < 8, "a seat at the table")
			taken[seat] = true
		check_eq(taken.size(), players, "%d players, %d different seats: %s" % [players, players, seats])
	check_eq(BlackjackRules.spread_seats(10, 8).size(), 8, "no more players than seats")

func test_what_the_table_shows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var game := BlackjackRules.play(1, 17, 17, rng)
	var steps: Array = game.steps
	# Steps: seat 0, dealer (up), seat 0, dealer (down) ...
	check_eq(BlackjackRules.showing(game.players[0], 0, steps, 1), [game.players[0][0]] as Array[int])
	check_eq(BlackjackRules.showing(game.dealer, BlackjackRules.DEALER, steps, 4), [game.dealer[0], -1] as Array[int], "the dealer's second card is face down")
	check_eq(BlackjackRules.showing(game.dealer, BlackjackRules.DEALER, steps, steps.size()), game.dealer, "all turned over at the end")
	check_eq(BlackjackRules.showing(game.players[0], 0, steps, 0), [] as Array[int], "nothing before the deal")
