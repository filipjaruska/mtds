extends "res://tests/test_case.gd"
## A roaming NPC (Shady Fella): what he offers and who may trade with him.

const State := RoamingNpcRules.State

func test_offer_has_different_cards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var offer := RoamingNpcRules.roll_offer([&"a", &"b", &"c", &"d"], 3, rng)
	check_eq(offer.size(), 3)
	check_eq({offer[0]: 1, offer[1]: 1, offer[2]: 1}.size(), 3, "no card twice")
	check_eq(RoamingNpcRules.roll_offer([&"a", &"b"], 3, rng).size(), 2, "fewer when there are not enough")

func test_who_may_open_the_trade() -> void:
	var offer: Array[StringName] = [&"a", &"b"]
	check_eq(RoamingNpcRules.open_refusal(State.ROAMING, 0, 5, {}, offer, 50.0, 120.0, true), "")
	check_eq(RoamingNpcRules.open_refusal(State.BUSY, 7, 5, {}, offer, 50.0, 120.0, true), "busy", "someone else is choosing")
	check_eq(RoamingNpcRules.open_refusal(State.ROAMING, 0, 5, {5: true}, offer, 50.0, 120.0, true), "already picked", "one card each")
	check_eq(RoamingNpcRules.open_refusal(State.ROAMING, 0, 5, {}, offer, 200.0, 120.0, true), "too far")
	check_eq(RoamingNpcRules.open_refusal(State.ROAMING, 0, 5, {}, offer, 50.0, 120.0, false), "hands full")
	check_eq(RoamingNpcRules.open_refusal(State.FLEEING, 0, 5, {}, offer, 50.0, 120.0, true), "gone")
	check_eq(RoamingNpcRules.open_refusal(State.ROAMING, 0, 5, {}, [], 50.0, 120.0, true), "gone", "no cards left")

func test_who_may_pick() -> void:
	var offer: Array[StringName] = [&"a", &"b"]
	check(RoamingNpcRules.can_pick(State.BUSY, 5, 5, offer, 1, 50.0, 180.0, true))
	check(not RoamingNpcRules.can_pick(State.BUSY, 7, 5, offer, 1, 50.0, 180.0, true), "only the one choosing")
	check(not RoamingNpcRules.can_pick(State.BUSY, 5, 5, offer, 2, 50.0, 180.0, true), "a card he has")
	check(not RoamingNpcRules.can_pick(State.ROAMING, 5, 5, offer, 0, 50.0, 180.0, true), "only while choosing")

func test_shot_drops_one_of_his_cards() -> void:
	var rng := RandomNumberGenerator.new()
	check([&"a", &"b"].has(RoamingNpcRules.dropped_card([&"a", &"b"], rng)))
	check_eq(RoamingNpcRules.dropped_card([], rng), &"", "nothing left, nothing drops")
