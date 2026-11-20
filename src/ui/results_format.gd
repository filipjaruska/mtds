extends RefCounted
class_name ResultsFormat
## Fills the scoreboard and match results lists. In team matches the players
## are grouped under a line per team (best team first) in the team's colour.

static func fill(list: ItemList, results: Array, team_mode: bool) -> void:
	list.clear()
	if not team_mode:
		for entry in results:
			list.add_item(player_line(entry))
		return

	var totals := TeamRules.team_totals(results)
	var winner := TeamRules.winner(totals)
	for total in totals:
		var team: int = total.team
		var label: String = TeamRules.NAMES[team]
		if winner == team:
			label += " (winning)"
		var index := list.add_item("%s  ||  %d kills  |  %d deaths  |  %d dmg" % [
			label, total.kills, total.deaths, int(total.damage_dealt)])
		list.set_item_custom_fg_color(index, TeamRules.COLORS[team])
		list.set_item_selectable(index, false)
		for entry in results:
			if int(entry.get("team", 0)) == team:
				index = list.add_item("    " + player_line(entry))
				list.set_item_custom_fg_color(index, TeamRules.COLORS[team].lightened(0.45))

static func player_line(entry: Dictionary) -> String:
	return "%s  ||  %d kills  |  %d deaths  |  %d dmg" % [
		entry.get("name", "Unknown"),
		entry.get("kills", 0),
		entry.get("deaths", 0),
		int(entry.get("damage_dealt", 0.0)),
	]
