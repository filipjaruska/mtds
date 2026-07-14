extends Node
## Provides a publish/subscribe pattern for loosely coupled communication between
## different parts of the game. Components can emit events (publish) and other
## components can listen for events (subscribe).
##
## For more information see the docs: res://docs/docs/event-manager.md

var _signal_dict = {}
var _event_contracts = {}
var strict_validation: bool = true
var log_invalid_payloads: bool = true

enum Events {
	# Player events
	PLAYER_DAMAGED, # [player_node, damage_amount, remaining_health]
	PLAYER_HEALED, # [player_node, heal_amount, new_health]
	PLAYER_DIED, # [player_node]
	PLAYER_RESPAWNED, # [player_node]
	
	# Weapon events
	WEAPON_FIRED, # [weapon_node, current_ammo, max_ammo]
	WEAPON_RELOADED, # [weapon_node, is_reloading_start: bool, remaining_reload_time: float]
	WEAPON_SWITCHED, # [player_node, weapon_index, weapon_node]
	WEAPON_PICKED_UP, # [player_node, weapon_node]
	WEAPON_DROPPED, # [player_node, weapon_node]
	
	# UI events
	UI_HEALTH_UPDATED, # [current_health: int, max_health: int]
	UI_AMMO_UPDATED, # [current_ammo: int, max_ammo: int]
	UI_WEAPON_SLOTS_UPDATED, # [Array of slot information]
	
	# Multiplayer events
	PLAYER_CONNECTED, # [player_id: int]
	PLAYER_DISCONNECTED, # [player_id: int, player_data: Dictionary]
	CONNECTION_SUCCEEDED, # []
	CONNECTION_FAILED, # []
	
	# Game state events
	GAME_STATE_CHANGED, # [old_state: GameManager.GameState, new_state: GameManager.GameState]
	
	# Powerup events
	POWERUP_COLLECTED, # [player_node, powerup_card, inventory_slot]
	POWERUP_USED, # [player_node, powerup_card, inventory_slot]
	POWERUP_EXPIRED, # [player_node, powerup_card]
}

## Initialize all events on ready
func _ready() -> void:
	for event_name in Events.keys():
		var event_id = Events[event_name]
		_signal_dict[event_id] = []
		add_user_signal(event_name)
	_initialize_event_contracts()

func _initialize_event_contracts() -> void:
	_event_contracts = {
		Events.PLAYER_DAMAGED: [TYPE_OBJECT, TYPE_FLOAT, TYPE_FLOAT],
		Events.PLAYER_HEALED: [TYPE_OBJECT, TYPE_FLOAT, TYPE_FLOAT],
		Events.PLAYER_DIED: [TYPE_OBJECT],
		Events.PLAYER_RESPAWNED: [TYPE_OBJECT],
		Events.WEAPON_FIRED: [TYPE_OBJECT, TYPE_INT, TYPE_INT],
		Events.WEAPON_RELOADED: [TYPE_OBJECT, TYPE_BOOL, TYPE_FLOAT],
		Events.WEAPON_SWITCHED: [TYPE_OBJECT, TYPE_INT, TYPE_OBJECT],
		Events.WEAPON_PICKED_UP: [TYPE_OBJECT, TYPE_OBJECT],
		Events.WEAPON_DROPPED: [TYPE_OBJECT, TYPE_OBJECT],
		Events.UI_HEALTH_UPDATED: [TYPE_OBJECT, TYPE_INT, TYPE_INT],
		Events.UI_AMMO_UPDATED: [TYPE_INT, TYPE_INT],
		Events.UI_WEAPON_SLOTS_UPDATED: [TYPE_ARRAY],
		Events.PLAYER_CONNECTED: [TYPE_INT],
		Events.PLAYER_DISCONNECTED: [TYPE_INT, TYPE_DICTIONARY],
		Events.CONNECTION_SUCCEEDED: [],
		Events.CONNECTION_FAILED: [],
		Events.GAME_STATE_CHANGED: [TYPE_INT, TYPE_INT],
		Events.POWERUP_COLLECTED: [TYPE_OBJECT, TYPE_OBJECT, TYPE_INT],
		Events.POWERUP_USED: [TYPE_OBJECT, TYPE_OBJECT, TYPE_INT],
		Events.POWERUP_EXPIRED: [TYPE_OBJECT, TYPE_OBJECT]
	}

