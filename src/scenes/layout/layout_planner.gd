extends RefCounted
class_name LayoutPlanner
## Pure: decides which room goes in each slot of a slot map, how it is turned,
## and which doorways between rooms are open. The same slots and seed give the
## same plan on every machine. GameMap turns a plan into rooms.
##
## Sides are numbered clockwise: 0 north, 1 east, 2 south, 3 west.
##
## A slot (input):
##   {cell: Vector2i, square: bool, rotate: bool, flip: bool, required: bool,
##    empty_chance: float, choices: Array of choice}
## A choice: {key: String, weight: float, max: int (0 = no limit),
##            edges: [4 x Edge, local sides], gated: bool, spawns: int}
##
## A plan (output):
##   rooms: {cell: {choice, rot (0..3 quarter turns clockwise), flip (mirror
##           east-west, applied before turning), edges: [4 x Edge, map sides]}}
##   sides: {"x,y,side": Side} for every side of every room (map sides)
##   ok: bool, problems: PackedStringArray, spawns: int

enum Edge { WALL, DOOR, OPEN }
## What happens to one side of a room:
##   NONE   a wall side; nothing to do
##   OPEN   the doorway (or open edge) leads into the neighbour
##   SEALED the doorway is walled up (an open edge is walled along its length)
##   GATE   a gate goes in the doorway (semi-permanent rooms)
enum Side { NONE, OPEN, SEALED, GATE }

const STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## A plan that breaks a rule is rerolled (with the same random stream) this often.
const ATTEMPTS := 40

## The map side a room's own side ends up on.
static func map_side(own_side: int, rot: int, flip: bool) -> int:
	var side := own_side
	if flip and side % 2 == 1:
		side = 4 - side # east <-> west
	return (side + rot) % 4

## The room's own side that ends up on a map side.
static func own_side(side: int, rot: int, flip: bool) -> int:
	var own := posmod(side - rot, 4)
	if flip and own % 2 == 1:
		own = 4 - own
	return own

static func side_key(cell: Vector2i, side: int) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, side]

