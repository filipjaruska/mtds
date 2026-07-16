extends Node
class_name PowerupManager

const MAX_INVENTORY_SLOTS = 4

var powerup_inventory: Array[BasePowerupCard] = []
var powerup_inventory_stack_counts: Array[int] = []
var active_powerups: Array[ActivePowerup] = []
var player_node: Node
var _shuffle_selected_slot: int = -1

signal inventory_updated(inventory: Array)
signal powerup_activated(powerup_card: BasePowerupCard, slot: int)
signal active_powerups_updated(active_powerups: Array[ActivePowerup])

func _init(player: Node = null):
	if player:
		player_node = player

func _ready():
	if not player_node:
		player_node = get_parent()
	powerup_inventory.resize(MAX_INVENTORY_SLOTS)
	powerup_inventory_stack_counts.resize(MAX_INVENTORY_SLOTS)
	set_process(true)
	EventManager.register(EventManager.Events.WEAPON_FIRED, _on_weapon_fired)

func _exit_tree() -> void:
	EventManager.unregister(EventManager.Events.WEAPON_FIRED, _on_weapon_fired)

func _process(_delta):
	if player_node.get_node("MultiplayerSynchronizer").get_multiplayer_authority() == multiplayer.get_unique_id():
		_check_powerup_inputs()

func _check_powerup_inputs():
	var slot_index: int = InputManager.get_powerup_slot_use_index()
	if slot_index < 0:
		if not InputManager.is_powerup_details_held():
			_shuffle_selected_slot = -1
		return
	
	if GameManager.is_shuffle_mode() and InputManager.is_powerup_details_held():
		_handle_shuffle_slot_pressed(slot_index)
	else:
		_shuffle_selected_slot = -1
		use_powerup_at_slot(slot_index)

func collect_powerup(_powerup_card: BasePowerupCard) -> bool:
	return find_empty_slot() != -1

func find_empty_slot() -> int:
	for i in range(MAX_INVENTORY_SLOTS):
		if powerup_inventory[i] == null:
			return i
	return -1

func add_powerup_to_slot(card_type: int, slot_index: int):
	var powerup_card = _create_card_from_type(card_type)
	_set_inventory_slot(slot_index, powerup_card, 1)
	inventory_updated.emit(get_inventory_display_data())
	EventManager.emit_event(EventManager.Events.POWERUP_COLLECTED, [player_node, powerup_card, slot_index])

@rpc("any_peer", "call_local", "reliable")
func _sync_collect_powerup(card_type: int, slot_index: int):
	var powerup_card = _create_card_from_type(card_type)
	_set_inventory_slot(slot_index, powerup_card, 1)
	inventory_updated.emit(get_inventory_display_data())
	EventManager.emit_event(EventManager.Events.POWERUP_COLLECTED, [player_node, powerup_card, slot_index])

func use_powerup_at_slot(slot_index: int):
	if slot_index < 0 or slot_index >= MAX_INVENTORY_SLOTS:
		return
	
	var powerup_card = powerup_inventory[slot_index]
	if powerup_card == null:
		return
	
	_sync_use_powerup.rpc(powerup_card.type, slot_index, get_inventory_stack_count(slot_index))

@rpc("any_peer", "call_local", "reliable")
func _sync_use_powerup(card_type: int, slot_index: int, inventory_stack_count: int = 1):
	var powerup_card = _create_card_from_type(card_type)
	var activation_stack_count := _get_activation_stack_count(powerup_card, inventory_stack_count)
	_apply_powerup_activation(powerup_card, activation_stack_count)
	
	if player_node and player_node.is_multiplayer_authority():
		_reset_inventory_slot(slot_index)
		_shuffle_selected_slot = -1
		inventory_updated.emit(get_inventory_display_data())
		powerup_activated.emit(powerup_card, slot_index)
		EventManager.emit_event(EventManager.Events.POWERUP_USED, [player_node, powerup_card, slot_index])
		_sync_weapon_state_after_powerup_change()
	active_powerups_updated.emit(active_powerups)

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
		_apply_powerup_activation(first_card, group.size())
		
		for card_info in group:
			_reset_inventory_slot(card_info["slot"])
			powerup_activated.emit(card_info["card"], card_info["slot"])
	
	inventory_updated.emit(get_inventory_display_data())
	active_powerups_updated.emit(active_powerups)

