extends Control
class_name PowerupInventoryUI

const COMPACT_TOP := -130.0
const COMPACT_BOTTOM := -24.0
const EXPANDED_TOP := -220.0
const EXPANDED_BOTTOM := -24.0
const SLOT_EXPANDED_MIN_SIZE := Vector2(84, 176)
const DETAILS_TWEEN_DURATION := 0.22
const SHUFFLE_PULSE_DURATION := 0.6

const EMPTY_COLOR := Color(1, 1, 1, 0.05)
const GAMEPAD_HOTKEYS := ["←", "↑", "→", "↓"]

@onready var hbox_container = $HBoxContainer
@onready var slot_1 = $HBoxContainer/PowerupSlot1
@onready var slot_2 = $HBoxContainer/PowerupSlot2
@onready var slot_3 = $HBoxContainer/PowerupSlot3
@onready var slot_4 = $HBoxContainer/PowerupSlot4
@onready var mode_hint: Label = $ModeHint

var inventory_slots: Array[Control] = []
var current_inventory: Array[Dictionary] = []
var _expanded := false
var _shuffle_mode_active := false
var _expand_tween: Tween = null
var _slot_idle_tweens: Dictionary = {}
var _shuffle_pulse_tween: Tween = null

func _ready():
	inventory_slots = [slot_1, slot_2, slot_3, slot_4]
	for slot in inventory_slots:
		_create_detail_overlay(slot)
	hbox_container.add_theme_constant_override("separation", 8)
	if mode_hint:
		mode_hint.visible = false
	set_process(true)
	_update_display([])

func _process(_delta: float) -> void:
	_set_expanded(InputManager.is_powerup_details_held())
	var want_shuffle := GameManager.is_shuffle_mode() and InputManager.is_powerup_shuffle_held()
	_set_shuffle_mode(want_shuffle)
	_update_mode_hint()

func _update_mode_hint() -> void:
	if mode_hint == null:
		return
	if _expanded:
		mode_hint.visible = true
		mode_hint.text = "Details"
	elif _shuffle_mode_active:
		mode_hint.visible = true
		mode_hint.text = "Merge"
	else:
		mode_hint.visible = false

func _set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	_tween_expand_state()

func _set_shuffle_mode(active: bool) -> void:
	if _shuffle_mode_active == active:
		return
	_shuffle_mode_active = active
	if _shuffle_mode_active and not _expanded:
		_start_shuffle_pulse()
	else:
		_stop_shuffle_pulse()
	_refresh_slot_visuals()

func _tween_expand_state() -> void:
	if _expand_tween and _expand_tween.is_valid():
		_expand_tween.kill()

	var target_top := EXPANDED_TOP if _expanded else COMPACT_TOP
	var target_bottom := EXPANDED_BOTTOM if _expanded else COMPACT_BOTTOM
	var target_sep := 12 if _expanded else 8
	var target_slot_size := SLOT_EXPANDED_MIN_SIZE if _expanded else Vector2.ZERO

	_expand_tween = create_tween()
	_expand_tween.set_parallel(true)
	_expand_tween.set_ease(Tween.EASE_OUT)
	_expand_tween.set_trans(Tween.TRANS_CUBIC)
	_expand_tween.tween_property(self, "offset_top", target_top, DETAILS_TWEEN_DURATION)
	_expand_tween.tween_property(self, "offset_bottom", target_bottom, DETAILS_TWEEN_DURATION)
	_expand_tween.tween_method(_set_separation, float(hbox_container.get_theme_constant("separation")), float(target_sep), DETAILS_TWEEN_DURATION)

	for i in range(inventory_slots.size()):
		var slot: Control = inventory_slots[i]
		_expand_tween.tween_property(slot, "custom_minimum_size", target_slot_size, DETAILS_TWEEN_DURATION)

		var slot_data := current_inventory[i] if i < current_inventory.size() else {}
		var card: BasePowerupCard = slot_data.get("card", null)
		var overlay: Control = slot.get_node_or_null("DetailOverlay")
		var label: Label = slot.get_node("Label")

		if _expanded and card != null and overlay:
			overlay.visible = true
			overlay.modulate.a = 0.0
			_expand_tween.tween_property(overlay, "modulate:a", 1.0, DETAILS_TWEEN_DURATION)
			_update_slot_overlay(slot, card)
		elif overlay:
			_expand_tween.tween_property(overlay, "modulate:a", 0.0, DETAILS_TWEEN_DURATION * 0.7)

		label.visible = not _expanded and card != null
		if label.visible:
			label.modulate.a = 0.0
			_expand_tween.tween_property(label, "modulate:a", 1.0, DETAILS_TWEEN_DURATION)

	if _expanded:
		_stop_shuffle_pulse()
	elif _shuffle_mode_active:
		_start_shuffle_pulse()

	_expand_tween.chain().tween_callback(_on_expand_tween_finished)