## `min_spawns`: player spawn points the rooms must offer in total (outside
## semi-permanent rooms). `extra_door_chance`: chance for each doorway that is
## not needed to connect the map to be open anyway.
static func plan(slots: Array, seed_value: int, extra_door_chance: float, min_spawns: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sorted := slots.duplicate()
	sorted.sort_custom(func(a, b): return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	var result := {}
	for attempt in range(ATTEMPTS):
		result = _attempt(sorted, rng, extra_door_chance, min_spawns)
		if result.ok:
			return result
	return result

static func _attempt(slots: Array, rng: RandomNumberGenerator, extra_door_chance: float, min_spawns: int) -> Dictionary:
	var problems := PackedStringArray()
	var rooms := {}
	var used := {}
	var spawns := 0
	for slot in slots:
		if not slot.required and rng.randf() < slot.empty_chance:
			continue
		var options: Array = slot.choices.filter(func(c): return c.max <= 0 or used.get(c.key, 0) < c.max)
		if options.is_empty():
			if slot.required:
				problems.append("slot at %s has no room left to use" % [slot.cell])
			continue
		var choice: Dictionary = _weighted(options, rng)
		used[choice.key] = used.get(choice.key, 0) + 1
		rooms[slot.cell] = {"choice": choice, "slot": slot}
		if not choice.gated:
			spawns += int(choice.get("spawns", 0))
	# Turn each room so that as many of its doorways as possible lead into a
	# neighbouring room (ties picked at random), so few layouts need a reroll.
	for cell in rooms:
		var placed: Dictionary = rooms[cell]
		var slot: Dictionary = placed.slot
		var turns: Array = [0]
		if slot.rotate:
			turns = [0, 1, 2, 3] if slot.square else [0, 2]
		var orientations: Array = []
		for rot in turns:
			orientations.append([rot, false])
			if slot.flip:
				orientations.append([rot, true])
		_shuffle(orientations, rng)
		var best_score := -1
		for orientation in orientations:
			var edges := _turned_edges(placed.choice, orientation[0], orientation[1])
			var score := 0
			for side in range(4):
				if edges[side] != Edge.WALL and rooms.has(cell + STEPS[side]):
					score += 1
			if score > best_score:
				best_score = score
				placed.rot = orientation[0]
				placed.flip = orientation[1]
				placed.edges = edges
		placed.erase("slot")
	if rooms.is_empty():
		problems.append("no rooms were placed")
	if spawns < min_spawns:
		problems.append("only %d spawn points, %d needed" % [spawns, min_spawns])

	var sides := {}
	var groups := {} # union-find over rooms that are not semi-permanent
	for cell in rooms:
		groups[cell] = cell
	var candidates: Array = []
	var gate_candidates := {} # gated cell -> [[cell, side], ...]
	for cell in rooms:
		for side in range(4):
			var kind: int = rooms[cell].edges[side]
			var other: Vector2i = cell + STEPS[side]
			if not rooms.has(other):
				sides[side_key(cell, side)] = Side.NONE if kind == Edge.WALL else Side.SEALED
				continue
			if side == 0 or side == 3:
				continue # each pair once, from its north-west room
			var back := (side + 2) % 4
			var other_kind: int = rooms[other].edges[back]
			sides[side_key(cell, side)] = Side.NONE if kind == Edge.WALL else Side.SEALED
			sides[side_key(other, back)] = Side.NONE if other_kind == Edge.WALL else Side.SEALED
			if kind == Edge.WALL or other_kind == Edge.WALL:
				continue
			var gated_a: bool = rooms[cell].choice.gated
			var gated_b: bool = rooms[other].choice.gated
			if gated_a and gated_b:
				continue
			if gated_a or gated_b:
				var gated_cell: Vector2i = cell if gated_a else other
				gate_candidates.get_or_add(gated_cell, []).append([cell, side])
			elif kind == Edge.OPEN and other_kind == Edge.OPEN:
				_join(groups, cell, other) # open blocks always run into each other
				sides[side_key(cell, side)] = Side.OPEN
				sides[side_key(other, back)] = Side.OPEN
			else:
				candidates.append([cell, side])
	_shuffle(candidates, rng)
	for pair in candidates:
		var cell: Vector2i = pair[0]
		var other: Vector2i = cell + STEPS[pair[1]]
		var needed := _root(groups, cell) != _root(groups, other)
		if needed or rng.randf() < extra_door_chance:
			_join(groups, cell, other)
			_open(sides, cell, pair[1], Side.OPEN)
	for gated_cell in gate_candidates:
		var options: Array = gate_candidates[gated_cell]
		_shuffle(options, rng)
		for i in range(options.size()):
			if i == 0 or rng.randf() < extra_door_chance:
				_open(sides, options[i][0], options[i][1], Side.GATE)
	# Every room outside the semi-permanent ones must be reachable.
	var root = null
	for cell in rooms:
		if rooms[cell].choice.gated:
			if not gate_candidates.has(cell):
				problems.append("semi-permanent room at %s has no way in" % [cell])
			continue
		if root == null:
			root = _root(groups, cell)
		elif _root(groups, cell) != root:
			problems.append("room at %s cannot be reached" % [cell])
			break
	return {"rooms": rooms, "sides": sides, "ok": problems.is_empty(), "problems": problems, "spawns": spawns}

## A choice's sides on the map after turning and mirroring.
static func _turned_edges(choice: Dictionary, rot: int, flip: bool) -> Array:
	var edges := [Edge.WALL, Edge.WALL, Edge.WALL, Edge.WALL]
	for own in range(4):
		var kind: int = choice.edges[own]
		if choice.gated and kind == Edge.OPEN:
			kind = Edge.DOOR # semi-permanent rooms close every way in
		edges[map_side(own, rot, flip)] = kind
	return edges

## Opens the doorway between `cell` and its neighbour on `side`, both ways.
static func _open(sides: Dictionary, cell: Vector2i, side: int, state: int) -> void:
	sides[side_key(cell, side)] = state
	sides[side_key(cell + STEPS[side], (side + 2) % 4)] = state

static func _weighted(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for option in options:
		total += maxf(option.weight, 0.0)
	if total <= 0.0:
		return options[0]
	var pick := rng.randf() * total
	for option in options:
		pick -= maxf(option.weight, 0.0)
		if pick < 0.0:
			return option
	return options[-1]

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

static func _root(groups: Dictionary, cell: Vector2i) -> Vector2i:
	while groups[cell] != cell:
		cell = groups[cell]
	return cell

static func _join(groups: Dictionary, a: Vector2i, b: Vector2i) -> void:
	groups[_root(groups, a)] = _root(groups, b)
