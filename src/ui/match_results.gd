extends CanvasLayer
## The end-of-match screen: who won (from your point of view), the top three on
## a podium, the full score table, and a countdown back to the lobby.

signal continue_pressed

const AUTO_CONTINUE_SECONDS: float = 12.0
const PODIUM_CARD := preload("res://src/ui/library/podium_card.tscn")

@onready var continue_button: Button = %ContinueButton
@onready var timer_label: Label = %TimerLabel
@onready var _auto_bar: ProgressBar = %AutoBar
@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _podium: HBoxContainer = %Podium
@onready var _table: ScoreTable = %Table

var _time_remaining: float = AUTO_CONTINUE_SECONDS
var _continued: bool = false

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func setup(results: Array) -> void:
	var team_mode := GameManager.is_team_mode()
	var my_id := multiplayer.get_unique_id()
	var head := ResultsFormat.headline(results, team_mode, my_id)
	_eyebrow.text = "Match over  ·  %s" % ("Team deathmatch" if team_mode else "Deathmatch")
	_title.text = head.title
	_title.add_theme_color_override("font_color", UiPalette.ACCENT if head.outcome == "win" else UiPalette.TEXT)
	_subtitle.text = head.subtitle
	_fill_podium(results, team_mode, my_id)
	_table.show_results(results, team_mode, my_id)

	_time_remaining = AUTO_CONTINUE_SECONDS
	_continued = false
	_update_timer_label()
	set_process(true)

## Top three by damage, laid out 2nd, 1st, 3rd.
func _fill_podium(results: Array, team_mode: bool, my_id: int) -> void:
	for child in _podium.get_children():
		child.queue_free()
	var top := ResultsFormat.rows(results, false).slice(0, 3)
	for place in [2, 1, 3]:
		if place > top.size():
			continue
		var row: Dictionary = top[place - 1]
		var card: PodiumCard = PODIUM_CARD.instantiate()
		_podium.add_child(card)
		var color: Color = TeamRules.COLORS[row.team] if team_mode else ScoreTable.player_color(row.id)
		card.show_player(row, place, color, row.id == my_id)

func _process(delta: float) -> void:
	_time_remaining = maxf(0.0, _time_remaining - delta)
	_update_timer_label()
	if _time_remaining <= 0.0:
		_on_continue_pressed()

func _update_timer_label() -> void:
	timer_label.text = "Back to the lobby in %d" % [int(ceil(_time_remaining))]
	_auto_bar.value = _time_remaining / AUTO_CONTINUE_SECONDS

func _on_continue_pressed() -> void:
	if _continued:
		return
	_continued = true
	set_process(false)
	continue_pressed.emit()
