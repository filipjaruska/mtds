extends Area2D
class_name PeaceZone
## A no-fighting area: players inside cannot shoot, swing, charge or play cards,
## and nobody inside can be hurt (by players, NPCs or fire). Give it a CollisionShape2D child for
## its shape. Player positions are synced, so every game agrees on who is in
## it: the owner's game stops the input (and the HUD says so), the host refuses
## any attack that slips through. Switch it with `active` (events do).

const GROUP := &"peace_zone"

## Whether the zone is in force.
@export var active: bool = true

func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 1 # player bodies
	monitorable = false

## True while `player` stands in an active zone.
static func covers(player: Node) -> bool:
	if not player is Node2D or not player.is_inside_tree():
		return false
	for zone in player.get_tree().get_nodes_in_group(GROUP):
		if zone.active and zone.overlaps_body(player):
			return true
	return false
