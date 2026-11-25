extends Control
class_name EventStripUI
## The strip under the match clock: the next in-game event ("Shady Fella  in
## 0:42", the bar filling up as it gets close) or the one running now ("2 cards
## left", or the time it has left with the bar draining). It pops when an event
## starts. Reads the map's EventDirector; sits at the top centre of the screen.

const WIDTH := 240.0
const BAR_HEIGHT := 4.0

var _panel: PanelContainer
var _icon: TextureRect
var _name: Label
var _status: Label
var _bar_back: ColorRect
var _bar: ColorRect
var _live := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.position = Vector2(-WIDTH * 0.5, 0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(22, 22)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	_name = UiPalette.label("", UiPalette.S, UiPalette.TEXT)
	_name.uppercase = true
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_status = UiPalette.label("", UiPalette.S, UiPalette.TEXT_DIM)
	row.add_child(_status)
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_holder)
	_bar_back = ColorRect.new()
	_bar_back.color = UiPalette.WELL
	_bar_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_holder.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = UiPalette.ACCENT
	_bar.size = Vector2(0, BAR_HEIGHT)
	bar_holder.add_child(_bar)
	visible = false
	EventManager.game_event_started.connect(_on_event_started)

func _director() -> EventDirector:
	# PlayerUI's owner: EventStrip -> PlayerUI -> PlayerCamera -> CameraComponent -> Player -> map.
	var player := get_parent().get_parent().get_parent().get_parent()
	var map := player.get_parent() if player else null
	return map.get_node_or_null("Events") as EventDirector if map else null

func _process(_delta: float) -> void:
	var director := _director()
	if director == null or not GameManager.is_state(GameManager.GameState.PLAYING):
		visible = false
		return
	var running: Array = director.active.filter(func(e): return is_instance_valid(e))
	var fraction := 0.0
	if not running.is_empty():
		var event: GameEvent = running[-1]
		_show(event.spec, true)
		var left := event.time_left()
		var text := event.status_text()
		if left >= 0.0:
			text = _clock(left) + " left" if text == "" else text
			fraction = clampf(left / event.spec.lasts_seconds, 0.0, 1.0) if event.spec.lasts_seconds > 0.0 else 1.0
		else:
			fraction = 1.0
		_status.text = text if text != "" else "now"
	elif director.next_index >= 0 and director.next_index < director.specs.size():
		_show(director.specs[director.next_index], false)
		var wait := maxf((director.next_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
		_status.text = "in " + _clock(wait)
		fraction = 1.0 - wait / director.next_wait if director.next_wait > 0.0 else 1.0
	else:
		visible = false
		return
	visible = true
	_bar.size.x = _bar_back.size.x * clampf(fraction, 0.0, 1.0)

func _show(spec: EventSpec, live: bool) -> void:
	_name.text = spec.display_name
	_icon.texture = spec.icon
	_icon.visible = spec.icon != null
	_live = live
	_name.add_theme_color_override("font_color", UiPalette.ACCENT if live else UiPalette.TEXT)
	_status.add_theme_color_override("font_color", UiPalette.TEXT if live else UiPalette.TEXT_DIM)

static func _clock(seconds: float) -> String:
	var whole := ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]

## A new event: the strip pops so nobody misses it.
func _on_event_started(_event: Node) -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(1.25, 1.25)
	_panel.modulate = Color(1.6, 1.6, 1.6)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.45)
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.6)
