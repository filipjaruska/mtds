extends RefCounted
class_name LayoutPlanner
## Pure: places a map's rooms for one match and carves the corridors between
## them. The same input and seed give the same result on every machine.
## GameMap gathers the input from its MapRoom, RoomDoor, RoomSpot and RoomLink
## nodes and applies the result. Everything is in map tile cells.
##
## Input:
##   rooms: Array of {id: String, cells: {cell: true} (where it is painted),
##          anchor: Vector2i (its centre cell), group: StringName (swap group),
##          gated: bool, doors: Array of {cells: Array[Vector2i] (the doorway,
##          in order along the wall), facing: int (0 north, 1 east, 2 south, 3 west)}}
##   spots: {group: Array[Vector2i]}  more places a swap group's rooms may take
##   links: Array of {a: String, b: String, chance: float}
##   settings: {width: int (corridor width in tiles), turn_cost: float, padding: int}
## Result:
##   offsets: {id: Vector2i}  how far each room moved
##   floor, walls: {cell: true}  corridor tiles to paint
##   doors: {"id:index": OPEN or GATE}; doorways not listed are walled up
##   links: Array of [a, b, added: bool]  the links that got a corridor
##   ok: bool, problems: PackedStringArray

const STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OPEN := "open"
const GATE := "gate"
## Door pairs tried per link, closest first.
const PAIRS_PER_LINK := 6
## Room pairs tried when connecting an unreachable room.
const PAIRS_PER_REPAIR := 12
## Whole layouts tried before falling back to the painted places.
const PLAN_ATTEMPTS := 6
## Shuffles of the swap groups tried before keeping the painted places.
const SWAP_ATTEMPTS := 25
## A corridor search gives up after this many steps.
const MAX_STEPS := 120000

class Work:
	var width := 3
	var before := 1 # corridor cells on the low side of its centre line
	var after := 1
	var turn_cost := 3.0
	var rooms := {} # id -> {id, gated, cells, doors}
	var owner := {} # cell -> room id
	var blocked := {} # centre cells a corridor may not use
	var bounds := Rect2i()
	var floor_cells := {}
	var door_state := {}
	var door_use := {}
	var groups := {}
	var problems := PackedStringArray()
	var made: Array = []

