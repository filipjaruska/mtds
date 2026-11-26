extends Control
class_name EventStripUI
## The strip under the match clock: a row for every in-game event running now
## ("2 cards left", or the time it has left with the bar draining) and one for
## the next to come ("Shady Fella  in 0:42", the bar filling up as it gets
## close). A row pops when its event starts. Reads the map's EventDirector;
## sits at the top centre of the screen.

const WIDTH := 240.0
const BAR_HEIGHT := 4.0
## Rows for running events at most (the next event always gets its own).
const MAX_RUNNING := 3

var _column: VBoxContainer
var _rows: Array = [] # {panel, icon, name, status, back, bar}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 4)
	_column.position = Vector2(-WIDTH * 0.5, 0)
	_column.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_column)
	for i in range(MAX_RUNNING + 1):
		_rows.append(_make_row())
	visible = false
	EventManager.game_event_started.connect(_on_event_started)

func _make_row() -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	_column.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var title := UiPalette.label("", UiPalette.S, UiPalette.TEXT)
	title.uppercase = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var status := UiPalette.label("", UiPalette.S, UiPalette.TEXT_DIM)
	row.add_child(status)
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_holder)
	var back := ColorRect.new()
	back.color = UiPalette.WELL
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_holder.add_child(back)
	var bar := ColorRect.new()
	bar.color = UiPalette.ACCENT
	bar.size = Vector2(0, BAR_HEIGHT)
	bar_holder.add_child(bar)
	panel.visible = false
	return {"panel": panel, "icon": icon, "name": title, "status": status, "back": back, "bar": bar, "event": null}

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
	running = running.slice(maxi(running.size() - MAX_RUNNING, 0))
	var used := 0
	for event in running:
		_show_running(_rows[used], event)
		used += 1
	if director.next_index >= 0 and director.next_index < director.specs.size():
		_show_next(_rows[used], director)
		used += 1
	for i in range(_rows.size()):
		_rows[i].panel.visible = i < used
		if i >= used:
			_rows[i].event = null
	visible = used > 0

func _show_running(row: Dictionary, event: GameEvent) -> void:
	_fill(row, event.spec, true)
	row.event = event
	var left := event.time_left()
	var text := event.status_text()
	var fraction := 1.0
	if left >= 0.0:
		text = _clock(left) + " left" if text == "" else text
		fraction = clampf(left / event.spec.lasts_seconds, 0.0, 1.0) if event.spec.lasts_seconds > 0.0 else 1.0
	row.status.text = text if text != "" else "now"
	row.bar.size.x = row.back.size.x * fraction

func _show_next(row: Dictionary, director: EventDirector) -> void:
	_fill(row, director.specs[director.next_index], false)
	row.event = null
	var wait := maxf((director.next_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	row.status.text = "in " + _clock(wait)
	var fraction := 1.0 - wait / director.next_wait if director.next_wait > 0.0 else 1.0
	row.bar.size.x = row.back.size.x * clampf(fraction, 0.0, 1.0)

func _fill(row: Dictionary, spec: EventSpec, live: bool) -> void:
	row.name.text = spec.display_name
	row.icon.texture = spec.icon
	row.icon.visible = spec.icon != null
	row.name.add_theme_color_override("font_color", UiPalette.ACCENT if live else UiPalette.TEXT)
	row.status.add_theme_color_override("font_color", UiPalette.TEXT if live else UiPalette.TEXT_DIM)

static func _clock(seconds: float) -> String:
	var whole := ceili(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]

## A new event: its row pops so nobody misses it.
func _on_event_started(event: Node) -> void:
	await get_tree().process_frame # its row is filled in on the next frame
	for row in _rows:
		if row.event == event:
			var panel: PanelContainer = row.panel
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(1.25, 1.25)
			panel.modulate = Color(1.6, 1.6, 1.6)
			var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(panel, "scale", Vector2.ONE, 0.45)
			tween.tween_property(panel, "modulate", Color.WHITE, 0.6)
