extends Control
class_name PowerupInventoryUI

const COMPACT_TOP := -130.0
const COMPACT_BOTTOM := -24.0
const EXPANDED_TOP := -220.0
const EXPANDED_BOTTOM := -24.0
const SLOT_EXPANDED_MIN_SIZE := Vector2(96, 188)

const GAMEPAD_HOTKEYS := ["←", "↑", "→", "↓"]

@onready var hbox_container = $HBoxContainer
@onready var slot_1 = $HBoxContainer/PowerupSlot1
@onready var slot_2 = $HBoxContainer/PowerupSlot2
@onready var slot_3 = $HBoxContainer/PowerupSlot3
@onready var slot_4 = $HBoxContainer/PowerupSlot4

var inventory_slots: Array[Control] = []
var current_inventory: Array[BasePowerupCard] = []
var _expanded := false

func _ready():
	inventory_slots = [slot_1, slot_2, slot_3, slot_4]
	for slot in inventory_slots:
		_create_detail_overlay(slot)
	hbox_container.add_theme_constant_override("separation", 8)
	set_process(true)
	_update_display([])

func _process(_delta: float) -> void:
	_set_expanded(InputManager.is_powerup_details_held())

func _set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	if _expanded:
		offset_top = EXPANDED_TOP
		offset_bottom = EXPANDED_BOTTOM
	else:
		offset_top = COMPACT_TOP
		offset_bottom = COMPACT_BOTTOM
	hbox_container.add_theme_constant_override("separation", 14 if _expanded else 8)
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		slot.custom_minimum_size = SLOT_EXPANDED_MIN_SIZE if _expanded else Vector2.ZERO
		var card = current_inventory[i] if i < current_inventory.size() else null
		_update_slot_overlay(slot, card)
		var label: Label = slot.get_node("Label")
		label.visible = not _expanded and card != null

func update_inventory(inventory: Array[BasePowerupCard]):
	current_inventory = inventory
	_update_display(inventory)

func _update_display(inventory: Array[BasePowerupCard]):
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var card = inventory[i] if i < inventory.size() else null
		_update_slot(slot, card, i + 1)

func _create_detail_overlay(slot: Control) -> void:
	var overlay := Control.new()
	overlay.name = "DetailOverlay"
	overlay.visible = false
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.04, 0.06, 0.88)
	overlay.add_child(dim)

	var content := VBoxContainer.new()
	content.name = "OverlayContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 6)
	content.offset_left = 8.0
	content.offset_top = 8.0
	content.offset_right = -8.0
	content.offset_bottom = -8.0
	overlay.add_child(content)

	var name_label := Label.new()
	name_label.name = "OverlayName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	content.add_child(name_label)

	var description_label := Label.new()
	description_label.name = "OverlayDescription"
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.modulate = Color(0.88, 0.88, 0.88)
	content.add_child(description_label)

func _update_slot(slot: Control, card: BasePowerupCard, slot_number: int):
	var icon = slot.get_node("Icon")
	var label = slot.get_node("Label")
	var hotkey = slot.get_node("Hotkey")
	var background = slot.get_node("Background")
	
	hotkey.text = _get_hotkey_label(slot_number)
	
	if card:
		icon.visible = true
		label.visible = not _expanded
		background.color = card.rarity_color
		
		if card.icon_texture:
			icon.texture = card.icon_texture
		else:
			icon.texture = _get_default_icon_for_type(card.type)
		
		label.text = card.get_display_name()
		
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(background, "modulate:a", 0.7, 1.0)
		tween.tween_property(background, "modulate:a", 1.0, 1.0)
	else:
		icon.visible = false
		label.visible = false
		background.color = Color(0.2, 0.2, 0.2, 0.5)
		background.modulate = Color.WHITE
	
	_update_slot_overlay(slot, card)

func _get_hotkey_label(slot_number: int) -> String:
	if InputManager.current_device == InputManager.InputDevice.GAMEPAD:
		return GAMEPAD_HOTKEYS[slot_number - 1]
	return str(slot_number)

func _update_slot_overlay(slot: Control, card: BasePowerupCard) -> void:
	var overlay: Control = slot.get_node_or_null("DetailOverlay")
	if not overlay:
		return
	
	overlay.visible = _expanded and card != null
	if not overlay.visible or card == null:
		return
	
	var name_label: Label = overlay.get_node("OverlayContent/OverlayName")
	var description_label: Label = overlay.get_node("OverlayContent/OverlayDescription")
	name_label.text = card.get_display_name()
	name_label.modulate = card.rarity_color.lightened(0.35)
	description_label.text = card.get_type_description()

func _get_default_icon_for_type(_type: BasePowerupCard.PowerupType) -> Texture2D:
	return null

func highlight_slot(slot_index: int, duration: float = 0.5):
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return
	
	var slot = inventory_slots[slot_index]
	var background = slot.get_node("Background")
	
	var original_color = background.color
	var tween = create_tween()
	tween.tween_property(background, "color", Color.YELLOW, 0.1)
	tween.tween_property(background, "color", original_color, duration)
