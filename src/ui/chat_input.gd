extends Control
class_name ChatInput
## The typing field for chat. There is no chat window: Enter opens a small
## field right where the speech bubble will appear above your player; Enter
## sends (ChatManager.send), Esc or an empty Enter closes. While it is open
## ChatManager.is_typing mutes gameplay input. Only the local player's copy
## does anything.

const FIELD_WIDTH := 210.0
const ABOVE_PLAYER := 96.0

## PlayerUI's owner: ChatInput -> PlayerUI -> PlayerCamera -> CameraComponent -> Player.
@onready var player: Node2D = get_node("../../../..")

var _field: LineEdit
var _open := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field = LineEdit.new()
	_field.max_length = ChatRules.MAX_LENGTH
	_field.placeholder_text = "Say something…"
	_field.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	_field.size = Vector2(FIELD_WIDTH, 30)
	_field.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	style.set_corner_radius_all(7)
	style.border_color = Color(1.0, 0.82, 0.3, 0.8)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	_field.add_theme_stylebox_override("normal", style)
	_field.add_theme_stylebox_override("focus", style)
	_field.visible = false
	_field.text_submitted.connect(_on_submitted)
	_field.focus_exited.connect(_close)
	_field.gui_input.connect(_on_field_input)
	add_child(_field)

func _exit_tree() -> void:
	if _open:
		ChatManager.set_typing(false)

func _input(event: InputEvent) -> void:
	if _open or not event.is_action_pressed("chat") or event.is_echo():
		return
	if not player.is_multiplayer_authority() or not GameManager.is_state(GameManager.GameState.PLAYING) or InputManager.menu_open:
		return
	_open = true
	_field.text = ""
	_field.visible = true
	_field.grab_focus()
	ChatManager.set_typing(true)
	# Don't let this same Enter press reach the field and submit it empty.
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _open:
		return
	if not GameManager.is_state(GameManager.GameState.PLAYING):
		_close()
		return
	var screen := player.get_global_transform_with_canvas().origin
	_field.position = screen + Vector2(-FIELD_WIDTH * 0.5, -ABOVE_PLAYER)

func _on_submitted(text: String) -> void:
	ChatManager.send(text)
	_close()

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		_field.accept_event()

func _close() -> void:
	if not _open:
		return
	_open = false
	_field.visible = false
	_field.release_focus()
	ChatManager.set_typing(false)

func is_open() -> bool:
	return _open