static func plan(input: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# A layout that breaks a rule (a room no corridor reaches) is rolled again;
	# the last try keeps every room where it is painted.
	var result := {}
	for attempt in range(PLAN_ATTEMPTS):
		result = _plan_once(input, rng, attempt < PLAN_ATTEMPTS - 1)
		if result.ok:
			return result
	return result

static func _plan_once(input: Dictionary, rng: RandomNumberGenerator, swaps: bool) -> Dictionary:
	var settings: Dictionary = input.get("settings", {})
	var w := Work.new()
	w.width = maxi(int(settings.get("width", 3)), 1)
	@warning_ignore("integer_division")
	w.before = (w.width - 1) / 2
	w.after = w.width - 1 - w.before
	w.turn_cost = float(settings.get("turn_cost", 3.0))
	var rooms: Array = input.get("rooms", []).duplicate()
	rooms.sort_custom(func(x, y): return x.id < y.id)

	# Swap groups: the rooms of a group are shuffled between their own places
	# and the group's extra spots.
	var offsets := {}
	var by_group := {}
	for room in rooms:
		offsets[room.id] = Vector2i.ZERO
		if room.group != &"":
			by_group.get_or_add(room.group, []).append(room)
	var group_names: Array = by_group.keys()
	group_names.sort()
	var spots: Dictionary = input.get("spots", {})
	# Rooms of different sizes may not fit each other's places: shuffle again
	# until nothing overlaps (or keep the painted places).
	for attempt in range(SWAP_ATTEMPTS + 1 if swaps else 1):
		for group in group_names:
			var members: Array = by_group[group]
			var places: Array = members.map(func(r): return r.anchor)
			places.append_array(spots.get(group, []))
			if swaps and attempt < SWAP_ATTEMPTS:
				_shuffle(places, rng)
			for i in range(members.size()):
				offsets[members[i].id] = places[i] - members[i].anchor
		if not swaps or attempt == SWAP_ATTEMPTS or not _overlaps(rooms, offsets):
			break

	_place(w, rooms, offsets)
	var padding := int(settings.get("padding", 12)) + w.width
	if not w.owner.is_empty():
		var first: Vector2i = w.owner.keys()[0]
		var rect := Rect2i(first, Vector2i.ONE)
		for cell in w.owner:
			rect = rect.expand(cell).expand(cell + Vector2i.ONE)
		w.bounds = rect.grow(padding)
	for cell: Vector2i in w.owner:
		for x in range(cell.x - w.after, cell.x + w.before + 1):
			for y in range(cell.y - w.after, cell.y + w.before + 1):
				w.blocked[Vector2i(x, y)] = true

	# Drawn links, each rolled against its chance.
	var links: Array = input.get("links", []).duplicate()
	links.sort_custom(func(x, y): return x.a + "|" + x.b < y.a + "|" + y.b)
	for link in links:
		if not (w.rooms.has(link.a) and w.rooms.has(link.b)) or link.a == link.b:
			w.problems.append("a link between %s and %s does not join two rooms" % [link.a, link.b])
			continue
		if rng.randf() >= float(link.chance):
			continue
		if _connect(w, link.a, link.b):
			w.made.append([link.a, link.b, false])

	# Rooms the links left unreachable get the closest corridor that fits.
	var main: Array = rooms.filter(func(r): return not r.gated).map(func(r): return r.id)
	var tried := {}
	while main.size() > 1:
		var root := _root(w, main[0])
		var inside: Array = main.filter(func(id): return _root(w, id) == root)
		var outside: Array = main.filter(func(id): return _root(w, id) != root)
		if outside.is_empty():
			break
		var pairs: Array = []
		for x in inside:
			for y in outside:
				pairs.append([_room_distance(w, x, y), x, y])
		pairs.sort()
		var joined := false
		var attempts := 0
		for pair in pairs:
			var key: String = pair[1] + "|" + pair[2]
			if tried.has(key):
				continue
			tried[key] = true
			attempts += 1
			if _connect(w, pair[1], pair[2]):
				w.made.append([pair[1], pair[2], true])
				joined = true
				break
			if attempts >= PAIRS_PER_REPAIR:
				break
		if not joined:
			w.problems.append("no corridor fits to reach %s" % ", ".join(outside))
			break

	# Semi-permanent rooms need at least one way in (a gate) too.
	for room in rooms:
		if not room.gated or _has_open_door(w, room.id):
			continue
		var pairs: Array = []
		for other in main:
			pairs.append([_room_distance(w, room.id, other), other])
		pairs.sort()
		var joined := false
		for pair in pairs.slice(0, PAIRS_PER_REPAIR):
			if _connect(w, room.id, pair[1]):
				w.made.append([room.id, pair[1], true])
				joined = true
				break
		if not joined:
			w.problems.append("no corridor fits to reach the semi-permanent room %s" % room.id)

	var walls := {}
	for cell: Vector2i in w.floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var next := cell + Vector2i(dx, dy)
				if not w.floor_cells.has(next) and not w.owner.has(next):
					walls[next] = true
	return {"offsets": offsets, "floor": w.floor_cells, "walls": walls, "doors": w.door_state, "links": w.made,
		"ok": w.problems.is_empty(), "problems": w.problems}

static func door_key(id: String, index: int) -> String:
	return "%s:%d" % [id, index]

static func _overlaps(rooms: Array, offsets: Dictionary) -> bool:
	var taken := {}
	for room in rooms:
		var offset: Vector2i = offsets[room.id]
		for cell: Vector2i in room.cells:
			var moved := cell + offset
			if taken.has(moved):
				return true
			taken[moved] = true
	return false

static func _place(w: Work, rooms: Array, offsets: Dictionary) -> void:
	var overlaps := {}
	for room in rooms:
		var offset: Vector2i = offsets[room.id]
		var placed := {"id": room.id, "gated": room.gated, "cells": {}, "doors": []}
		for cell: Vector2i in room.cells:
			var moved := cell + offset
			if w.owner.has(moved) and w.owner[moved] != room.id:
				overlaps[[w.owner[moved], room.id]] = true
			w.owner[moved] = room.id
			placed.cells[moved] = true
		for door in room.doors:
			var cells: Array[Vector2i] = []
			for cell: Vector2i in door.cells:
				cells.append(cell + offset)
			placed.doors.append({"cells": cells, "facing": door.facing})
		w.rooms[room.id] = placed
		w.groups[room.id] = room.id
	for pair in overlaps:
		w.problems.append("%s and %s overlap" % pair)

# --- Corridors ---------------------------------------------------------------------------

## Carves a corridor between two rooms through their best free doorways.
static func _connect(w: Work, x: String, y: String) -> bool:
	var pairs: Array = []
	var doors_x: Array = w.rooms[x].doors
	var doors_y: Array = w.rooms[y].doors
	for i in range(doors_x.size()):
		for j in range(doors_y.size()):
			var used: int = w.door_use.get(door_key(x, i), 0) + w.door_use.get(door_key(y, j), 0)
			var distance := _manhattan(_start(w, doors_x[i]), _start(w, doors_y[j]))
			pairs.append([used, distance, i, j])
	pairs.sort()
	for pair in pairs.slice(0, PAIRS_PER_LINK):
		var a: Dictionary = doors_x[pair[2]]
		var b: Dictionary = doors_y[pair[3]]
		var cells: Variant = _straight(w, a, b)
		if cells == null:
			cells = _route(w, a, b)
		if cells == null:
			continue
		for cell: Vector2i in cells:
			if not w.owner.has(cell):
				w.floor_cells[cell] = true
		_use_door(w, x, pair[2])
		_use_door(w, y, pair[3])
		w.groups[_root(w, x)] = _root(w, y)
		return true
	return false

static func _use_door(w: Work, id: String, index: int) -> void:
	var key := door_key(id, index)
	w.door_use[key] = w.door_use.get(key, 0) + 1
	w.door_state[key] = GATE if w.rooms[id].gated else OPEN

static func _has_open_door(w: Work, id: String) -> bool:
	for i in range(w.rooms[id].doors.size()):
		if w.door_state.has(door_key(id, i)):
			return true
	return false

## The centre-line cell just outside a doorway where its corridor starts.
static func _start(w: Work, door: Dictionary) -> Vector2i:
	var middle: Vector2i = door.cells[mini(w.before, door.cells.size() - 1)]
	return middle + STEPS[door.facing] * (w.before + 1)

## The straight piece from a doorway out to its corridor start.
static func _stub(w: Work, door: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step in range(1, w.before + 2):
		for cell: Vector2i in door.cells:
			out.append(cell + STEPS[door.facing] * step)
	return out

## Two doorways facing each other across a gap: a straight corridor, or null.
static func _straight(w: Work, a: Dictionary, b: Dictionary) -> Variant:
	if (a.facing + 2) % 4 != b.facing or a.cells.size() != b.cells.size():
		return null
	var step: Vector2i = STEPS[a.facing]
	var gap: Vector2i = b.cells[0] - a.cells[0]
	var distance := gap.x * step.x + gap.y * step.y
	if distance < 1 or gap != step * distance:
		return null
	for i in range(a.cells.size()):
		if b.cells[i] - a.cells[i] != gap: # doorway cells are in order along the wall
			return null
	var out: Array[Vector2i] = []
	for along in range(1, distance):
		for cell: Vector2i in a.cells:
			var next := cell + step * along
			if w.owner.has(next):
				return null
			out.append(next)
	return out

## A corridor around rooms from one doorway to another, or null.
## Searches the corridor's centre line, preferring straight runs and corridors
## already carved, then widens it to the corridor width.
static func _route(w: Work, a: Dictionary, b: Dictionary) -> Variant:
	var start := _start(w, a)
	var goal := _start(w, b)
	for stub in [_stub(w, a), _stub(w, b)]:
		for cell in stub:
			if w.owner.has(cell):
				return null
	if w.blocked.has(start) or w.blocked.has(goal) or not w.bounds.has_point(start) or not w.bounds.has_point(goal):
		return null
	var line := _search(w, start, int(a.facing), goal)
	if line.is_empty():
		return null
	var out: Array[Vector2i] = []
	out.append_array(_stub(w, a))
	out.append_array(_stub(w, b))
	for centre in line:
		for x in range(centre.x - w.before, centre.x + w.after + 1):
			for y in range(centre.y - w.before, centre.y + w.after + 1):
				out.append(Vector2i(x, y))
	return out

## A* over (cell, heading); turning costs extra, so corridors run straight.
static func _search(w: Work, start: Vector2i, heading: int, goal: Vector2i) -> Array[Vector2i]:
	var width := w.bounds.size.x
	var origin := w.bounds.position
	var encode := func(cell: Vector2i, dir: int) -> int:
		return ((cell.y - origin.y) * width + (cell.x - origin.x)) * 4 + dir
	var heap: Array = []
	var cost := {}
	var came := {}
	var order := 0
	var first: int = encode.call(start, heading)
	cost[first] = 0.0
	_push(heap, [_manhattan(start, goal) * 0.5, order, first, start, heading])
	var steps := 0
	while not heap.is_empty() and steps < MAX_STEPS:
		steps += 1
		var item: Array = _pop(heap)
		var key: int = item[2]
		var cell: Vector2i = item[3]
		var dir: int = item[4]
		if cell == goal:
			var line: Array[Vector2i] = []
			var current = key
			while current != null:
				@warning_ignore("integer_division")
				var index: int = current / 4
				@warning_ignore("integer_division")
				var row: int = index / width
				line.append(Vector2i(index % width, row) + origin)
				current = came.get(current)
			line.reverse()
			return line
		if item[0] - _manhattan(cell, goal) * 0.5 > cost[key] + 0.0001:
			continue # a cheaper way here was found after this was queued
		for next_dir in range(4):
			if next_dir == (dir + 2) % 4:
				continue
			var next: Vector2i = cell + STEPS[next_dir]
			if next != goal and (w.blocked.has(next) or not w.bounds.has_point(next)):
				continue
			var step_cost := 0.5 if w.floor_cells.has(next) else 1.0
			if next_dir != dir:
				step_cost += w.turn_cost
			var next_key: int = encode.call(next, next_dir)
			var total: float = cost[key] + step_cost
			if total < cost.get(next_key, INF):
				cost[next_key] = total
				came[next_key] = key
				order += 1
				_push(heap, [total + _manhattan(next, goal) * 0.5, order, next_key, next, next_dir])
	return []

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent := (i - 1) / 2
		if not _before(heap[i], heap[parent]):
			break
		var tmp = heap[i]
		heap[i] = heap[parent]
		heap[parent] = tmp
		i = parent

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var smallest := i
			for child in [2 * i + 1, 2 * i + 2]:
				if child < heap.size() and _before(heap[child], heap[smallest]):
					smallest = child
			if smallest == i:
				break
			var tmp = heap[i]
			heap[i] = heap[smallest]
			heap[smallest] = tmp
			i = smallest
	return top

static func _before(x: Array, y: Array) -> bool:
	return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1])

# --- Helpers ----------------------------------------------------------------------------

static func _room_distance(w: Work, x: String, y: String) -> int:
	var best := 1 << 30
	for a in w.rooms[x].doors:
		for b in w.rooms[y].doors:
			best = mini(best, _manhattan(_start(w, a), _start(w, b)))
	return best

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

static func _root(w: Work, id: String) -> String:
	while w.groups[id] != id:
		id = w.groups[id]
	return id
