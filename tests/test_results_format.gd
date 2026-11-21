extends "res://tests/test_case.gd"

func _entry(id: int, team: int, kills: int, deaths: int, damage: float) -> Dictionary:
	return {"id": id, "name": "P%d" % id, "team": team, "kills": kills, "deaths": deaths, "damage_dealt": damage}

func test_deathmatch_rows_are_ranked_players() -> void:
	var rows := ResultsFormat.rows([_entry(3, 0, 4, 1, 300.0), _entry(1, 0, 2, 2, 120.5)], false)
	check_eq(rows.size(), 2)
	check_eq(rows[0].kind, "player")
	check_eq(rows[0].rank, 1)
	check_eq(rows[0].id, 3)
	check_eq(rows[1].rank, 2)
	check_eq(rows[1].damage, 120, "damage is shown whole")

func test_team_rows_put_winning_team_first() -> void:
	var results := [_entry(1, 0, 1, 3, 200.0), _entry(2, 1, 3, 0, 150.0), _entry(3, 1, 2, 1, 90.0)]
	var rows := ResultsFormat.rows(results, true)
	check_eq(rows.size(), 5, "two team rows and three players")
	check_eq(rows[0].kind, "team")
	check_eq(rows[0].team, 1, "Blue has more kills")
	check(rows[0].winning)
	check_eq(rows[0].kills, 5)
	check_eq(rows[1].id, 2)
	check_eq(rows[2].rank, 2, "ranked within the team")
	check_eq(rows[3].kind, "team")
	check(not rows[3].winning)
	check_eq(rows[4].rank, 1)

func test_headline_deathmatch() -> void:
	var results := [_entry(3, 0, 4, 1, 300.0), _entry(1, 0, 2, 2, 120.0), _entry(2, 0, 0, 3, 10.0)]
	check_eq(ResultsFormat.headline(results, false, 3).outcome, "win")
	var third := ResultsFormat.headline(results, false, 2)
	check_eq(third.title, "3rd place")
	check_eq(third.subtitle, "P3 won with 300 damage.")
	check_eq(ResultsFormat.headline([], false, 1).outcome, "none")

func test_headline_teams() -> void:
	var results := [_entry(1, 0, 1, 3, 200.0), _entry(2, 1, 3, 0, 150.0)]
	check_eq(ResultsFormat.headline(results, true, 2).title, "Victory")
	check_eq(ResultsFormat.headline(results, true, 1).title, "Defeat")
	var level := [_entry(1, 0, 1, 1, 50.0), _entry(2, 1, 1, 1, 50.0)]
	check_eq(ResultsFormat.headline(level, true, 1).outcome, "draw")

func test_ordinal() -> void:
	check_eq(ResultsFormat.ordinal(1), "1st")
	check_eq(ResultsFormat.ordinal(2), "2nd")
	check_eq(ResultsFormat.ordinal(3), "3rd")
	check_eq(ResultsFormat.ordinal(4), "4th")
	check_eq(ResultsFormat.ordinal(11), "11th")
	check_eq(ResultsFormat.ordinal(22), "22nd")
