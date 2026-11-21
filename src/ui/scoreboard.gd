extends CanvasLayer
## The scoreboard shown while Tab is held: every player's kills, deaths and
## damage (ScoreTable), with the game type and time left in the corner.

@onready var _table: ScoreTable = %Table
@onready var _info: Label = %Info

var _shown_key := 0 # rows are rebuilt only when the stats change

func _ready() -> void:
	layer = 80
	visible = false

func update_results(results: Array) -> void:
	if _table == null:
		return
	var remaining := int(GameManager.get_match_time_remaining())
	var mode := "Team deathmatch" if GameManager.is_team_mode() else "Deathmatch"
	_info.text = "%s  ·  %d:%02d left" % [mode, remaining / 60, remaining % 60]
	var key := hash([results, GameManager.is_team_mode()])
	if key != _shown_key:
		_shown_key = key
		_table.show_results(results, GameManager.is_team_mode(), multiplayer.get_unique_id())
