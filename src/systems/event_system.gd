extends Node
## Provides a publish/subscribe pattern for loosely coupled communication between
## different parts of the game. Components can emit events (publish) and other
## components can listen for events (subscribe).
##
## For more information see the docs: res://docs/docs/event-manager.md

var _signal_dict = {}

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

## Register a callback to an event
## 
## Subscribes an object's method to be called when the specified event is emitted.
## @param event  The event type from the Events enum
## @param target The object that will receive the callback
## @param method The method name to call on the target object
## @param binds  Optional array of additional parameters to pass to the callback
func register(event: int, target: Object, method: String, binds: Array = []) -> void:
	if not _signal_dict.has(event):
		push_error("Trying to register non-existent event: " + str(event))
		return

	# Check if this connection already exists
	for connection in _signal_dict[event]:
		if connection.target == target and connection.method == method:
			return
	
	# Store connection info
	_signal_dict[event].append({
		"target": target,
		"method": method,
		"binds": binds
	})
	
	# Connect to target's tree_exiting signal to auto-unregister
	if not target.tree_exiting.is_connected(_on_target_tree_exiting.bind(event, target, method)):
		target.tree_exiting.connect(_on_target_tree_exiting.bind(event, target, method))

## Unregister a callback from an event
##
## @param event The event type from the Events enum
## @param target The object that was receiving the callback
## @param method The method name that was being called
func unregister(event: int, target: Object, method: String) -> void:
	if not _signal_dict.has(event):
		push_error("Trying to unregister from non-existent event: " + str(event))
		return
	
	var connections = _signal_dict[event]
	for i in range(connections.size() - 1, -1, -1):
		if connections[i].target == target and connections[i].method == method:
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
	
	# Call all registered callbacks
	for connection in _signal_dict[event]:
		if is_instance_valid(connection.target):
			var combined_args = args + connection.binds
			if combined_args.size() > 0:
				connection.target.callv(connection.method, combined_args)
			else:
				connection.target.call(connection.method)

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