## Register a callback to an event
## 
## Subscribes an object's method to be called when the specified event is emitted.
## @param event  The event type from the Events enum
## @param target The object that will receive the callback
## @param method The method name to call on the target object
## @param binds  Optional array of additional parameters to pass to the callback
func register(event: int, target_or_callable: Variant, method: String = "", binds: Array = []) -> void:
	if not _signal_dict.has(event):
		push_error("Trying to register non-existent event: " + str(event))
		return

	var event_callable: Callable
	var target: Object = null
	var method_name: String = method

	if target_or_callable is Callable:
		event_callable = target_or_callable
		target = event_callable.get_object()
		method_name = event_callable.get_method()
		if binds.size() > 0:
			event_callable = event_callable.bindv(binds)
	elif target_or_callable is Object:
		target = target_or_callable
		if method_name.is_empty():
			push_error("Register requires a method name when passing a target object.")
			return
		event_callable = Callable(target, method_name)
		if binds.size() > 0:
			event_callable = event_callable.bindv(binds)
	else:
		push_error("Register requires either a Callable or target Object.")
		return

	# Check if this connection already exists
	for connection in _signal_dict[event]:
		if connection.callable == event_callable:
			return
	
	# Store connection info
	_signal_dict[event].append({
		"callable": event_callable,
		"target": target,
		"method": method_name
	})
	
	# Connect to target's tree_exiting signal to auto-unregister
	if target is Node:
		var on_exit := _on_target_tree_exiting.bind(event, target, method_name)
		if not target.tree_exiting.is_connected(on_exit):
			target.tree_exiting.connect(on_exit)

## Unregister a callback from an event
##
## @param event The event type from the Events enum
## @param target The object that was receiving the callback
## @param method The method name that was being called
func unregister(event: int, target_or_callable: Variant, method: String = "") -> void:
	if not _signal_dict.has(event):
		push_error("Trying to unregister from non-existent event: " + str(event))
		return

	var callable_to_remove: Callable
	var target: Object = null
	var method_name: String = method

	if target_or_callable is Callable:
		callable_to_remove = target_or_callable
		target = callable_to_remove.get_object()
		method_name = callable_to_remove.get_method()
	elif target_or_callable is Object:
		target = target_or_callable
		if method_name.is_empty():
			push_error("Unregister requires a method name when passing a target object.")
			return
	else:
		push_error("Unregister requires either a Callable or target Object.")
		return
	
	var connections = _signal_dict[event]
	for i in range(connections.size() - 1, -1, -1):
		if target_or_callable is Callable:
			if connections[i].callable == callable_to_remove:
				connections.remove_at(i)
		else:
			if connections[i].target == target and connections[i].method == method_name:
				connections.remove_at(i)

## Clean up when a connected object is freed
## 
## @private
## @param event The event type from the Events enum
## @param target The target object that is being freed
## @param method The method that was registered
func _on_target_tree_exiting(event: int, target: Object, method: String) -> void:
	unregister(event, target, method)

## Emit an event with optional arguments
##
## Triggers all callbacks registered to the specified event.
## @param event The event type from the Events enum
## @param args Optional array of arguments to pass to the callbacks
func emit_event(event: int, args: Array = []) -> void:
	if not _signal_dict.has(event):
		push_error("Trying to emit non-existent event: " + str(event))
		return
	
	if not _validate_event_args(event, args):
		return
	
	# Call all registered callbacks
	for connection in _signal_dict[event]:
		if connection.target == null or is_instance_valid(connection.target):
			connection.callable.callv(args)

func _validate_event_args(event: int, args: Array) -> bool:
	if not _event_contracts.has(event):
		return true

	var contract: Array = _event_contracts[event]
	if contract.size() != args.size():
		var count_error = "Event %s expected %d args but got %d" % [get_event_name(event), contract.size(), args.size()]
		_log_invalid_emit(event, args, count_error)
		if strict_validation:
			push_error(count_error)
			return false
		push_warning(count_error)
		return true

	for i in range(contract.size()):
		if not _matches_type(args[i], contract[i]):
			var type_error = "Event %s arg[%d] expected %s but got %s" % [
				get_event_name(event),
				i,
				_type_to_string(contract[i]),
				type_string(typeof(args[i]))
			]
			_log_invalid_emit(event, args, type_error)
			if strict_validation:
				push_error(type_error)
				return false
			push_warning(type_error)
			return true

	return true

func _matches_type(value: Variant, expected_type: Variant) -> bool:
	if expected_type is Array:
		for allowed_type in expected_type:
			if typeof(value) == int(allowed_type):
				return true
		return false
	return typeof(value) == int(expected_type)

func _type_to_string(expected_type: Variant) -> String:
	if expected_type is Array:
		var names: Array = []
		for allowed_type in expected_type:
			names.append(type_string(int(allowed_type)))
		return "/".join(names)
	return type_string(int(expected_type))

func _log_invalid_emit(event: int, args: Array, reason: String) -> void:
	if not log_invalid_payloads:
		return
	push_warning("Event validation failed (%s): %s | payload=%s" % [get_event_name(event), reason, _format_payload(args)])

func _format_payload(args: Array) -> String:
	var preview: Array = []
	for value in args:
		preview.append("%s:%s" % [type_string(typeof(value)), str(value)])
	return "[" + ", ".join(preview) + "]"

## Helper method to get event names for debugging
##
## Converts an event integer to its string name.
## @param event The event type from the Events enum
## @return The string name of the event or "UNKNOWN_EVENT" if not found
func get_event_name(event: int) -> String:
	for key in Events.keys():
		if Events[key] == event:
			return key
	return "UNKNOWN_EVENT"
