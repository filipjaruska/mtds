extends Control
class_name PowerupInventoryUI

@onready var slot_1 = $HBoxContainer/PowerupSlot1
@onready var slot_2 = $HBoxContainer/PowerupSlot2
@onready var slot_3 = $HBoxContainer/PowerupSlot3
@onready var slot_4 = $HBoxContainer/PowerupSlot4

var inventory_slots: Array[Control] = []
var current_inventory: Array[BasePowerupCard] = []

func _ready():
	inventory_slots = [slot_1, slot_2, slot_3, slot_4]
	_update_display([])

func update_inventory(inventory: Array[BasePowerupCard]):
	current_inventory = inventory
	_update_display(inventory)

func _update_display(inventory: Array[BasePowerupCard]):
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var card = inventory[i] if i < inventory.size() else null
		_update_slot(slot, card, i + 1)

func _update_slot(slot: Control, card: BasePowerupCard, slot_number: int):
	var icon = slot.get_node("Icon")
	var label = slot.get_node("Label")
	var hotkey = slot.get_node("Hotkey")
	var background = slot.get_node("Background")
	
	hotkey.text = str(slot_number)
	
	if card:
		icon.visible = true
		label.visible = true
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
