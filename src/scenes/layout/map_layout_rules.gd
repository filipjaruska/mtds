@tool
extends Resource
class_name MapLayoutRules
## How a map's rooms are put together each match (set on the map's root node):
## the corridors carved between rooms and what they are made of.

## Corridor width in tiles; doorways are this wide too.
@export_range(1, 8) var corridor_tiles: int = 3
## How much corridors avoid turning (higher = longer straight runs).
@export_range(0.0, 20.0, 0.5) var turn_cost: float = 3.0
## How far outside the rooms corridors may wander, in tiles.
@export_range(2, 60) var padding_tiles: int = 12
@export_group("Corridor tiles")
## Tile set the corridors are painted with (its physics layer must be on
## layer 3 "walls" for the corridor walls to stop players and shots).
@export var tile_set: TileSet
## Corridor floor: tile set source id and atlas coords.
@export var floor_source_id: int = 1
@export var floor_atlas_coords: Vector2i = Vector2i.ZERO
## Corridor walls: tile set source id and atlas coords.
@export var wall_source_id: int = 2
@export var wall_atlas_coords: Vector2i = Vector2i.ZERO
@export_group("Editor")
## The layout the preview button shows when not 0, so you can keep looking at
## one layout while changing the map.
@export var preview_seed: int = 0

const TILE := 64
