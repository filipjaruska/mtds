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
##   links: Array of {a: String, b: String, chance: float, width: int (0 = default)}
##   settings: {width: int (default corridor width in tiles), turn_cost: float,
##              padding: int, max_detour: float}
## Result:
##   offsets: {id: Vector2i}  how far each room moved
##   floor, walls: {cell: true}  corridor tiles to paint
##   doors: {"id:index": {state: OPEN or GATE, open: Array[int]}}: the doorway
##          tiles (by index) corridors lead into; every other doorway tile is
##          walled up, and doorways not listed are walled up entirely
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
## Tiles a corridor may run beyond max_detour x the straight distance (so short
## corridors may still bend round a corner).
const DETOUR_SLACK := 6

class Work:
	var width := 3 # default corridor width
	var turn_cost := 3.0
	var max_detour := 1.3
	var rooms := {} # id -> {id, gated, cells, doors}
	var owner := {} # cell -> room id
	var bounds := Rect2i()
	var floor_cells := {}
	# Flat grids over `bounds` for the corridor search: where a corridor's
	# centre line may not go (one per width), and corridor floor so far.
	var blocked_grids := {}
	var floor_grid := PackedByteArray()
	var door_state := {}
	var door_open := {} # door key -> {index: true}
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
	w.turn_cost = float(settings.get("turn_cost", 3.0))
	w.max_detour = float(settings.get("max_detour", 1.3))
	var rooms: Array = input.get("rooms", []).duplicate()
	rooms.sort_custom(func(x, y): return x.id < y.id)
	var links: Array = input.get("links", []).duplicate()
	links.sort_custom(func(x, y): return x.a + "|" + x.b < y.a + "|" + y.b)

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
	var widest := w.width
	for link in links:
		widest = maxi(widest, int(link.get("width", 0)))
	var padding := int(settings.get("padding", 12)) + widest
	if not w.owner.is_empty():
		var first: Vector2i = w.owner.keys()[0]
		var rect := Rect2i(first, Vector2i.ONE)
		for cell in w.owner:
			rect = rect.expand(cell).expand(cell + Vector2i.ONE)
		w.bounds = rect.grow(padding)
	w.floor_grid.resize(w.bounds.size.x * w.bounds.size.y)

	# Drawn links, each rolled against its chance. One whose corridor would be a
	# long way round is dropped: the closest rooms get connected instead.
	var dropped: Array = []
	for link in links:
		if not (w.rooms.has(link.a) and w.rooms.has(link.b)) or link.a == link.b:
			w.problems.append("a link between %s and %s does not join two rooms" % [link.a, link.b])
			continue
		if rng.randf() >= float(link.chance):
			continue
		var width: int = link.get("width", 0) if int(link.get("width", 0)) > 0 else w.width
		if _connect(w, link.a, link.b, width, true):
			w.made.append([link.a, link.b, false])
		else:
			dropped.append(link)
	# A dropped link is replaced by short corridors: each of its rooms joins
	# the nearest room it has no corridor to yet.
	for link in dropped:
		for id in [link.a, link.b]:
			if w.rooms[id].gated:
				continue
			var near: Array = []
			for other in w.rooms:
				if other != id and not w.rooms[other].gated and not _joined_directly(w, id, other):
					near.append([_room_distance(w, id, other), other])
			near.sort()
			for pair in near.slice(0, 3):
				if _connect(w, id, pair[1], w.width, true):
					w.made.append([id, pair[1], true])
					break

	# Rooms the links left unreachable get the closest corridor that fits:
	# a short one if possible, a long way round only if nothing else fits.
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
				var key: String = x + "|" + y
				if not tried.has(key):
					pairs.append([_room_distance(w, x, y), x, y])
		pairs.sort()
		pairs = pairs.slice(0, PAIRS_PER_REPAIR)
		var joined := false
		for limited in [true, false]:
			for pair in pairs:
				if _connect(w, pair[1], pair[2], w.width, limited):
					w.made.append([pair[1], pair[2], true])
					joined = true
					break
			if joined:
				break
		for pair in pairs:
			tried[pair[1] + "|" + pair[2]] = true
		if not joined and pairs.size() < PAIRS_PER_REPAIR:
			w.problems.append("no corridor fits to reach %s" % ", ".join(outside))
			break

	# Semi-permanent rooms need at least one way in (a gate) too.
	for room in rooms:
		if not room.gated or w.door_state.keys().any(func(k): return k.begins_with(room.id + ":")):
			continue
		var pairs: Array = []
		for other in main:
			pairs.append([_room_distance(w, room.id, other), other])
		pairs.sort()
		var joined := false
		for limited in [true, false]:
			for pair in pairs.slice(0, PAIRS_PER_REPAIR):
				if _connect(w, room.id, pair[1], w.width, limited):
					w.made.append([room.id, pair[1], true])
					joined = true
					break
			if joined:
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
	var doors := {}
	for key in w.door_state:
		var open: Array = w.door_open[key].keys()
		open.sort()
		doors[key] = {"state": w.door_state[key], "open": open}
	return {"offsets": offsets, "floor": w.floor_cells, "walls": walls, "doors": doors, "links": w.made,
		"ok": w.problems.is_empty(), "problems": w.problems}