func _on_expand_tween_finished() -> void:
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var overlay: Control = slot.get_node_or_null("DetailOverlay")
		var slot_data := current_inventory[i] if i < current_inventory.size() else {}
		var card: BasePowerupCard = slot_data.get("card", null)
		if overlay and not _expanded:
			overlay.visible = false
		var label: Label = slot.get_node("Label")
		label.visible = not _expanded and card != null
		label.modulate.a = 1.0

func _set_separation(value: float) -> void:
	hbox_container.add_theme_constant_override("separation", int(round(value)))

func _start_shuffle_pulse() -> void:
	_stop_shuffle_pulse()
	for slot in inventory_slots:
		_kill_idle_pulse(slot)
	_shuffle_pulse_tween = create_tween()
	_shuffle_pulse_tween.set_loops()
	_shuffle_pulse_tween.tween_method(_apply_shuffle_pulse, 0.0, 1.0, SHUFFLE_PULSE_DURATION)
	_shuffle_pulse_tween.tween_method(_apply_shuffle_pulse, 1.0, 0.0, SHUFFLE_PULSE_DURATION)

func _apply_shuffle_pulse(t: float) -> void:
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var background: ColorRect = slot.get_node("Background")
		var selected := _is_slot_selected(slot)
		var base := Color(1.0, 0.92, 0.55, 1.0) if selected else Color(1.0, 1.0, 1.0, 1.0)
		var peak := Color(1.15, 1.05, 0.7, 1.0)
		background.modulate = base.lerp(peak, t)

func _stop_shuffle_pulse() -> void:
	if _shuffle_pulse_tween and _shuffle_pulse_tween.is_valid():
		_shuffle_pulse_tween.kill()
		_shuffle_pulse_tween = null
	_refresh_slot_visuals()
	if not _shuffle_mode_active:
		for i in range(inventory_slots.size()):
			var slot = inventory_slots[i]
			var slot_data := current_inventory[i] if i < current_inventory.size() else {}
			if slot_data.get("card", null):
				_ensure_idle_pulse(slot)

func _is_slot_selected(slot: Control) -> bool:
	var idx := inventory_slots.find(slot)
	if idx < 0 or idx >= current_inventory.size():
		return false
	return current_inventory[idx].get("selected", false)

func _refresh_slot_visuals() -> void:
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var slot_data := current_inventory[i] if i < current_inventory.size() else {}
		var selected: bool = slot_data.get("selected", false)
		var background: ColorRect = slot.get_node("Background")
		if selected:
			background.modulate = Color(1.0, 0.92, 0.55, 1.0)
		elif _shuffle_mode_active and not _expanded:
			background.modulate = Color(1.05, 1.02, 0.9, 1.0)
		else:
			background.modulate = Color.WHITE

func update_inventory(inventory: Array[Dictionary]):
	if _inventories_equal(current_inventory, inventory):
		return
	current_inventory = inventory.duplicate(true)
	_update_display(current_inventory)

func _inventories_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var aa: Dictionary = a[i]
		var bb: Dictionary = b[i]
		if aa.get("card") != bb.get("card"):
			return false
		if aa.get("count", 0) != bb.get("count", 0):
			return false
		if aa.get("selected", false) != bb.get("selected", false):
			return false
	return true

