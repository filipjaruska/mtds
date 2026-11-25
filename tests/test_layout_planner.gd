extends "res://tests/test_case.gd"
## LayoutPlanner: which room goes where, turned how, with which doorways open.

const W := LayoutPlanner.Edge.WALL
const D := LayoutPlanner.Edge.DOOR
const O := LayoutPlanner.Edge.OPEN

func _choice(key: String, edges: Array, extra: Dictionary = {}) -> Dictionary:
	var c := {"key": key, "weight": 1.0, "max": 0, "edges": edges, "gated": false, "spawns": 1}
	c.merge(extra, true)
	return c

func _slot(cell: Vector2i, choices: Array, extra: Dictionary = {}) -> Dictionary:
	var s := {"cell": cell, "choices": choices, "empty_chance": 0.0, "rotate": true, "flip": true, "required": false, "square": true}
	s.merge(extra, true)
	return s

func _grid(w: int, h: int, choices: Array) -> Array:
	var out: Array = []
	for y in range(h):
		for x in range(w):
			out.append(_slot(Vector2i(x, y), choices))
	return out

## Rooms reachable from `start` through open doorways.
func _reachable(plan: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for side in range(4):
			var next: Vector2i = cell + LayoutPlanner.STEPS[side]
			if plan.rooms.has(next) and not seen.has(next) and plan.sides.get(LayoutPlanner.side_key(cell, side)) == LayoutPlanner.Side.OPEN:
				seen[next] = true
				todo.append(next)
	return seen

func test_sides_turn_and_mirror_back() -> void:
	for rot in range(4):
		for flip in [false, true]:
			for side in range(4):
				check_eq(LayoutPlanner.own_side(LayoutPlanner.map_side(side, rot, flip), rot, flip), side)
	check_eq(LayoutPlanner.map_side(0, 1, false), 1, "a quarter turn puts north east")
	check_eq(LayoutPlanner.map_side(1, 0, true), 3, "mirroring swaps east and west")
	check_eq(LayoutPlanner.map_side(0, 0, true), 0, "mirroring keeps north")

func test_same_seed_same_plan() -> void:
	var slots := _grid(4, 3, [_choice("a", [D, D, D, D]), _choice("b", [D, W, D, W])])
	var a := LayoutPlanner.plan(slots, 42, 0.3)
	var b := LayoutPlanner.plan(slots, 42, 0.3)
	check_eq(var_to_str(a), var_to_str(b))
	var others := 0
	for seed_value in range(1, 20):
		if var_to_str(LayoutPlanner.plan(slots, seed_value, 0.3)) != var_to_str(a):
			others += 1
	check(others > 10, "other seeds give other layouts (%d of 19)" % others)

func test_every_room_is_reachable() -> void:
	var slots := _grid(4, 4, [_choice("cross", [D, D, D, D]), _choice("corner", [D, D, W, W]), _choice("line", [D, W, D, W])])
	for seed_value in range(30):
		var plan := LayoutPlanner.plan(slots, seed_value, 0.0)
		check(plan.ok, "seed %d: %s" % [seed_value, plan.problems])
		check_eq(_reachable(plan, plan.rooms.keys()[0]).size(), plan.rooms.size(), "seed %d: all rooms connected" % seed_value)

func test_doorways_to_nowhere_are_sealed() -> void:
	var plan := LayoutPlanner.plan([_slot(Vector2i.ZERO, [_choice("a", [D, D, D, D])])], 1, 1.0)
	for side in range(4):
		check_eq(plan.sides[LayoutPlanner.side_key(Vector2i.ZERO, side)], LayoutPlanner.Side.SEALED)

func test_open_blocks_always_join() -> void:
	var slots := [_slot(Vector2i(0, 0), [_choice("block", [O, O, O, O])]), _slot(Vector2i(1, 0), [_choice("block", [O, O, O, O])])]
	var plan := LayoutPlanner.plan(slots, 3, 0.0)
	check_eq(plan.sides[LayoutPlanner.side_key(Vector2i(0, 0), 1)], LayoutPlanner.Side.OPEN)
	check_eq(plan.sides[LayoutPlanner.side_key(Vector2i(1, 0), 3)], LayoutPlanner.Side.OPEN)
	check_eq(plan.sides[LayoutPlanner.side_key(Vector2i(0, 0), 3)], LayoutPlanner.Side.SEALED, "open edge at the map's border is walled")

func test_required_empty_and_max_per_map() -> void:
	var once := _choice("once", [D, D, D, D], {"max": 1})
	var slots := [
		_slot(Vector2i(0, 0), [once], {"required": true}),
		_slot(Vector2i(1, 0), [once, _choice("other", [D, D, D, D])]),
		_slot(Vector2i(2, 0), [_choice("other", [D, D, D, D])], {"empty_chance": 1.0}),
	]
	for seed_value in range(10):
		var plan := LayoutPlanner.plan(slots, seed_value, 0.5)
		check(plan.rooms.has(Vector2i(0, 0)), "required slot filled")
		check_eq(plan.rooms[Vector2i(0, 0)].choice.key, "once")
		check_eq(plan.rooms[Vector2i(1, 0)].choice.key, "other", "max 1 per map")
		check(not plan.rooms.has(Vector2i(2, 0)), "empty chance 1 stays empty")

func test_semi_permanent_room_gets_gates_only() -> void:
	var gated := _choice("table", [D, D, D, D], {"gated": true, "spawns": 0})
	var slots := _grid(3, 3, [_choice("room", [D, D, D, D])])
	slots[4] = _slot(Vector2i(1, 1), [gated], {"required": true})
	for seed_value in range(15):
		var plan := LayoutPlanner.plan(slots, seed_value, 0.3)
		check(plan.ok, "seed %d: %s" % [seed_value, plan.problems])
		var gates := 0
		for side in range(4):
			var state: int = plan.sides[LayoutPlanner.side_key(Vector2i(1, 1), side)]
			check(state != LayoutPlanner.Side.OPEN, "no open way into a closed room")
			if state == LayoutPlanner.Side.GATE:
				gates += 1
		check(gates >= 1, "seed %d: at least one gate" % seed_value)
		var outside: Array = plan.rooms.keys().filter(func(c): return c != Vector2i(1, 1))
		check_eq(_reachable(plan, outside[0]).size(), outside.size(), "the rest connects without the closed room")

func test_too_few_spawn_points_is_a_problem() -> void:
	var plan := LayoutPlanner.plan(_grid(2, 1, [_choice("a", [D, D, D, D])]), 1, 0.3, 5)
	check(not plan.ok)
	check(plan.problems[0].contains("spawn"), str(plan.problems))
