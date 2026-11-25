extends CanvasLayer
## Shady Fella's offer on the choosing player's screen: his cards side by side
## above the hand. Pick one with its card key (1, 2, 3...) or a click. The
## player can still move; walking away, getting hurt, Esc or taking too long
## closes it. While it is open the trigger and card keys belong to it.

signal picked(index: int)
signal closed

const RULES: GameRules = preload("res://src/game_rules.tres")

var offer: Array[StringName] = []

var _row: HBoxContainer
var _timer_bar: ColorRect
var _timer_back: ColorRect
var _opened_msec := 0
var _done := false
var _last_health := -1

func _ready() -> void:
	layer = 60
	InputManager.choosing_card = true
	_opened_msec = Time.get_ticks_msec()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var panel := PanelContainer.new()
	panel.theme = load("res://src/ui/theme/main_theme.tres")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -250
	holder.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := UiPalette.label("Shady Fella", UiPalette.L, UiPalette.ACCENT)
	title.uppercase = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var line := UiPalette.label("Pick one. Quick, before someone sees.", UiPalette.S, UiPalette.TEXT_DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	column.add_child(_row)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 4)
	column.add_child(bar)
	_timer_back = ColorRect.new()
	_timer_back.color = UiPalette.WELL
	_timer_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(_timer_back)
	_timer_bar = ColorRect.new()
	_timer_bar.color = UiPalette.ACCENT
	_timer_bar.size = Vector2(0, 4)
	bar.add_child(_timer_bar)
	show_offer(offer)
	EventManager.health_changed.connect(_on_health_changed)

## (Re)build the cards; the host sends the offer again when it changes.
func show_offer(cards: Array[StringName]) -> void:
	offer = cards
	for child in _row.get_children():
		child.queue_free()
	for i in range(offer.size()):
		var def := PowerupDefs.get_def(offer[i])
		if def == null:
			continue
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		_row.add_child(slot)
		var card_box := Control.new()
		card_box.custom_minimum_size = HandLayout.CARD_SIZE
		card_box.mouse_filter = Control.MOUSE_FILTER_STOP
		card_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_box.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				choose(i))
		slot.add_child(card_box)
		var view := CardView.create()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(view)
		view.set_card(def, 1)
		view.set_hotkey(GameSettings.get_action_binding_text("powerup_slot_%d" % (i + 1)))
		var about := UiPalette.label(def.get_type_description(), UiPalette.XS, UiPalette.TEXT_DIM)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(HandLayout.CARD_SIZE.x + 40, 0)
		slot.add_child(about)

func _process(_delta: float) -> void:
	var elapsed := (Time.get_ticks_msec() - _opened_msec) / 1000.0
	_timer_bar.size.x = _timer_back.size.x * clampf(1.0 - elapsed / RULES.shady_choose_seconds, 0.0, 1.0)
	if elapsed > RULES.shady_choose_seconds:
		close()
		return
	for i in range(mini(offer.size(), 4)):
		if Input.is_action_just_pressed("powerup_slot_%d" % (i + 1)):
			choose(i)

func choose(index: int) -> void:
	if not _done:
		_done = true
		picked.emit(index)

## Closes it and tells the host (unless the host closed it).
func close() -> void:
	if not is_queued_for_deletion():
		closed.emit()
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## Getting hurt closes the offer.
func _on_health_changed(player: Node, health: int, _max_health: int) -> void:
	if not player.is_multiplayer_authority():
		return
	if _last_health >= 0 and health < _last_health:
		close()
	_last_health = health

func _exit_tree() -> void:
	InputManager.choosing_card = false
