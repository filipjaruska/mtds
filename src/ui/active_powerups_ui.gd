extends Control
class_name ActivePowerupsUI
## The cards in effect, down the left edge: one active_powerup_row.tscn per
## card, with a strip along the bottom for the time (or uses) left and, for the
## Riot Shield, a second strip for the shield's HP.

const ROW_SCENE := preload("res://src/ui/library/active_powerup_row.tscn")
const ROW_MIN_SIZE := Vector2(190, 38)
const ROW_ENTER_DURATION := 0.15
## Card thumbnail size; stacked cards show as a small pile behind it.
const THUMB_SIZE := Vector2(24, 34)
const BAR_LEFT := 40.0

## Riot Shield HP (0..1) while the shield is up, -1 otherwise. Set by PlayerUI.
var shield_fraction := -1.0

@onready var effects_container = $ScrollContainer/VBoxContainer

var active_effect_displays: Array[Control] = []
var _entries: Dictionary = {} # def id -> latest active entry

func _ready():
	effects_container.add_theme_constant_override("separation", 4)
	set_process(true)

func _process(_delta: float):
	_update_effect_timers()

## `active` is PowerupManager.active: entries from PowerupRules. Rows are keyed
## by powerup id and reused, so calling this every frame is cheap.
func update_active_powerups(active: Array):
	_entries.clear()
	for entry in active:
		_entries[entry.def] = entry
	
	var existing: Dictionary = {}
	for display in active_effect_displays:
		if is_instance_valid(display):
			existing[display.get_meta("powerup")] = display
	
	var kept: Array[Control] = []
	for def_id in _entries:
		if PowerupDefs.get_def(def_id) == null:
			continue
		if existing.has(def_id):
			_refresh_static_labels(existing[def_id], _entries[def_id])
			kept.append(existing[def_id])
			existing.erase(def_id)
		else:
			var display := _create_effect_display(_entries[def_id])
			effects_container.add_child(display)
			kept.append(display)
			_animate_row_in(display)
	for display in existing.values():
		display.queue_free()
	active_effect_displays = kept

func _create_effect_display(entry: Dictionary) -> Control:
	var row: Control = ROW_SCENE.instantiate()
	row.set_meta("powerup", entry.def)
	_refresh_static_labels(row, entry)
	_update_row_progress(row, entry)
	return row

func _refresh_static_labels(display: Control, entry: Dictionary) -> void:
	var card := PowerupDefs.get_def(entry.def)
	var name_label: Label = display.get_node("NameLabel")
	var uses_badge: Label = display.get_node("UsesBadge")
	var stack_suffix := " x%d" % entry.stacks if entry.stacks > 1 else ""
	name_label.text = card.get_display_name() + stack_suffix
	uses_badge.visible = entry.uses_left >= 0
	if uses_badge.visible:
		uses_badge.text = str(entry.uses_left)
	_build_thumb(display.get_node("Thumb"), card, entry.stacks)

## The card image with one copy behind it per extra stack (like the hand's piles).
func _build_thumb(thumb: Control, card: PowerupDef, stacks: int) -> void:
	if thumb.get_meta("stacks", -1) == stacks:
		return
	thumb.set_meta("stacks", stacks)
	for child in thumb.get_children():
		child.queue_free()
	var layers := HandLayout.pile_offsets(stacks)
	layers.reverse()
	for layer in layers:
		thumb.add_child(_thumb_rect(card, layer.offset * 0.45, layer.shade))
	thumb.add_child(_thumb_rect(card, Vector2.ZERO, 1.0))

func _thumb_rect(card: PowerupDef, offset: Vector2, shade: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = card.card_texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # before size, or it is clamped to the texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = THUMB_SIZE
	rect.position = offset
	rect.modulate = Color(shade, shade, shade)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _animate_row_in(display: Control) -> void:
	display.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(display, "modulate:a", 1.0, ROW_ENTER_DURATION)

func _update_effect_timers():
	for display in active_effect_displays:
		if is_instance_valid(display) and _entries.has(display.get_meta("powerup")):
			_update_row_progress(display, _entries[display.get_meta("powerup")])

func _update_row_progress(display: Control, entry: Dictionary) -> void:
	var bar_fill: ColorRect = display.get_node("BarFill")
	var percentage: float = PowerupRules.remaining_fraction(entry, Time.get_ticks_msec())
	var card := PowerupDefs.get_def(entry.def)
	var row_width: float = maxf(display.size.x, ROW_MIN_SIZE.x)
	var bar_left := BAR_LEFT
	var fill_width: float = maxf((row_width - bar_left) * percentage, 0.0)
	_update_shield_bar(display, card, row_width)

	# Time left: the strip along the bottom of the row (placed in the scene) shrinks.
	bar_fill.offset_right = bar_fill.offset_left + fill_width

	var uses_low: bool = entry.uses_left >= 0 and entry.uses_left <= 3
	if uses_low or percentage < 0.25:
		bar_fill.color = UiPalette.BAD
	elif percentage < 0.5:
		bar_fill.color = UiPalette.WARN
	else:
		bar_fill.color = card.rarity_color

## A thin bar under the Steel Skin row showing what is left of the shield.
func _update_shield_bar(display: Control, card: PowerupDef, row_width: float) -> void:
	var bar: ColorRect = display.get_node("ShieldBar")
	bar.visible = card.ability is RiotShieldAbility and shield_fraction >= 0.0
	if not bar.visible:
		return
	bar.position = Vector2(BAR_LEFT - 5.0, ROW_MIN_SIZE.y - 8.0)
	bar.size = Vector2((row_width - BAR_LEFT) * shield_fraction, 3.0)
	bar.color = UiPalette.INFO if shield_fraction > 0.3 else UiPalette.BAD
