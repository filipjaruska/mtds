extends PanelContainer
class_name ScoreRow
## One line of the score table (ScoreTable): the column header, a team summary
## or a player. The layout lives in score_row.tscn; this only fills it in.

@onready var _rank: Label = $Columns/Rank
@onready var _icon: TextureRect = $Columns/Icon
@onready var _name: Label = $Columns/Name
@onready var _tag: Label = $Columns/Tag
@onready var _kills: Label = $Columns/Kills
@onready var _deaths: Label = $Columns/Deaths
@onready var _damage: Label = $Columns/Damage

func show_header() -> void:
	theme_type_variation = &"ScoreHeader"
	custom_minimum_size.y = 0
	_set_texts("#", "Player", "Kills", "Deaths", "Damage")
	for label in [_rank, _name, _kills, _deaths, _damage]:
		label.theme_type_variation = &"CaptionLabel"
		label.uppercase = true
	_icon.self_modulate = Color(1, 1, 1, 0) # keeps the column width
	_tag.visible = false

## row: a "player" row from ResultsFormat.rows().
func show_player(row: Dictionary, color: Color, is_me: bool, alternate: bool) -> void:
	theme_type_variation = &"ScoreRowMe" if is_me else (&"ScoreRowAlt" if alternate else &"ScoreRow")
	_set_texts(str(row.rank), row.name, str(row.kills), str(row.deaths), str(row.damage))
	_rank.add_theme_color_override("font_color", UiPalette.ACCENT if row.rank == 1 else UiPalette.TEXT_DIM)
	_icon.modulate = color
	_tag.visible = is_me
	_tag.text = "YOU"

## row: a "team" row from ResultsFormat.rows().
func show_team(row: Dictionary, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.SURFACE_HOVER
	box.border_width_left = 4
	box.border_color = color
	box.content_margin_left = 10
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", box)
	_set_texts("", "%s team" % TeamRules.NAMES[row.team], str(row.kills), str(row.deaths), str(row.damage))
	_name.uppercase = true
	_name.add_theme_color_override("font_color", color.lightened(0.25))
	_icon.self_modulate = Color(1, 1, 1, 0)
	_tag.visible = row.winning
	_tag.text = "WINNING"

func _set_texts(rank: String, player_name: String, kills: String, deaths: String, damage: String) -> void:
	_rank.text = rank
	_name.text = player_name
	_kills.text = kills
	_deaths.text = deaths
	_damage.text = damage
