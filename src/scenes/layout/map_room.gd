@tool
extends Node2D
class_name MapRoom
## The root of a room or block scene for slot maps (see GameMap and MapSlot).
## Make one by duplicating res://src/scenes/rooms/room_template.tscn.
##
## A room is one slot big (the map's layout rules say how many tiles) with its
## top-left corner at this node. Inside it: Floor and Walls tile layers, and
## anything a map can have (SpawnPoints, WeaponSpawners, PowerupSpawners...).
##
## Each side is a wall, a doorway or open:
##   WALL  solid; the walls are painted along the room's border
##   DOOR  a gap in the middle of the border wall, as wide as the map's door
##         width. Leave those tiles without walls; the map walls them up when
##         nothing is on the other side or the doorway stays closed
##   OPEN  no border wall at all (blocks of an open area); walled up along the
##         whole side when the next slot is empty
## The map turns and mirrors rooms, so any side can end up anywhere.
##
## Semi-permanent rooms (`gated`) start closed: their doorways get gates that
## open when an event calls GameMap.set_gate_open(gate, true). Nobody spawns
## in them while they are closed.

enum Edge { WALL, DOOR, OPEN }

const TILE := 64
const SIDE_NAMES := ["north", "east", "south", "west"]

## Size in tiles; must match the map's slot size.
@export var size_tiles: Vector2i = Vector2i(16, 16):
	set(value):
		size_tiles = value
		_changed()
## Doorway width in tiles; must match the map's door width.
@export_range(1, 8) var door_tiles: int = 4:
	set(value):
		door_tiles = value
		_changed()
@export_group("Sides")
@export var north: Edge = Edge.DOOR:
	set(value):
		north = value
		_changed()
@export var east: Edge = Edge.DOOR:
	set(value):
		east = value
		_changed()
@export var south: Edge = Edge.DOOR:
	set(value):
		south = value
		_changed()
@export var west: Edge = Edge.DOOR:
	set(value):
		west = value
		_changed()
@export_group("Semi-permanent")
## Closed until an event opens it (the blackjack room, for example).
@export var gated: bool = false:
	set(value):
		gated = value
		_changed()
## Name events use to open it (GameMap.set_gate_open).
@export var gate: StringName = &""
@export_group("Sealing")
## The wall tile used to wall up doorways: tile set source id and atlas coords.
@export var seal_source_id: int = 2
@export var seal_atlas_coords: Vector2i = Vector2i.ZERO

## Gates placed in this room's doorways by the layout.
var gates: Array[RoomGate] = []
var opened := false

func edges() -> Array:
	return [north, east, south, west]

## Closed semi-permanent room: no spawning here, no way in.
func is_closed() -> bool:
	return gated and not opened

func set_gates_open(open: bool) -> void:
	opened = open
	for g in gates:
		g.set_open(open)

func floor_layer() -> TileMapLayer:
	return get_node_or_null("Floor") as TileMapLayer

func walls_layer() -> TileMapLayer:
	return get_node_or_null("Walls") as TileMapLayer

# --- Cells -------------------------------------------------------------------------

## Border tiles of the doorway on one of the room's own sides.
func door_cells(side: int) -> Array[Vector2i]:
	var along := size_tiles.x if side % 2 == 0 else size_tiles.y
	@warning_ignore("integer_division")
	var start := (along - door_tiles) / 2
	var cells: Array[Vector2i] = []
	for i in range(door_tiles):
		cells.append(_border_cell(side, start + i))
	return cells

## Every border tile of one side.
func side_cells(side: int) -> Array[Vector2i]:
	var along := size_tiles.x if side % 2 == 0 else size_tiles.y
	var cells: Array[Vector2i] = []
	for i in range(along):
		cells.append(_border_cell(side, i))
	return cells

func _border_cell(side: int, i: int) -> Vector2i:
	match side:
		0:
			return Vector2i(i, 0)
		1:
			return Vector2i(size_tiles.x - 1, i)
		2:
			return Vector2i(i, size_tiles.y - 1)
	return Vector2i(0, i)