static func _joined_directly(w: Work, x: String, y: String) -> bool:
	return w.made.any(func(l): return (l[0] == x and l[1] == y) or (l[0] == y and l[1] == x))

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

## Corridor cells on each side of its centre line: [before, after].
static func _halves(width: int) -> Array[int]:
	@warning_ignore("integer_division")
	var before := (width - 1) / 2
	return [before, width - 1 - before]

## Carves a corridor of `width` between two rooms through their best free
## doorways. `limited`: refuse corridors much longer than the straight distance.
static func _connect(w: Work, x: String, y: String, width: int, limited: bool) -> bool:
	var pairs: Array = []
	var doors_x: Array = w.rooms[x].doors
	var doors_y: Array = w.rooms[y].doors
	for i in range(doors_x.size()):
		for j in range(doors_y.size()):
			var used: int = w.door_use.get(door_key(x, i), 0) + w.door_use.get(door_key(y, j), 0)
			var distance := _manhattan(_start(doors_x[i], width), _start(doors_y[j], width))
			pairs.append([used, distance, i, j])
	pairs.sort()
	for pair in pairs.slice(0, PAIRS_PER_LINK):
		var a: Dictionary = doors_x[pair[2]]
		var b: Dictionary = doors_y[pair[3]]
		var cells: Variant = _straight(w, a, b, width)
		if cells == null:
			cells = _route(w, a, b, width, limited)
		if cells == null:
			continue
		for cell: Vector2i in cells:
			if not w.owner.has(cell):
				w.floor_cells[cell] = true
				if w.bounds.has_point(cell):
					w.floor_grid[_index(w, cell)] = 1
		_use_door(w, x, pair[2], width)
		_use_door(w, y, pair[3], width)
		w.groups[_root(w, x)] = _root(w, y)
		return true
	return false

static func _use_door(w: Work, id: String, index: int, width: int) -> void:
	var key := door_key(id, index)
	w.door_use[key] = w.door_use.get(key, 0) + 1
	w.door_state[key] = GATE if w.rooms[id].gated else OPEN
	var door: Dictionary = w.rooms[id].doors[index]
	var halves := _halves(width)
	@warning_ignore("integer_division")
	var centre: int = (door.cells.size() - 1) / 2
	var open: Dictionary = w.door_open.get_or_add(key, {})
	for i in range(door.cells.size()):
		if i - centre >= -halves[0] and i - centre <= halves[1]:
			open[i] = true

## The doorway's middle tile.
static func _centre(door: Dictionary) -> Vector2i:
	@warning_ignore("integer_division")
	return door.cells[(door.cells.size() - 1) / 2]

## Along the doorway (the direction its tiles are listed in).
static func _across(door: Dictionary) -> Vector2i:
	return Vector2i(1, 0) if door.facing == 0 or door.facing == 2 else Vector2i(0, 1)

## The centre-line cell just outside a doorway where its corridor starts.
static func _start(door: Dictionary, width: int) -> Vector2i:
	return _centre(door) + STEPS[door.facing] * (_halves(width)[0] + 1)

## The straight piece from a doorway out to its corridor start, `width` wide.
static func _stub(door: Dictionary, width: int) -> Array[Vector2i]:
	var halves := _halves(width)
	var out: Array[Vector2i] = []
	for step in range(1, halves[0] + 2):
		for k in range(-halves[0], halves[1] + 1):
			out.append(_centre(door) + _across(door) * k + STEPS[door.facing] * step)
	return out

## Two doorways facing each other across a gap: a straight corridor, or null.
static func _straight(w: Work, a: Dictionary, b: Dictionary, width: int) -> Variant:
	if (a.facing + 2) % 4 != b.facing:
		return null
	var step: Vector2i = STEPS[a.facing]
	var gap: Vector2i = _centre(b) - _centre(a)
	var distance := gap.x * step.x + gap.y * step.y
	if distance < 1 or gap != step * distance:
		return null
	var halves := _halves(width)
	var out: Array[Vector2i] = []
	for along in range(1, distance):
		for k in range(-halves[0], halves[1] + 1):
			var next := _centre(a) + _across(a) * k + step * along
			if w.owner.has(next):
				return null
			out.append(next)
	return out

