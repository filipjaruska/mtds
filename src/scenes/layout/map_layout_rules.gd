@tool
extends Resource
class_name MapLayoutRules
## How a map's rooms are put together each match (set on the map's root node):
## the corridors carved between rooms and what they are made of.
##
## Indoors (catacombs) corridors are tunnels with walls, and the space between
## them is solid. Outdoors corridors are roads without walls, the ground between
## rooms is filled in (grass) and a wall runs round the whole map, so the map is
## one rectangle with the rooms as buildings in it.

## Corridor width in tiles, and doorway width, unless a link or doorway sets its own.
@export_range(1, 8) var corridor_tiles: int = 3
## A link whose corridor would be longer than this many times the straight
## distance between its doorways (plus a few tiles) is dropped for the match;
## rooms then get short corridors to their nearest neighbours instead. A long
## way round is only used when nothing else reaches a room.
@export_range(1.0, 5.0, 0.1) var max_detour: float = 1.3
## How much corridors avoid turning (higher = longer straight runs).
@export_range(0.0, 20.0, 0.5) var turn_cost: float = 3.0
## How far outside the rooms corridors may wander, in tiles.
@export_range(2, 60) var padding_tiles: int = 12
@export_group("Corridor tiles")
## Tile set the corridors are painted with (its physics layer must be on
## layer 3 "walls" for the corridor walls to stop players and shots).
@export var tile_set: TileSet
## Corridor floor (outdoors: the roads): tile set source id and atlas coords.
@export var floor_source_id: int = 1
@export var floor_atlas_coords: Vector2i = Vector2i.ZERO
## Corridor walls (outdoors: the wall round the map): tile set source id and atlas coords.
@export var wall_source_id: int = 2
@export var wall_atlas_coords: Vector2i = Vector2i.ZERO
@export_group("Outdoors")
## Roads instead of tunnels, ground between the rooms and a wall round the map
## (use a tile set with ground, road and wall tiles and set their ids here).
@export var outdoors: bool = false
## The ground between rooms and roads: tile set source id and atlas coords.
@export var ground_source_id: int = 0
@export var ground_atlas_coords: Vector2i = Vector2i.ZERO
## Ground beyond the outermost room or road, in tiles.
@export_range(1, 40) var border_tiles: int = 6
## Make the map a square instead of just a rectangle.
@export var square: bool = false
@export_group("Editor")
## The layout the preview button shows when not 0, so you can keep looking at
## one layout while changing the map.
@export var preview_seed: int = 0

const TILE := 64