func _cells_rect(cells: Array[Vector2i]) -> Rect2:
	var rect := Rect2(Vector2(cells[0]) * TILE, Vector2(TILE, TILE))
	for cell in cells:
		rect = rect.merge(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))
	return rect

# --- Applying a layout ---------------------------------------------------------------

## Called by GameMap with what the layout decided for one of the room's own
## sides (a LayoutPlanner.Side).
func apply_side(side: int, state: int) -> void:
	var kind: int = edges()[side]
	if kind == Edge.WALL:
		return
	if gated and kind == Edge.OPEN:
		kind = Edge.DOOR
	match state:
		LayoutPlanner.Side.SEALED:
			_wall_up(door_cells(side) if kind == Edge.DOOR else side_cells(side))
		LayoutPlanner.Side.GATE:
			if gated:
				var g := RoomGate.create(_cells_rect(door_cells(side)))
				g.name = "Gate_%s" % SIDE_NAMES[side]
				add_child(g)
				gates.append(g)

func _wall_up(cells: Array[Vector2i]) -> void:
	var walls := walls_layer()
	if walls == null:
		return
	for cell in cells:
		walls.set_cell(cell, seal_source_id, seal_atlas_coords)

# --- What the map needs to know --------------------------------------------------------

## Facts the layout planner and the map checks use.
func summary() -> Dictionary:
	var spawns := 0
	var weapons := {}
	for node in find_children("*", "", true, false):
		if node is SpawnPoint or node.is_in_group("PlayerSpawnLocation"):
			spawns += 1
		elif node is WeaponSpawner and node.weapon_def:
			weapons[node.weapon_def.id] = weapons.get(node.weapon_def.id, 0) + 1
	return {"edges": edges(), "gated": gated, "spawns": spawns, "weapons": weapons,
		"size_tiles": size_tiles, "door_tiles": door_tiles}

# --- Editor ---------------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := Vector2(size_tiles) * TILE
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 4.0)
	for side in range(4):
		var kind: int = edges()[side]
		if kind == Edge.WALL:
			continue
		var cells := door_cells(side) if kind == Edge.DOOR else side_cells(side)
		var color := Color(0.3, 1.0, 0.45, 0.9) if kind == Edge.DOOR else Color(0.3, 0.8, 1.0, 0.9)
		if gated:
			color = Color(1.0, 0.6, 0.15, 0.9)
		draw_rect(_cells_rect(cells).grow(-6), color, false, 6.0)
	var label := "%s  %dx%d tiles" % [name, size_tiles.x, size_tiles.y]
	if gated:
		label += "  ·  semi-permanent (%s)" % gate
	draw_string(ThemeDB.fallback_font, Vector2(12, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var walls := walls_layer()
	if floor_layer() == null or walls == null:
		warnings.append("Needs a TileMapLayer named Floor and one named Walls (see room_template.tscn).")
	if (size_tiles.x - door_tiles) % 2 != 0 or (size_tiles.y - door_tiles) % 2 != 0:
		warnings.append("Width and height minus the door width must be even, so doorways line up when the room is mirrored.")
	if walls:
		for side in range(4):
			if edges()[side] != Edge.DOOR:
				continue
			for cell in door_cells(side):
				if walls.get_cell_source_id(cell) != -1:
					warnings.append("The %s doorway has wall tiles in it: leave its %d middle border tiles empty." % [SIDE_NAMES[side], door_tiles])
					break
		var bounds := Rect2i(Vector2i.ZERO, size_tiles)
		for layer: TileMapLayer in [floor_layer(), walls]:
			if layer and not layer.get_used_cells().all(func(c): return bounds.has_point(c)):
				warnings.append("%s has tiles outside the room (%dx%d tiles from this node)." % [layer.name, size_tiles.x, size_tiles.y])
	if gated:
		if gate == &"":
			warnings.append("Semi-permanent rooms need a gate name, which events use to open them.")
		if edges().has(Edge.OPEN):
			warnings.append("Semi-permanent rooms cannot have open sides; they are used as doorways.")
		if not edges().has(Edge.DOOR) and not edges().has(Edge.OPEN):
			warnings.append("Semi-permanent room without a doorway: nobody can get in.")
	return warnings
