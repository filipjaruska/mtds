extends CanvasLayer
class_name PauseMenu
## The in-match Esc menu. The match keeps running (it's multiplayer); the local
## player just stops taking gameplay input while it is open
## (InputManager.menu_open). Owned by the lobby, which runs the session.
##   Resume     back to the game
##   Options    the options screen on top (Esc there comes back here)
##   End match  host only: finish the round now, results for everyone
##   Leave      click twice; the host leaving ends the session for everyone
## The layout is pause_menu.tscn; this script only wires it up.

const OPTIONS_SCENE := "res://src/ui/menus/options.tscn"
const CONFIRM_SECONDS := 3.0

@onready var lobby: Node = get_parent()

@onready var _root: Control = %Root
@onready var _panel: PanelContainer = %Panel
@onready var _resume: Button = %Resume
@onready var _end_match: Button = %EndMatch
@onready var _leave: Button = %Leave
@onready var _note: Label = %Note

var _open := false
var _leave_armed_until := 0

func _ready() -> void:
	_resume.pressed.connect(_on_resume)
	%Options.pressed.connect(_on_options)
	_end_match.pressed.connect(_on_end_match)
	_leave.pressed.connect(_on_leave)
	_set_open(false)

func is_open() -> bool:
	return _open

func _exit_tree() -> void:
	InputManager.menu_open = false # never leave gameplay input muted

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu") or event.is_echo():
		return
	if not _in_match() or ChatManager.is_typing:
		return
	get_viewport().set_input_as_handled()
	if lobby.has_menu_overlay():
		_back_from_options() # Esc in Options: back to this menu
		return
	_set_open(not _open)

func _process(_delta: float) -> void:
	if _open and not _in_match():
		_set_open(false)
	if _open and not lobby.has_menu_overlay() and not _panel.visible:
		_panel.visible = true # Options was closed some other way
	if _leave_armed_until > 0 and Time.get_ticks_msec() > _leave_armed_until:
		_disarm_leave()

func _in_match() -> bool:
	return lobby.is_in_match() and GameManager.is_state(GameManager.GameState.PLAYING)

func _set_open(open: bool) -> void:
	_open = open
	_root.visible = open
	_panel.visible = open
	InputManager.menu_open = open
	_disarm_leave()
	if open:
		_end_match.visible = multiplayer.is_server() and not GameManager.tutorial_mode
		_note.text = "The tutorial keeps going" if GameManager.tutorial_mode else "The match keeps going"
		_leave.text = _leave_label()
		_resume.grab_focus()
	elif lobby.has_menu_overlay():
		lobby.close_menu_overlay()

func _on_resume() -> void:
	_set_open(false)

func _on_options() -> void:
	_panel.visible = false
	lobby.open_menu_overlay(OPTIONS_SCENE).show_in_match(_back_from_options)

func _back_from_options() -> void:
	lobby.close_menu_overlay()
	_panel.visible = true
	_resume.grab_focus()

func _on_end_match() -> void:
	_set_open(false)
	GameManager.finish_match_now()

func _on_leave() -> void:
	if _leave_armed_until == 0:
		_leave_armed_until = Time.get_ticks_msec() + int(CONFIRM_SECONDS * 1000.0)
		_leave.text = "Click again to leave"
		_leave.modulate = UiPalette.BAD.lightened(0.3)
		return
	_set_open(false)
	lobby.leave_session()

func _disarm_leave() -> void:
	_leave_armed_until = 0
	if _leave:
		_leave.modulate = Color.WHITE
		_leave.text = _leave_label()

func _leave_label() -> String:
	if GameManager.tutorial_mode:
		return "Leave tutorial"
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return "Leave game (ends it for everyone)"
	return "Leave game"