## A corridor around rooms from one doorway to another, or null.
## Searches the corridor's centre line, preferring straight runs and corridors
## already carved, then widens it to `width`. `limited`: null when the
## corridor would be much longer than the straight distance (max_detour).
static func _route(w: Work, a: Dictionary, b: Dictionary, width: int, limited: bool) -> Variant:
	var start := _start(a, width)
	var goal := _start(b, width)
	var stubs := _stub(a, width) + _stub(b, width)
	for cell in stubs:
		if w.owner.has(cell):
			return null
	var blocked := _blocked_grid(w, width)
	if not w.bounds.has_point(start) or not w.bounds.has_point(goal):
		return null
	if blocked[_index(w, start)] == 1 or blocked[_index(w, goal)] == 1:
		return null
	var line := _search(w, blocked, start, int(a.facing), goal)
	if line.is_empty():
		return null
	var halves := _halves(width)
	if limited:
		var length := line.size() + 2 * (halves[0] + 1)
		if length > _manhattan(_centre(a), _centre(b)) * w.max_detour + DETOUR_SLACK:
			return null
	var out: Array[Vector2i] = stubs
	for centre in line:
		for x in range(centre.x - halves[0], centre.x + halves[1] + 1):
			for y in range(centre.y - halves[0], centre.y + halves[1] + 1):
				out.append(Vector2i(x, y))
	return out

## Where a corridor of `width` may not put its centre line: within reach of a room.
static func _blocked_grid(w: Work, width: int) -> PackedByteArray:
	if w.blocked_grids.has(width):
		return w.blocked_grids[width]
	var halves := _halves(width)
	var grid := PackedByteArray()
	grid.resize(w.bounds.size.x * w.bounds.size.y)
	for cell: Vector2i in w.owner:
		for x in range(cell.x - halves[1], cell.x + halves[0] + 1):
			for y in range(cell.y - halves[1], cell.y + halves[0] + 1):
				var near := Vector2i(x, y)
				if w.bounds.has_point(near):
					grid[_index(w, near)] = 1
	w.blocked_grids[width] = grid
	return grid

## A* over (cell, heading); turning costs extra, so corridors run straight.
## Works on flat arrays over the search bounds (dictionaries are much slower).
static func _search(w: Work, blocked: PackedByteArray, start: Vector2i, heading: int, goal: Vector2i) -> Array[Vector2i]:
	var width := w.bounds.size.x
	var origin := w.bounds.position
	var states := w.bounds.size.x * w.bounds.size.y * 4
	var cost := PackedFloat32Array()
	cost.resize(states)
	cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(states)
	came.fill(-1)
	var goal_index := _index(w, goal)
	var heap: Array = []
	var order := 0
	var first := _index(w, start) * 4 + heading
	cost[first] = 0.0
	_push(heap, [_manhattan(start, goal), order, first])
	var steps := 0
	while not heap.is_empty() and steps < MAX_STEPS:
		steps += 1
		var item: Array = _pop(heap)
		var key: int = item[2]
		@warning_ignore("integer_division")
		var index: int = key / 4
		var dir: int = key % 4
		@warning_ignore("integer_division")
		var cell := Vector2i(index % width, index / width) + origin
		if index == goal_index:
			var line: Array[Vector2i] = []
			var current := key
			while current != -1:
				@warning_ignore("integer_division")
				var at: int = current / 4
				@warning_ignore("integer_division")
				line.append(Vector2i(at % width, at / width) + origin)
				current = came[current]
			line.reverse()
			return line
		var here: float = cost[key]
		if item[0] - _manhattan(cell, goal) > here + 0.0001:
			continue # a cheaper way here was found after this was queued
		for next_dir in range(4):
			if next_dir == (dir + 2) % 4:
				continue
			var next: Vector2i = cell + STEPS[next_dir]
			if not w.bounds.has_point(next):
				continue
			var next_index := _index(w, next)
			if next_index != goal_index and blocked[next_index] == 1:
				continue
			var step_cost := 0.5 if w.floor_grid[next_index] == 1 else 1.0
			if next_dir != dir:
				step_cost += w.turn_cost
			var next_key := next_index * 4 + next_dir
			var total := here + step_cost
			if total < cost[next_key]:
				cost[next_key] = total
				came[next_key] = key
				order += 1
				# Full distance as the estimate: not always the cheapest corridor
				# (old ones cost less to reuse), but far fewer steps to find one.
				_push(heap, [total + _manhattan(next, goal), order, next_key])
	return []

static func _index(w: Work, cell: Vector2i) -> int:
	return (cell.y - w.bounds.position.y) * w.bounds.size.x + (cell.x - w.bounds.position.x)

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
			best = mini(best, _manhattan(_start(a, w.width), _start(b, w.width)))
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
