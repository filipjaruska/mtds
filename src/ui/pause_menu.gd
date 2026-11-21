extends CanvasLayer
class_name PauseMenu
## The in-match Esc menu. The match keeps running (it's multiplayer); the local
## player just stops taking gameplay input while it is open
## (InputManager.menu_open). Owned by the lobby, which runs the session.
##   Resume     back to the game
##   Options    the options screen on top (Esc there comes back here)
##   End match  host only: finish the round now, results for everyone
##   Leave      click twice; the host leaving ends the session for everyone

const OPTIONS_SCENE := "res://src/ui/menus/options.tscn"
const CONFIRM_SECONDS := 3.0

@onready var lobby: Node = get_parent()

var _open := false
var _root: Control
var _panel: PanelContainer
var _resume: Button
var _end_match: Button
var _leave: Button
var _leave_armed_until := 0
var _note: Label

func _ready() -> void:
	layer = 90
	_build()
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
		# Esc in Options: back to this menu.
		lobby.close_menu_overlay()
		_panel.visible = true
		_resume.grab_focus()
		return
	_set_open(not _open)

func _process(_delta: float) -> void:
	if _open and not _in_match():
		_set_open(false)
	if _open and not lobby.has_menu_overlay() and not _panel.visible:
		_panel.visible = true # Options closed through its own tab bar
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
	lobby.open_menu_overlay(OPTIONS_SCENE)

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

# --- Building ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # clicks don't reach the game
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = UiPalette.BACKDROP # the one dimmed layer in the UI
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	var style := UiPalette.panel(&"panel", 28)
	style.border_color = UiPalette.BORDER_STRONG
	style.border_width_top = 3
	style.border_color = UiPalette.ACCENT
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(320, 0)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"TitleLabel"
	title.uppercase = true
	column.add_child(title)
	var note := Label.new()
	_note = note
	note.text = "The match keeps going"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.theme_type_variation = &"MutedLabel"
	column.add_child(note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)

	_resume = _button(column, "Resume", _on_resume)
	_resume.theme_type_variation = &"AccentButton"
	_button(column, "Options", _on_options)
	_end_match = _button(column, "End match (show results)", _on_end_match)
	_leave = _button(column, "Leave game", _on_leave)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
