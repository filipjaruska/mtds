extends Node
## EventManager (autoload): every game-wide event in one place. Type
## `EventManager.` to see them all.
##
##   EventManager.player_died.connect(_on_player_died)   listen
##   EventManager.player_died.emit(player)               announce
##
## A listener's function takes the event's values in the order listed here.
## Connections end by themselves when the listening node is freed.
## Events that belong to one object stay on that object instead (for example
## PowerupManager.active_changed); this file is only for game-wide ones.

# Other scripts emit these, so Godot's "signal never used here" warning is expected.
@warning_ignore_start("unused_signal")

# --- Players ---------------------------------------------------------------------

## A player lost health. `amount` is how much, `health_left` what remains.
signal player_damaged(player: Node, amount: float, health_left: float)
## A player regained health.
signal player_healed(player: Node, amount: float, health: float)
signal player_died(player: Node)
signal player_respawned(player: Node)
## A player's health or max health changed (drives the HUD).
signal health_changed(player: Node, health: int, max_health: int)

# --- Weapons -----------------------------------------------------------------------

## A shot left the gun; `ammo` is what is left in the magazine.
signal weapon_fired(player: Node, ammo: int, mag_size: int)
## A reload started (`started` true, lasting `reload_seconds`) or ended.
signal weapon_reloaded(player: Node, started: bool, reload_seconds: float)
## The player now holds `weapon` (null: empty hands) from slot `slot`.
signal weapon_switched(player: Node, slot: int, weapon: WeaponDef)
signal weapon_picked_up(player: Node, weapon: WeaponDef)
signal weapon_dropped(player: Node, weapon: WeaponDef)
## Ammo to show. Melee weapons send -1; the offhand values are -1 unless
## dual wielding.
signal ammo_changed(player: Node, ammo: int, mag_size: int, offhand_ammo: int, offhand_mag_size: int)
## The weapon slot names ("" for empty) and which one is in use.
signal weapon_slots_changed(player: Node, slot_names: Array, active_slot: int)

# --- Cards -------------------------------------------------------------------------

## A card went into the hand at `slot`.
signal powerup_collected(player: Node, card: PowerupDef, slot: int)
## The card in `slot` was played.
signal powerup_used(player: Node, card: PowerupDef, slot: int)
## An active card ran out.
signal powerup_expired(player: Node, card: PowerupDef)

# --- In-game events (Shady Fella, the blackjack table...) -------------------------

## An event began on this game (a GameEvent node).
signal game_event_started(event: Node)
## An event is over (the node is freed right after).
signal game_event_ended(event: Node)

# --- Session -----------------------------------------------------------------------

## A peer joined the lobby (host side, and on clients for others).
signal player_connected(peer_id: int)
## A peer left; `player_data` is what GameManager knew about them.
signal player_disconnected(peer_id: int, player_data: Dictionary)
## This client reached the host.
signal connected_to_host()
## This client could not reach the host.
signal connection_failed()
## GameManager.GameState changed.
signal game_state_changed(old_state: int, new_state: int)