func _get_active_powerup_of_type(type: BasePowerupCard.PowerupType) -> ActivePowerup:
	for powerup in active_powerups:
		if powerup.powerup_card.type == type:
			return powerup
	return null

func _on_powerup_expired(expired_powerup: ActivePowerup):
	if player_node and player_node.is_multiplayer_authority():
		_sync_powerup_expired.rpc(expired_powerup.powerup_card.type)
	else:
		_remove_active_powerup_local(expired_powerup.powerup_card.type)

func _remove_active_powerup_local(card_type: BasePowerupCard.PowerupType) -> void:
	var powerup := _get_active_powerup_of_type(card_type)
	if not powerup:
		return
	var card = powerup.powerup_card
	powerup.remove_effect()
	active_powerups.erase(powerup)
	powerup.queue_free()
	active_powerups_updated.emit(active_powerups)
	EventManager.emit_event(EventManager.Events.POWERUP_EXPIRED, [player_node, card])

@rpc("any_peer", "call_local", "reliable")
func _sync_powerup_expired(card_type: int) -> void:
	_remove_active_powerup_local(card_type)
	if player_node and player_node.is_multiplayer_authority():
		_sync_weapon_state_after_powerup_change()

func expire_active_powerup_of_type(type: BasePowerupCard.PowerupType) -> void:
	if not player_node or not player_node.is_multiplayer_authority():
		return
	if _get_active_powerup_of_type(type):
		_sync_powerup_expired.rpc(type)

func _sync_weapon_state_after_powerup_change() -> void:
	var weapon_manager = player_node.get_node_or_null("PlayerController/WeaponManager")
	if weapon_manager and weapon_manager.has_method("_sync_weapons_to_peers"):
		weapon_manager._sync_weapons_to_peers()

func trigger_burst_if_ready(weapon: RangedWeapon) -> bool:
	var burst_powerup := _get_active_powerup_of_type(BasePowerupCard.PowerupType.BURST)
	if burst_powerup == null or burst_powerup.get_remaining_uses() <= 0:
		return false
	if weapon == null or weapon.ammo <= 0 or weapon.is_reloading:
		return false
	
	var card = burst_powerup.powerup_card
	if not card.has_method("execute_burst"):
		return false
	
	card.execute_burst(weapon, burst_powerup.stack_count)
	burst_powerup.consume_use()
	active_powerups_updated.emit(active_powerups)
	return true

func _on_weapon_fired(weapon_node: Node, _current_ammo: int, _max_ammo: int) -> void:
	if not player_node or not player_node.is_multiplayer_authority():
		return
	
	var weapon_manager = weapon_node.get_parent()
	if weapon_manager == null or weapon_manager.get("player") != player_node:
		return
	
	for active_powerup in active_powerups.duplicate():
		if not active_powerup.has_use_limit():
			continue
		if not active_powerup.powerup_card.should_consume_use_on_weapon_fired():
			continue
		active_powerup.consume_use()

func get_inventory_slot_count() -> int:
	return MAX_INVENTORY_SLOTS

