extends Node
class_name PowerupManager
## A player's powerups. The inventory only exists on the owning peer; active
## powerups are mirrored on every peer (the host needs them to compute damage
## and health). Decisions live in PowerupRules; this node reads input, applies
## rule results and syncs.
##
## Systems that depend on powerups listen to `active_changed` and derive their
## state from get_modifiers() / the ability helpers, so nothing has to be
## "removed" again when a powerup ends.

const MAX_INVENTORY_SLOTS = 4

## Owner only. Emitted when the inventory changes.
signal inventory_updated(inventory: Array)
## Every peer. Emitted whenever the set of active powerups changes.
signal active_changed(active: Array)

## Owner only: Array of {def: StringName, count: int}.
var inventory: Array = PowerupRules.empty_inventory(MAX_INVENTORY_SLOTS)
## Every peer: Array of PowerupRules entries.
var active: Array = []
## Host: the card ids in this player's hand, as the owner last reported them
## (the inventory itself lives on the owner). Events use it to know who holds
## cards and who has room for one.
var hand_ids: Array[StringName] = []

@onready var player_node: Node = get_parent()

var _shuffle_selected_slot: int = -1

func _ready() -> void:
	EventManager.weapon_fired.connect(_on_weapon_fired)
	inventory_updated.connect(func(_data): _report_hand())

func _exit_tree() -> void:
	if EventManager.weapon_fired.is_connected(_on_weapon_fired): EventManager.weapon_fired.disconnect(_on_weapon_fired)

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_check_powerup_inputs()
	for def_id in PowerupRules.expired_ids(active, Time.get_ticks_msec()):
		_sync_expired.rpc(def_id)

# --- Queries -------------------------------------------------------------------

func get_modifiers() -> Dictionary:
	return PowerupRules.modifiers(active)

## Spread multiplier for dual wielding, or -1.0 when Dual Wield is not active.
func get_dual_wield_spread() -> float:
	var entry := PowerupRules.entry_with_ability(active, &"dual_wield")
	if entry.is_empty():
		return -1.0
	return PowerupRules.dual_spread(PowerupDefs.get_def(entry.def), entry.stacks)

func has_free_slot() -> bool:
	return PowerupRules.empty_slot(inventory) >= 0

func get_inventory_slot_count() -> int:
	return MAX_INVENTORY_SLOTS

