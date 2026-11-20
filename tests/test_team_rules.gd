extends "res://tests/test_case.gd"

func _players(teams: Dictionary) -> Dictionary:
	var players := {}
	for id in teams:
		players[id] = {"id": id, "name": "P%d" % id, "team": teams[id]}
	return players

func test_pick_team_fills_smaller_team() -> void:
	check_eq(TeamRules.pick_team({}), 0, "first player is Red")
	check_eq(TeamRules.pick_team(_players({1: 0})), 1)
	check_eq(TeamRules.pick_team(_players({1: 0, 2: 1})), 0, "tie goes to Red")
	check_eq(TeamRules.pick_team(_players({1: 1, 2: 1, 3: 0})), 0)

func test_friendly_only_in_team_mode() -> void:
	var players := _players({1: 0, 2: 0, 3: 1})
	check(TeamRules.is_friendly(players, 1, 2, true), "same team")
	check(not TeamRules.is_friendly(players, 1, 3, true), "other team")
	check(not TeamRules.is_friendly(players, 1, 2, false), "deathmatch has no friends")
	check(not TeamRules.is_friendly(players, 1, 1, true), "self is not a teammate")

func test_spawn_index_deathmatch_follows_id_order() -> void:
	var players := _players({7: 0, 1: 0, 3: 1})
	check_eq(TeamRules.spawn_index(players, 1, false), 0)
	check_eq(TeamRules.spawn_index(players, 3, false), 1)
	check_eq(TeamRules.spawn_index(players, 7, false), 2)

func test_spawn_index_teams_use_own_side() -> void:
	var players := _players({1: 0, 2: 1, 3: 0, 4: 1, 5: 0})
	check_eq(TeamRules.spawn_index(players, 1, true), 0, "first Red")
	check_eq(TeamRules.spawn_index(players, 3, true), 2, "second Red")
	check_eq(TeamRules.spawn_index(players, 5, true), 4, "third Red")
	check_eq(TeamRules.spawn_index(players, 2, true), 1, "first Blue")
	check_eq(TeamRules.spawn_index(players, 4, true), 3, "second Blue")

func test_respawn_indices() -> void:
	check_eq(TeamRules.respawn_indices(0, 5, false), [0, 1, 2, 3, 4] as Array[int])
	check_eq(TeamRules.respawn_indices(0, 5, true), [0, 2, 4] as Array[int])
	check_eq(TeamRules.respawn_indices(1, 5, true), [1, 3] as Array[int])
	check_eq(TeamRules.respawn_indices(1, 1, true), [0] as Array[int], "single spawn map")

func test_team_totals_and_winner() -> void:
	var results := [
		{"team": 0, "kills": 3, "deaths": 1, "damage_dealt": 300.0},
		{"team": 1, "kills": 4, "deaths": 2, "damage_dealt": 250.0},
		{"team": 0, "kills": 2, "deaths": 5, "damage_dealt": 100.0},
	]
	var totals := TeamRules.team_totals(results)
	check_eq(totals[0].team, 0, "Red first")
	check_eq(totals[0].kills, 5)
	check_eq(totals[0].damage_dealt, 400.0)
	check_eq(totals[1].kills, 4)
	check_eq(TeamRules.winner(totals), 0)

func test_winner_tie_breaks_on_damage_then_draws() -> void:
	var by_damage := TeamRules.team_totals([
		{"team": 0, "kills": 2, "damage_dealt": 100.0},
		{"team": 1, "kills": 2, "damage_dealt": 150.0},
	])
	check_eq(TeamRules.winner(by_damage), 1)
	var draw := TeamRules.team_totals([
		{"team": 0, "kills": 2, "damage_dealt": 100.0},
		{"team": 1, "kills": 2, "damage_dealt": 100.0},
	])
	check_eq(TeamRules.winner(draw), -1)
