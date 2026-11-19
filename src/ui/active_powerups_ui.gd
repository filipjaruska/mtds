extends Control
class_name ActivePowerupsUI

const ROW_MIN_SIZE := Vector2(180, 26)
const ROW_ENTER_DURATION := 0.15

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
	var row := Control.new()
	row.custom_minimum_size = ROW_MIN_SIZE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBg"
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_bg.offset_left = 28.0
	bar_bg.color = Color(1, 1, 1, 0.06)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_fill)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(2, 3)
	icon.size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 32.0
	name_label.offset_right = -22.0
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94, 0.9))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var uses_badge := Label.new()
	uses_badge.name = "UsesBadge"
	uses_badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	uses_badge.anchor_left = 1.0
	uses_badge.anchor_right = 1.0
	uses_badge.offset_left = -20.0
	uses_badge.offset_right = -2.0
	uses_badge.offset_top = -8.0
	uses_badge.offset_bottom = 8.0
	uses_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	uses_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	uses_badge.add_theme_font_size_override("font_size", 11)
	uses_badge.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88, 0.8))
	uses_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uses_badge.visible = false
	row.add_child(uses_badge)

	var card := PowerupDefs.get_def(entry.def)
	if card.icon_texture:
		icon.texture = card.icon_texture
	icon.modulate = Color(card.rarity_color.r, card.rarity_color.g, card.rarity_color.b, 0.9)

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
	var bar_left := 28.0
	var fill_width: float = maxf((row_width - bar_left) * percentage, 0.0)

	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = 0.0
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.offset_left = bar_left
	bar_fill.offset_right = bar_left + fill_width
	bar_fill.offset_top = 0.0
	bar_fill.offset_bottom = 0.0

	var uses_low: bool = entry.uses_left >= 0 and entry.uses_left <= 3
	if uses_low or percentage < 0.25:
		bar_fill.color = Color(0.85, 0.3, 0.28, 0.35)
	elif percentage < 0.5:
		bar_fill.color = Color(0.9, 0.6, 0.25, 0.3)
	else:
		bar_fill.color = Color(card.rarity_color.r, card.rarity_color.g, card.rarity_color.b, 0.28)