func get_inventory_stack_count(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= inventory.size():
		return 0
	return inventory[slot_index].count

func get_used_inventory_slots() -> int:
	return inventory.filter(func(slot): return slot.def != &"").size()

## For the hand UI: one {card: PowerupDef or null, count, selected} per slot.
func get_inventory_display_data() -> Array[Dictionary]:
	var display_data: Array[Dictionary] = []
	for i in range(inventory.size()):
		var slot: Dictionary = inventory[i]
		display_data.append({
			"card": PowerupDefs.get_def(slot.def) if slot.def != &"" else null,
			"count": slot.count,
			"selected": i == _shuffle_selected_slot,
		})
	return display_data

# --- Owner actions -------------------------------------------------------------

func add_to_inventory(def_id: StringName) -> bool:
	var slot := PowerupRules.empty_slot(inventory)
	var def := PowerupDefs.get_def(def_id)
	if slot < 0 or def == null:
		return false
	inventory = PowerupRules.with_slot(inventory, slot, def_id, 1)
	inventory_updated.emit(get_inventory_display_data())
	EventManager.powerup_collected.emit(player_node, def, slot)
	return true

func use_powerup_at_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory.size():
		return
	var slot: Dictionary = inventory[slot_index]
	var def := PowerupDefs.get_def(slot.def)
	if def == null:
		return
	var stacks := PowerupRules.activation_stacks(def, slot.count)
	inventory = PowerupRules.with_slot(inventory, slot_index, &"", 0)
	_shuffle_selected_slot = -1
	inventory_updated.emit(get_inventory_display_data())
	_sync_activate.rpc(def.id, stacks)
	EventManager.powerup_used.emit(player_node, def, slot_index)

func expire(def_id: StringName) -> void:
	if is_multiplayer_authority() and not PowerupRules.find(active, def_id).is_empty():
		_sync_expired.rpc(def_id)

func expire_ability(ability: StringName) -> void:
	var entry := PowerupRules.entry_with_ability(active, ability)
	if not entry.is_empty():
		expire(entry.def)

## Spends a Burst use. Returns {spread_degrees, shots_per_second} or {}.
func try_consume_burst() -> Dictionary:
	var entry := PowerupRules.entry_with_ability(active, &"burst")
	if entry.is_empty() or entry.uses_left == 0:
		return {}
	active = PowerupRules.consume_use(active, entry.def)
	active_changed.emit(active)
	return PowerupRules.burst_params(PowerupDefs.get_def(entry.def), entry.stacks)

## Host: spend a use of an active powerup (Last Stand) and tell the owner, who
## keeps the authoritative list and ends the powerup when no uses are left.
func host_consume_use(def_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	active = PowerupRules.consume_use(active, def_id)
	active_changed.emit(active)
	if not is_multiplayer_authority():
		_consume_use_from_host.rpc_id(get_multiplayer_authority(), def_id)

@rpc("any_peer", "reliable")
func _consume_use_from_host(def_id: StringName) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	active = PowerupRules.consume_use(active, def_id)
	active_changed.emit(active)

# --- Cards given and taken by the host (events) -------------------------------------

## Host: has this player room for another card?
func host_has_free_slot() -> bool:
	return hand_ids.size() < MAX_INVENTORY_SLOTS

## Host -> owner: put a card in the hand (Shady Fella's offer, the blackjack table).
@rpc("any_peer", "call_local", "reliable")
func grant_card(def_id: StringName) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	add_to_inventory(def_id)

## Host -> owner: the hand is lost (a lost blackjack game).
@rpc("any_peer", "call_local", "reliable")
func take_all_cards() -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	inventory = PowerupRules.empty_inventory(MAX_INVENTORY_SLOTS)
	_shuffle_selected_slot = -1
	inventory_updated.emit(get_inventory_display_data())

## Owner -> host: what is in the hand now.
func _report_hand() -> void:
	if not is_multiplayer_authority():
		return
	var ids: Array[StringName] = []
	for slot in inventory:
		for i in range(slot.count):
			ids.append(slot.def)
	if multiplayer.is_server():
		hand_ids = ids
	else:
		_receive_hand.rpc_id(1, ids)

@rpc("any_peer", "reliable")
func _receive_hand(ids: Array[StringName]) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		hand_ids = ids

func clear_on_death() -> void:
	if not is_multiplayer_authority():
		return
	inventory = PowerupRules.empty_inventory(MAX_INVENTORY_SLOTS)
	_shuffle_selected_slot = -1
	inventory_updated.emit(get_inventory_display_data())
	_sync_clear_active.rpc()

func _on_weapon_fired(shooter: Node, _current_ammo: int, _max_ammo: int) -> void:
	if shooter != player_node or not is_multiplayer_authority():
		return
	var changed := false
	for entry in active:
		var def := PowerupDefs.get_def(entry.def)
		if def and def.consume_use_on_fire and entry.uses_left > 0:
			active = PowerupRules.consume_use(active, entry.def)
			changed = true
	if changed:
		active_changed.emit(active)

# --- Input ---------------------------------------------------------------------

func _check_powerup_inputs() -> void:
	var slot_index: int = InputManager.get_powerup_slot_use_index()
	if slot_index < 0:
		if not InputManager.is_powerup_shuffle_held():
			_shuffle_selected_slot = -1
		return
	if InputManager.is_powerup_shuffle_held():
		_handle_shuffle_slot_pressed(slot_index)
	elif not PeaceZone.covers(player_node): # merging is fine, playing is not
		_shuffle_selected_slot = -1
		use_powerup_at_slot(slot_index)

## Shift + slot: pick a slot, then a matching slot to merge the stacks.
func _handle_shuffle_slot_pressed(slot_index: int) -> void:
	if inventory[slot_index].def == &"":
		return
	if _shuffle_selected_slot == -1 or _shuffle_selected_slot == slot_index:
		_shuffle_selected_slot = slot_index if _shuffle_selected_slot == -1 else -1
		inventory_updated.emit(get_inventory_display_data())
		return
	var def := PowerupDefs.get_def(inventory[slot_index].def)
	var merged := PowerupRules.merge(inventory, _shuffle_selected_slot, slot_index, def.max_stack_count)
	_shuffle_selected_slot = -1
	if merged != inventory:
		inventory = merged
		EventManager.powerup_collected.emit(player_node, def, slot_index)
	inventory_updated.emit(get_inventory_display_data())

# --- Owner -> everyone ---------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _sync_activate(def_id: StringName, stacks: int) -> void:
	var def := PowerupDefs.get_def(def_id)
	if def == null:
		return
	active = PowerupRules.activate(active, def, stacks, Time.get_ticks_msec())
	active_changed.emit(active)

@rpc("authority", "call_local", "reliable")
func _sync_expired(def_id: StringName) -> void:
	if PowerupRules.find(active, def_id).is_empty():
		return
	active = PowerupRules.without(active, def_id)
	active_changed.emit(active)
	EventManager.powerup_expired.emit(player_node, PowerupDefs.get_def(def_id))

@rpc("authority", "call_local", "reliable")
func _sync_clear_active() -> void:
	active = []
	active_changed.emit(active)
