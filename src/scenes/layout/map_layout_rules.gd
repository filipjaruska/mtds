@tool
extends Resource
class_name MapLayoutRules
## How a slot map is put together each match (set on the map's root node).
## Rooms are placed on a grid of slots; doorways sit in the middle of each
## room side, so rooms line up however they are turned.

## Size of one slot in tiles (64 px each). Every room in the map has this size.
## Width minus door width must be even (and height minus door width), so a
## doorway stays centred when a room is mirrored.
@export var slot_tiles: Vector2i = Vector2i(16, 16)
## Width of every doorway, in tiles.
@export_range(1, 8) var door_tiles: int = 4
## Doorways that are not needed to connect the map are open this often (0 = a
## maze with exactly one way between any two rooms, 1 = every doorway open).
@export_range(0.0, 1.0, 0.05) var extra_door_chance: float = 0.35
## The layout used by the editor's preview button when not 0, so you can keep
## looking at one layout while changing rooms.
@export var preview_seed: int = 0

const TILE := 64

func slot_pixels() -> Vector2:
	return Vector2(slot_tiles) * TILE

## Problems with these numbers, for the map's warnings.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if (slot_tiles.x - door_tiles) % 2 != 0 or (slot_tiles.y - door_tiles) % 2 != 0:
		out.append("Layout rules: slot width and height minus the door width must be even, or doorways do not line up when rooms are mirrored.")
	if door_tiles > mini(slot_tiles.x, slot_tiles.y) - 2:
		out.append("Layout rules: doorways are wider than a slot's side.")
	return out
