@tool
extends Node2D
## Editor only: draws one layout of a map over it (GameMap's preview button):
## where every room lands, the corridors, and which doorways stay open.
## Never saved with the scene.

const TILE := 64

## {room: MapRoom, offset: Vector2i}
var placed: Array = []
var plan: Dictionary = {}
## [{cell: Vector2i, state: String}] doorway tiles in map cells
var doors: Array = []

func _ready() -> void:
	z_index = 100

func _draw() -> void:
	if plan.is_empty():
		return
	var shade := Color(0.05, 0.05, 0.08, 0.82)
	var bounds := Rect2()
	for entry in placed:
		var rect: Rect2i = entry.rect
		var box := Rect2(Vector2(rect.position + entry.offset) * TILE, Vector2(rect.size) * TILE)
		bounds = box if bounds.size == Vector2.ZERO else bounds.merge(box)
	for cell in plan.walls:
		bounds = bounds.merge(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))
	draw_rect(bounds.grow(TILE * 4), shade)
	for cell in plan.floor:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), Color(0.55, 0.5, 0.42))
	for cell in plan.walls:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), Color(0.18, 0.16, 0.2))
	for entry in placed:
		var color := Color(1.0, 0.6, 0.15) if entry.room.gated else Color(0.55, 0.75, 1.0)
		for cell in entry.cells:
			draw_rect(Rect2(Vector2(cell + entry.offset) * TILE, Vector2(TILE, TILE)), Color(color, 0.35))
		var rect: Rect2i = entry.rect
		var box := Rect2(Vector2(rect.position + entry.offset) * TILE, Vector2(rect.size) * TILE)
		draw_rect(box, color, false, 6.0)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(12, 44), String(entry.room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	for door in doors:
		var color := Color(0.3, 1.0, 0.45)
		if door.state == "":
			color = Color(1.0, 0.3, 0.3)
		elif door.state == LayoutPlanner.GATE:
			color = Color(1.0, 0.6, 0.15)
		draw_rect(Rect2(Vector2(door.cell) * TILE, Vector2(TILE, TILE)).grow(-6), color)
