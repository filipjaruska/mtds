extends RefCounted
class_name ResultsFormat
## Pure helpers for the scoreboard (Tab) and the match results screen. `results`
## is GameManager.get_sorted_match_results(): [{id, name, team, kills, deaths,
## damage_dealt}], best damage first. Nothing here touches nodes.

## The table rows, top to bottom. Deathmatch: one row per player, ranked.
## Teams: a team row (best team first, winner flagged) followed by its players,
## ranked within the team.
##   {kind: "team", team, kills, deaths, damage, winning}
##   {kind: "player", rank, id, name, team, kills, deaths, damage}
static func rows(results: Array, team_mode: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not team_mode:
		for i in range(results.size()):
			out.append(_player_row(results[i], i + 1))
		return out
	var totals := TeamRules.team_totals(results)
	var winner := TeamRules.winner(totals)
	for total in totals:
		out.append({
			"kind": "team",
			"team": total.team,
			"kills": total.kills,
			"deaths": total.deaths,
			"damage": int(total.damage_dealt),
			"winning": winner == total.team,
		})
		var rank := 1
		for entry in results:
			if int(entry.get("team", 0)) == total.team:
				out.append(_player_row(entry, rank))
				rank += 1
	return out

## What the results screen leads with, from `my_id`'s point of view:
## {title, subtitle, outcome: "win" | "loss" | "draw" | "none"}.
static func headline(results: Array, team_mode: bool, my_id: int) -> Dictionary:
	if results.is_empty():
		return {"title": "Match over", "subtitle": "Nobody scored this time.", "outcome": "none"}
	if team_mode:
		var totals := TeamRules.team_totals(results)
		var winner := TeamRules.winner(totals)
		if winner < 0:
			return {"title": "Draw", "subtitle": "Both teams finished level.", "outcome": "draw"}
		var mine := -1
		for entry in results:
			if int(entry.get("id", 0)) == my_id:
				mine = int(entry.get("team", 0))
		var subtitle := "%s team wins, %d kills to %d" % [TeamRules.NAMES[winner], totals[0].kills, totals[1].kills]
		if mine == winner:
			return {"title": "Victory", "subtitle": subtitle, "outcome": "win"}
		return {"title": "Defeat", "subtitle": subtitle, "outcome": "loss" if mine >= 0 else "none"}
	var top: Dictionary = results[0]
	var damage := int(top.get("damage_dealt", 0.0))
	if int(top.get("id", 0)) == my_id:
		return {"title": "Victory", "subtitle": "You topped the board with %d damage." % damage, "outcome": "win"}
	var place := -1
	for i in range(results.size()):
		if int(results[i].get("id", 0)) == my_id:
			place = i + 1
	var winner_line := "%s won with %d damage." % [top.get("name", "Unknown"), damage]
	if place < 0:
		return {"title": "Match over", "subtitle": winner_line, "outcome": "none"}
	return {"title": "%s place" % ordinal(place), "subtitle": winner_line, "outcome": "loss"}

## 1 -> "1st", 2 -> "2nd", 11 -> "11th", 23 -> "23rd".
static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

static func _player_row(entry: Dictionary, rank: int) -> Dictionary:
	return {
		"kind": "player",
		"rank": rank,
		"id": int(entry.get("id", 0)),
		"name": str(entry.get("name", "Unknown")),
		"team": int(entry.get("team", 0)),
		"kills": int(entry.get("kills", 0)),
		"deaths": int(entry.get("deaths", 0)),
		"damage": int(entry.get("damage_dealt", 0.0)),
	}
