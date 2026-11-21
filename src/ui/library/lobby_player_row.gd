extends PanelContainer
class_name LobbyPlayerRow
## One player in the lobby list: their sprite in their colour, name, team tag
## (team matches), HOST tag and whether they are ready. Your own row is marked
## like on the scoreboard. Layout in lobby_player_row.tscn.

@onready var _icon: TextureRect = $Columns/Icon
@onready var _name: Label = $Columns/Name
@onready var _team: Label = $Columns/Team
@onready var _host: Label = $Columns/Host
@onready var _ready_tag: Label = $Columns/Ready

## team: the team index in team matches, -1 otherwise.
func show_player(player_name: String, color: Color, team: int, is_host: bool, is_ready: bool, is_me: bool) -> void:
	theme_type_variation = &"ScoreRowMe" if is_me else &"ScoreRow"
	_icon.modulate = color
	_name.text = player_name + ("  (you)" if is_me else "")
	_team.visible = team >= 0
	if team >= 0:
		_team.text = TeamRules.NAMES[team].to_upper()
		_team.add_theme_color_override("font_color", TeamRules.COLORS[team].lightened(0.3))
	_host.visible = is_host
	_ready_tag.text = "READY" if is_ready else "NOT READY"
	_ready_tag.theme_type_variation = &"SlotTagActive" if is_ready else &"SlotTag"