func _update_display(inventory: Array[Dictionary]):
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var slot_data := inventory[i] if i < inventory.size() else {}
		var card: BasePowerupCard = slot_data.get("card", null)
		var stack_count: int = slot_data.get("count", 0)
		var selected: bool = slot_data.get("selected", false)
		_update_slot(slot, card, stack_count, i + 1, selected)

func _create_detail_overlay(slot: Control) -> void:
	var overlay := Control.new()
	overlay.name = "DetailOverlay"
	overlay.visible = false
	overlay.modulate.a = 0.0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.05, 0.07, 0.9)
	overlay.add_child(dim)

	var content := VBoxContainer.new()
	content.name = "OverlayContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 4)
	content.offset_left = 6.0
	content.offset_top = 6.0
	content.offset_right = -6.0
	content.offset_bottom = -6.0
	overlay.add_child(content)

	var name_label := Label.new()
	name_label.name = "OverlayName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.name = "OverlayDescription"
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 10)
	description_label.modulate = Color(0.85, 0.85, 0.85)
	content.add_child(description_label)

func _update_slot(slot: Control, card: BasePowerupCard, stack_count: int, slot_number: int, selected: bool):
	var icon = slot.get_node("Icon")
	var label = slot.get_node("Label")
	var hotkey = slot.get_node("Hotkey")
	var background: ColorRect = slot.get_node("Background")

	hotkey.text = _get_hotkey_label(slot_number)

	if card:
		icon.visible = true
		label.visible = not _expanded
		var rarity := card.rarity_color
		background.color = Color(rarity.r, rarity.g, rarity.b, 0.45)
		if selected:
			background.modulate = Color(1.0, 0.92, 0.55, 1.0)
		elif _shuffle_mode_active and not _expanded:
			background.modulate = Color(1.05, 1.02, 0.9, 1.0)
		else:
			background.modulate = Color.WHITE

		if card.icon_texture:
			icon.texture = card.icon_texture
		else:
			icon.texture = null

		label.text = card.get_display_name()
		if stack_count > 1:
			label.text += " x%d" % stack_count

		if not _shuffle_mode_active:
			_ensure_idle_pulse(slot)
		else:
			_kill_idle_pulse(slot)
	else:
		_kill_idle_pulse(slot)
		icon.visible = false
		label.visible = false
		background.color = EMPTY_COLOR
		background.modulate = Color.WHITE

	_update_slot_overlay(slot, card)

func _ensure_idle_pulse(slot: Control) -> void:
	if _slot_idle_tweens.has(slot):
		var existing: Tween = _slot_idle_tweens[slot]
		if existing and existing.is_valid():
			return
	var background: ColorRect = slot.get_node("Background")
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(background, "modulate:a", 0.75, 1.2)
	tween.tween_property(background, "modulate:a", 1.0, 1.2)
	_slot_idle_tweens[slot] = tween

func _kill_idle_pulse(slot: Control) -> void:
	if not _slot_idle_tweens.has(slot):
		return
	var tween: Tween = _slot_idle_tweens[slot]
	if tween and tween.is_valid():
		tween.kill()
	_slot_idle_tweens.erase(slot)

func _get_hotkey_label(slot_number: int) -> String:
	if InputManager.current_device == InputManager.InputDevice.GAMEPAD:
		return GAMEPAD_HOTKEYS[slot_number - 1]
	return str(slot_number)

func _update_slot_overlay(slot: Control, card: BasePowerupCard) -> void:
	var overlay: Control = slot.get_node_or_null("DetailOverlay")
	if not overlay:
		return
	if not _expanded or card == null:
		if not _expanded:
			overlay.visible = false
		return
	overlay.visible = true
	var name_label: Label = overlay.get_node("OverlayContent/OverlayName")
	var description_label: Label = overlay.get_node("OverlayContent/OverlayDescription")
	name_label.text = card.get_display_name()
	name_label.modulate = card.rarity_color.lightened(0.35)
	description_label.text = card.get_type_description()

func highlight_slot(slot_index: int, duration: float = 0.4):
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return
	var slot = inventory_slots[slot_index]
	var background: ColorRect = slot.get_node("Background")
	var original := background.modulate
	var tween := create_tween()
	tween.tween_property(background, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.08)
	tween.tween_property(background, "modulate", original, duration)
