extends Node
class_name PowerupManager

const MAX_INVENTORY_SLOTS = 4

var powerup_inventory: Array[BasePowerupCard] = []
var active_powerups: Array[ActivePowerup] = []
var player_node: Node

signal inventory_updated(inventory: Array[BasePowerupCard])
signal powerup_activated(powerup_card: BasePowerupCard, slot: int)
signal active_powerups_updated(active_powerups: Array[ActivePowerup])

func _init(player: Node = null):
	if player:
		player_node = player

func _ready():
	if not player_node:
		player_node = get_parent()
	powerup_inventory.resize(MAX_INVENTORY_SLOTS)
	set_process(true)

func _process(_delta):
	if player_node.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id():
		_check_powerup_inputs()

func _check_powerup_inputs():
	if Input.is_action_just_pressed("powerup_slot_1"):
		use_powerup_at_slot(0)
	elif Input.is_action_just_pressed("powerup_slot_2"):
		use_powerup_at_slot(1)
	elif Input.is_action_just_pressed("powerup_slot_3"):
		use_powerup_at_slot(2)
	elif Input.is_action_just_pressed("powerup_slot_4"):
		use_powerup_at_slot(3)

func collect_powerup(powerup_card: BasePowerupCard) -> bool:
	for i in range(MAX_INVENTORY_SLOTS):
		if powerup_inventory[i] == null:
			powerup_inventory[i] = powerup_card
			inventory_updated.emit(powerup_inventory)
			EventManager.emit_event(EventManager.Events.POWERUP_COLLECTED, [player_node, powerup_card, i])
			return true
	return false

func use_powerup_at_slot(slot_index: int):
	if slot_index < 0 or slot_index >= MAX_INVENTORY_SLOTS:
		return
	
	var powerup_card = powerup_inventory[slot_index]
	if powerup_card == null:
		return
	
	var existing_powerup = _get_active_powerup_of_type(powerup_card.type)
	
	if existing_powerup:
		existing_powerup.add_stack(1)
		powerup_activated.emit(powerup_card, slot_index)
	else:
		var active_powerup = ActivePowerup.new(powerup_card, player_node)
		active_powerup.powerup_expired.connect(_on_powerup_expired)
		active_powerups.append(active_powerup)
		add_child(active_powerup)
		powerup_activated.emit(powerup_card, slot_index)
	
	powerup_inventory[slot_index] = null
	inventory_updated.emit(powerup_inventory)
	active_powerups_updated.emit(active_powerups)
	EventManager.emit_event(EventManager.Events.POWERUP_USED, [player_node, powerup_card, slot_index])

func use_multiple_powerups(slot_indices: Array[int]):
	var cards_to_use: Array[BasePowerupCard] = []
	var valid_slots: Array[int] = []
	
	for slot_index in slot_indices:
		if slot_index >= 0 and slot_index < MAX_INVENTORY_SLOTS and powerup_inventory[slot_index] != null:
			cards_to_use.append(powerup_inventory[slot_index])
			valid_slots.append(slot_index)
	
	if cards_to_use.is_empty():
		return
	
	var card_groups: Dictionary = {}
	for i in range(cards_to_use.size()):
		var card = cards_to_use[i]
		var type = card.type
		if not card_groups.has(type):
			card_groups[type] = []
		card_groups[type].append({"card": card, "slot": valid_slots[i]})
	
	for type in card_groups.keys():
		var group = card_groups[type]
		var first_card = group[0]["card"]
		
		var existing_powerup = _get_active_powerup_of_type(type)
		if existing_powerup:
			existing_powerup.add_stack(group.size())
		else:
			var active_powerup = ActivePowerup.new(first_card, player_node, group.size())
			active_powerup.powerup_expired.connect(_on_powerup_expired)
			active_powerups.append(active_powerup)
			add_child(active_powerup)
		
		for card_info in group:
			powerup_inventory[card_info["slot"]] = null
			powerup_activated.emit(card_info["card"], card_info["slot"])
	
	inventory_updated.emit(powerup_inventory)
	active_powerups_updated.emit(active_powerups)

func _get_active_powerup_of_type(type: BasePowerupCard.PowerupType) -> ActivePowerup:
	for powerup in active_powerups:
		if powerup.powerup_card.type == type:
			return powerup
	return null

func _on_powerup_expired(expired_powerup: ActivePowerup):
	active_powerups.erase(expired_powerup)
	active_powerups_updated.emit(active_powerups)
	EventManager.emit_event(EventManager.Events.POWERUP_EXPIRED, [player_node, expired_powerup.powerup_card])

func get_inventory_slot_count() -> int:
	return MAX_INVENTORY_SLOTS

func get_used_inventory_slots() -> int:
	var count = 0
	for card in powerup_inventory:
		if card != null:
			count += 1
	return count

func has_powerup_of_type(type: BasePowerupCard.PowerupType) -> bool:
	return _get_active_powerup_of_type(type) != null

func get_powerup_effect_value(type: BasePowerupCard.PowerupType) -> float:
	var powerup = _get_active_powerup_of_type(type)
	return powerup.effect_value if powerup else 0.0

func clear_inventory():
	powerup_inventory.clear()
	powerup_inventory.resize(MAX_INVENTORY_SLOTS)
	inventory_updated.emit(powerup_inventory)

func clear_all_active_powerups():
	for powerup in active_powerups:
		powerup.remove_effect()
		powerup.queue_free()
	active_powerups.clear()
	active_powerups_updated.emit(active_powerups)
