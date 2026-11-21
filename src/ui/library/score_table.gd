extends VBoxContainer
class_name ScoreTable
## The score table shared by the scoreboard (Tab) and the match results:
## a header, then ScoreRow lines from ResultsFormat.rows(). Your own line is
## marked; in team matches each team's players follow its summary line.

const ROW := preload("res://src/ui/library/score_row.tscn")

func show_results(results: Array, team_mode: bool, my_id: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var header: ScoreRow = ROW.instantiate()
	add_child(header)
	header.show_header()
	var index := 0
	for row in ResultsFormat.rows(results, team_mode):
		var line: ScoreRow = ROW.instantiate()
		add_child(line)
		if row.kind == "team":
			line.show_team(row, TeamRules.COLORS[row.team])
			index = 0
			continue
		var color: Color = TeamRules.COLORS[row.team] if team_mode else player_color(row.id)
		line.show_player(row, color, row.id == my_id, index % 2 == 1)
		index += 1
	if results.is_empty():
		var empty := UiPalette.label("No match stats yet", UiPalette.S, UiPalette.TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(empty)

static func player_color(peer_id: int) -> Color:
	var value = GameManager.get_player(peer_id).get("color", Color.WHITE)
	var color: Color = value if value is Color else Color.WHITE
	color.a = 1.0
	return color