func get_inventory_stack_count(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= powerup_inventory_stack_counts.size():
		return 0
	if powerup_inventory[slot_index] == null:
		return 0
	return maxi(powerup_inventory_stack_counts[slot_index], 1)

func get_inventory_display_data() -> Array[Dictionary]:
	var display_data: Array[Dictionary] = []
	for i in range(MAX_INVENTORY_SLOTS):
		display_data.append({
			"card": powerup_inventory[i],
			"count": get_inventory_stack_count(i),
			"selected": i == _shuffle_selected_slot,
		})
	return display_data

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
	powerup_inventory_stack_counts.clear()
	powerup_inventory_stack_counts.resize(MAX_INVENTORY_SLOTS)
	_shuffle_selected_slot = -1
	inventory_updated.emit(get_inventory_display_data())

func clear_inventory_on_death() -> void:
	if player_node.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	_sync_clear_inventory.rpc()

func clear_active_powerups_on_death() -> void:
	if player_node.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	_sync_clear_active_powerups.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_clear_inventory() -> void:
	clear_inventory()

@rpc("any_peer", "call_local", "reliable")
func _sync_clear_active_powerups() -> void:
	clear_all_active_powerups()

func clear_all_active_powerups():
	for powerup in active_powerups:
		powerup.remove_effect()
		powerup.queue_free()
	active_powerups.clear()
	active_powerups_updated.emit(active_powerups)

func _create_card_from_type(card_type: int) -> BasePowerupCard:
	match card_type:
		BasePowerupCard.PowerupType.FASTER_DASH:
			return PowerupFactory.create_faster_dash()
		BasePowerupCard.PowerupType.DAMAGE_BOOST:
			return PowerupFactory.create_damage_boost()
		BasePowerupCard.PowerupType.HEALTH_BOOST:
			return PowerupFactory.create_health_boost()
		BasePowerupCard.PowerupType.RELOAD_SPEED:
			return PowerupFactory.create_reload_speed()
		BasePowerupCard.PowerupType.BURST:
			return PowerupFactory.create_burst()
		BasePowerupCard.PowerupType.ARMOR:
			return PowerupFactory.create_armor()
		BasePowerupCard.PowerupType.DUAL_WIELD:
			return PowerupFactory.create_dual_wield()
		_:
			return PowerupFactory.create_faster_dash()

func _handle_shuffle_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_INVENTORY_SLOTS:
		return
	if powerup_inventory[slot_index] == null:
		return
	if _shuffle_selected_slot == -1:
		_shuffle_selected_slot = slot_index
		return
	if _shuffle_selected_slot == slot_index:
		_shuffle_selected_slot = -1
		return
	_merge_inventory_slots(_shuffle_selected_slot, slot_index)
	_shuffle_selected_slot = -1

func _merge_inventory_slots(source_slot: int, target_slot: int) -> void:
	var source_card := powerup_inventory[source_slot]
	var target_card := powerup_inventory[target_slot]
	if source_card == null or target_card == null:
		return
	if source_card.type != target_card.type:
		return
	var source_count := get_inventory_stack_count(source_slot)
	var target_count := get_inventory_stack_count(target_slot)
	var max_stack_count: int = mini(source_card.max_stack_count, target_card.max_stack_count)
	if target_count >= max_stack_count:
		return
	var moved_count := mini(source_count, max_stack_count - target_count)
	if moved_count <= 0:
		return
	powerup_inventory_stack_counts[target_slot] = target_count + moved_count
	var remaining_source_count := source_count - moved_count
	if remaining_source_count <= 0:
		_reset_inventory_slot(source_slot)
	else:
		powerup_inventory_stack_counts[source_slot] = remaining_source_count
	inventory_updated.emit(get_inventory_display_data())
	EventManager.emit_event(EventManager.Events.POWERUP_COLLECTED, [player_node, target_card, target_slot])

func _get_activation_stack_count(powerup_card: BasePowerupCard, inventory_stack_count: int) -> int:
	if GameManager.is_poker_mode() and powerup_card.type == GameManager.get_poker_featured_card_type():
		return powerup_card.max_stack_count
	if GameManager.is_shuffle_mode():
		return clampi(inventory_stack_count, 1, powerup_card.max_stack_count)
	return 1

func _apply_powerup_activation(powerup_card: BasePowerupCard, activation_stack_count: int) -> void:
	var existing_powerup = _get_active_powerup_of_type(powerup_card.type)
	if GameManager.is_poker_mode():
		if powerup_card.type == GameManager.get_poker_featured_card_type():
			if existing_powerup:
				existing_powerup.set_stack_count(activation_stack_count)
			else:
				_create_active_powerup(powerup_card, activation_stack_count)
			return
		if existing_powerup:
			existing_powerup.set_stack_count(1)
			return
		_create_active_powerup(powerup_card, 1)
		return
	if existing_powerup:
		existing_powerup.add_stack(activation_stack_count)
	else:
		_create_active_powerup(powerup_card, activation_stack_count)

func _create_active_powerup(powerup_card: BasePowerupCard, stack_count: int) -> void:
	var active_powerup = ActivePowerup.new(powerup_card, player_node, stack_count)
	active_powerup.powerup_expired.connect(_on_powerup_expired)
	active_powerups.append(active_powerup)
	add_child(active_powerup)

func _set_inventory_slot(slot_index: int, powerup_card: BasePowerupCard, stack_count: int) -> void:
	powerup_inventory[slot_index] = powerup_card
	powerup_inventory_stack_counts[slot_index] = stack_count if powerup_card != null else 0

func _reset_inventory_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_INVENTORY_SLOTS:
		return
	powerup_inventory[slot_index] = null
	powerup_inventory_stack_counts[slot_index] = 0
