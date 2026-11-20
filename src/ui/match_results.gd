extends CanvasLayer

signal continue_pressed

const AUTO_CONTINUE_SECONDS: float = 12.0

@onready var results_list: ItemList = $MarginContainer/VBoxContainer/ResultsList
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel

var _time_remaining: float = AUTO_CONTINUE_SECONDS
var _continued: bool = false

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func setup(results: Array) -> void:
	ResultsFormat.fill(results_list, results, GameManager.is_team_mode())

	_time_remaining = AUTO_CONTINUE_SECONDS
	_continued = false
	_update_timer_label()
	set_process(true)

func _process(delta: float) -> void:
	_time_remaining = maxf(0.0, _time_remaining - delta)
	_update_timer_label()
	if _time_remaining <= 0.0:
		_on_continue_pressed()

func _update_timer_label() -> void:
	timer_label.text = "Returning to lobby in %d..." % [int(ceil(_time_remaining))]

func _on_continue_pressed() -> void:
	if _continued:
		return
	_continued = true
	set_process(false)
	continue_pressed.emit()
