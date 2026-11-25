@tool
extends Node2D
class_name MapRoom
## A room of a map, painted in place inside the map scene: its own Floor and
## Walls tile layers, of any size and shape, plus anything a map can hold
## (SpawnPoints, WeaponSpawners, PowerupSpawners...). Put the node on the tile
## grid (a position that is a multiple of 64).
##
## Each match the map (GameMap) may move it and carves corridors to it:
##   - RoomDoor children mark its doorways: gaps in its border wall where a
##     corridor may attach. Doorways no corridor uses are walled up.
##   - Rooms with the same swap group trade places with each other (and with
##     the group's RoomSpots).
##   - RoomLinks between rooms say which ones get a corridor between them.
##
## Semi-permanent rooms (`gated`) start closed: their used doorways get gates
## that open when an event calls GameMap.set_gate_open(gate, true). Nobody
## spawns in them while they are closed.

const TILE := 64

## Rooms with the same swap group trade places each match. Empty: stays put.
@export var swap_group: StringName = &"":
	set(value):
		swap_group = value
		_changed()
@export_group("Semi-permanent")
## Closed until an event opens it (the blackjack room, for example).
@export var gated: bool = false:
	set(value):
		gated = value
		_changed()
## Name events use to open it (GameMap.set_gate_open).
@export var gate: StringName = &"":
	set(value):
		gate = value
		_changed()
@export_group("Sealing")
## The wall tile used to wall up unused doorways: tile set source id and atlas coords.
@export var seal_source_id: int = 2
@export var seal_atlas_coords: Vector2i = Vector2i.ZERO

## Gates placed in this room's doorways by the layout.
var gates: Array[RoomGate] = []
var opened := false

func floor_layer() -> TileMapLayer:
	return get_node_or_null("Floor") as TileMapLayer

func walls_layer() -> TileMapLayer:
	return get_node_or_null("Walls") as TileMapLayer

func doors() -> Array[RoomDoor]:
	var out: Array[RoomDoor] = []
	for node in find_children("*", "RoomDoor", true, false):
		out.append(node)
	return out

## Closed semi-permanent room: no spawning here, no way in.
func is_closed() -> bool:
	return gated and not opened

func set_gates_open(open: bool) -> void:
	opened = open
	for g in gates:
		g.set_open(open)

## Tiles the room takes up, in its own tile coordinates.
func cells() -> Dictionary:
	var out := {}
	for layer in [floor_layer(), walls_layer()]:
		if layer == null:
			continue
		var shift := Vector2i((layer.position / TILE).round())
		for cell in layer.get_used_cells():
			out[cell + shift] = true
	return out

func used_rect() -> Rect2i:
	var all := cells()
	if all.is_empty():
		return Rect2i()
	var first: Vector2i = all.keys()[0]
	var rect := Rect2i(first, Vector2i.ONE)
	for cell in all:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect

# --- Applying a layout ---------------------------------------------------------------

func seal_door(door: RoomDoor, width: int) -> void:
	var walls := walls_layer()
	if walls == null:
		return
	for cell in door.cells(width):
		walls.set_cell(cell, seal_source_id, seal_atlas_coords)

func add_gate(door: RoomDoor, width: int) -> void:
	var gap := door.cells(width)
	var rect := Rect2(Vector2(gap[0]) * TILE, Vector2(TILE, TILE))
	for cell in gap:
		rect = rect.merge(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))
	var g := RoomGate.create(rect)
	g.name = "Gate_%s" % door.name
	add_child(g)
	gates.append(g)

## Facts the map checks use.
func summary() -> Dictionary:
	var spawns := 0
	var weapons := {}
	for node in find_children("*", "", true, false):
		if node is SpawnPoint or node.is_in_group("PlayerSpawnLocation"):
			spawns += 1
		elif node is WeaponSpawner and node.weapon_def:
			weapons[node.weapon_def.id] = weapons.get(node.weapon_def.id, 0) + 1
	return {"gated": gated, "spawns": spawns, "weapons": weapons}

# --- Editor ---------------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()

func _changed() -> void:
	if is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := used_rect()
	if rect.size == Vector2i.ZERO:
		return
	var box := Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE)
	var color := Color(1.0, 0.6, 0.15) if gated else (Color(0.55, 0.75, 1.0) if swap_group != &"" else Color(1, 1, 1, 0.6))
	draw_rect(box, color, false, 4.0)
	var label := String(name)
	if swap_group != &"":
		label += "  ⇄ " + swap_group
	if gated:
		label += "  ·  semi-permanent (%s)" % gate
	draw_string(ThemeDB.fallback_font, box.position + Vector2(8, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if floor_layer() == null or walls_layer() == null:
		warnings.append("Needs a TileMapLayer named Floor and one named Walls, painted where the room is.")
	if not (position / TILE).is_equal_approx((position / TILE).round()):
		warnings.append("Not on the tile grid: its position must be a multiple of %d." % TILE)
	if doors().is_empty():
		warnings.append("No doorways: add RoomDoor nodes where corridors may attach.")
	if gated and gate == &"":
		warnings.append("Semi-permanent rooms need a gate name, which events use to open them.")
	return warnings
