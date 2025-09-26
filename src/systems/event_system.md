### Key Concepts

- **Publisher/Subscriber Model**: Components can emit events (publish) and other components can listen for events (subscribe)
- **Auto Cleanup**: The system automatically handles cleanup when subscribed objects are freed
- **Method References**: GDScript uses string method names
- **Argument Passing**: Parameters are passed through arrays rather than strongly typed function signatures

### Usage Examples

#### Subscribing to Events (Listening)

```py
# In your component's _ready function
func _ready():
    # Register to listen for player damaged event
    EventManager.register(
        EventManager.Events.PLAYER_DAMAGED,  # The event to subscribe to
        self,                               # The object that will receive the callback
        "_on_player_damaged"                # The method name to call
    )

    # Register for weapon events
    EventManager.register(EventManager.Events.WEAPON_FIRED, self, "_on_weapon_fired")
    EventManager.register(EventManager.Events.WEAPON_RELOADED, self, "_on_weapon_reloaded")

# Callback methods must match the parameter structure of the event
func _on_player_damaged(player_node, damage_amount, remaining_health):
    # Handle player damage event
    # Parameters come from the emit_event call arguments array
    print("Player took damage: ", damage_amount)

func _on_weapon_fired(weapon, ammo, max_ammo) -> void:
    if weapon == current_weapon():
        # Handle weapon fired logic
        pass
```

#### Adding Custom Parameters with Binds

```py
# With additional binding parameters that will be appended to event args
EventManager.register(
    EventManager.Events.WEAPON_PICKED_UP,
    self,
    "_on_weapon_picked_up",
    [true]  # This bind parameter will be passed as the last argument
)

# Your callback with a custom bind parameter
func _on_weapon_picked_up(player_node, weapon_node, should_auto_equip):
    # player_node and weapon_node come from emit_event
    # should_auto_equip comes from the binds array [true]
    if should_auto_equip:
        equip_weapon(weapon_node)
```

#### Unsubscribing from Events

```py
# Manual unsubscribe in _exit_tree
func _exit_tree():
    EventManager.unregister(EventManager.Events.WEAPON_FIRED, self, "_on_weapon_fired")
    EventManager.unregister(EventManager.Events.WEAPON_RELOADED, self, "_on_weapon_reloaded")
```

Note: The system automatically unregisters callbacks when an object is freed, so manual unsubscription is optional.

#### Publishing Events (Emitting)

```py
# Emit an event with no parameters
EventManager.emit_event(EventManager.Events.GAME_STARTED)

# Emit an event with parameters - player damaged
EventManager.emit_event(
    EventManager.Events.PLAYER_DAMAGED,
    [get_parent(), final_dmg, current_health]  # [player_node, damage_amount, remaining_health]
)

# Emit UI update event
EventManager.emit_event(
    EventManager.Events.UI_AMMO_UPDATED,
    [ammo, max_ammo]  # [current_ammo, max_ammo]
)

# Emit weapon event
EventManager.emit_event(
    EventManager.Events.WEAPON_PICKED_UP,
    [player, weapon]  # [player_node, weapon_node]
)
```
