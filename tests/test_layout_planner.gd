extends "res://tests/test_case.gd"
## LayoutPlanner: where rooms go and the corridors between them.

const N := 0
const E := 1
const S := 2
const W := 3

## A box-shaped room with 3-tile doorways in the middle of the given sides.
func _room(id: String, origin: Vector2i, size: Vector2i, facings: Array, extra: Dictionary = {}) -> Dictionary:
	var cells := {}
	for x in range(size.x):
		for y in range(size.y):
			cells[origin + Vector2i(x, y)] = true
	var doors: Array = []
	for facing in facings:
		var door: Array[Vector2i] = []
		var along := size.x if facing == N or facing == S else size.y
		@warning_ignore("integer_division")
		var start := (along - 3) / 2
		for i in range(3):
			match facing:
				N:
					door.append(origin + Vector2i(start + i, 0))
				S:
					door.append(origin + Vector2i(start + i, size.y - 1))
				E:
					door.append(origin + Vector2i(size.x - 1, start + i))
				W:
					door.append(origin + Vector2i(0, start + i))
		doors.append({"cells": door, "facing": facing})
	var room := {"id": id, "cells": cells, "anchor": origin + size / 2, "group": &"", "gated": false, "doors": doors}
	room.merge(extra, true)
	return room

func _input(rooms: Array, links: Array = [], spots: Dictionary = {}) -> Dictionary:
	return {"rooms": rooms, "links": links, "spots": spots, "settings": {"width": 3, "turn_cost": 3.0, "padding": 10, "max_detour": 1.6}}

func _link(a: String, b: String, chance := 1.0, width := 0) -> Dictionary:
	return {"a": a, "b": b, "chance": chance, "width": width}

## Rooms reachable from `start` walking over room tiles and corridor floor.
func _reachable(input: Dictionary, plan: Dictionary, start: String) -> Dictionary:
	var owner := {}
	for room in input.rooms:
		for cell in room.cells:
			owner[cell + plan.offsets[room.id]] = room.id
	var walkable: Dictionary = plan.floor.duplicate()
	for cell in owner:
		walkable[cell] = true
	var first: Vector2i = owner.keys().filter(func(c): return owner[c] == start)[0]
	var seen := {first: true}
	var todo: Array = [first]
	var rooms := {}
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		if owner.has(cell):
			rooms[owner[cell]] = true
		for step in LayoutPlanner.STEPS:
			var next: Vector2i = cell + step
			if walkable.has(next) and not seen.has(next):
				seen[next] = true
				todo.append(next)
	return rooms

func test_straight_corridor_between_facing_doorways() -> void:
	var input := _input([_room("a", Vector2i(0, 0), Vector2i(9, 9), [E, S]), _room("b", Vector2i(15, 0), Vector2i(9, 9), [W])], [_link("a", "b")])
	var plan := LayoutPlanner.plan(input, 1)
	check(plan.ok, str(plan.problems))
	check_eq(plan.floor.size(), 3 * 6, "a 3-wide corridor across the 6-tile gap")
	check(plan.floor.has(Vector2i(9, 4)) and plan.floor.has(Vector2i(14, 4)), "straight across")
	check_eq(plan.doors[LayoutPlanner.door_key("a", 0)].state, LayoutPlanner.OPEN)
	check_eq(plan.doors[LayoutPlanner.door_key("b", 0)].open, [0, 1, 2], "the whole doorway is open")
	check(not plan.doors.has(LayoutPlanner.door_key("a", 1)), "the unused doorway is walled up")

func test_corridor_goes_around_a_room() -> void:
	var rooms := [
		_room("a", Vector2i(0, 0), Vector2i(9, 9), [E]),
		_room("block", Vector2i(14, -4), Vector2i(8, 17), [N]),
		_room("c", Vector2i(28, 0), Vector2i(9, 9), [W]),
	]
	var input := _input(rooms, [_link("a", "c"), _link("block", "c")])
	var plan := LayoutPlanner.plan(input, 2)
	check(plan.ok, str(plan.problems))
	for room in rooms:
		for cell in room.cells:
			check(not plan.floor.has(cell) and not plan.walls.has(cell), "corridors never cut into %s" % room.id)
	check(_reachable(input, plan, "a").has("c"), "a reaches c")

func test_unlinked_rooms_are_connected_anyway() -> void:
	var input := _input([
		_room("a", Vector2i(0, 0), Vector2i(9, 9), [E, S]),
		_room("b", Vector2i(20, 0), Vector2i(9, 9), [W, S]),
		_room("c", Vector2i(10, 20), Vector2i(9, 9), [N, E, W]),
	], [_link("a", "b", 0.0)])
	for seed_value in range(5):
		var plan := LayoutPlanner.plan(input, seed_value)
		check(plan.ok, "seed %d: %s" % [seed_value, plan.problems])
		check_eq(_reachable(input, plan, "a").size(), 3, "seed %d: every room reachable" % seed_value)
		check(plan.links.all(func(l): return l[2]), "the 0%% link never comes; the corridors are added ones")

func test_link_chance() -> void:
	var input := _input([_room("a", Vector2i(0, 0), Vector2i(9, 9), [E, S]), _room("b", Vector2i(15, 0), Vector2i(9, 9), [W, S])],
		[_link("a", "b"), _link("a", "b", 0.5)])
	var doubled := 0
	for seed_value in range(40):
		var plan := LayoutPlanner.plan(input, seed_value)
		if plan.links.size() == 2:
			doubled += 1
	check(doubled > 5 and doubled < 35, "the 50%% link came %d times in 40" % doubled)

func test_swap_group_trades_places() -> void:
	var rooms := [
		_room("a", Vector2i(0, 0), Vector2i(9, 9), [E], {"group": &"g"}),
		_room("b", Vector2i(30, 0), Vector2i(9, 9), [W], {"group": &"g"}),
		_room("hub", Vector2i(15, 0), Vector2i(9, 9), [E, W]),
	]
	var input := _input(rooms, [_link("a", "hub"), _link("b", "hub")], {&"g": [Vector2i(19, 25)]})
	var moved := {}
	for seed_value in range(30):
		var plan := LayoutPlanner.plan(input, seed_value)
		check(plan.ok, "seed %d: %s" % [seed_value, plan.problems])
		check_eq(plan.offsets["hub"], Vector2i.ZERO, "rooms outside the group stay")
		moved[plan.offsets["a"]] = true
		check(plan.offsets["a"] != plan.offsets["b"] + Vector2i(30, 0) or plan.offsets["a"] == plan.offsets["b"], "two rooms never share a place")
	check_eq(moved.size(), 3, "a lands on each of the three places")
	check_eq(var_to_str(LayoutPlanner.plan(input, 7)), var_to_str(LayoutPlanner.plan(input, 7)), "same seed, same layout")

func test_semi_permanent_room_gets_a_gate() -> void:
	var input := _input([
		_room("a", Vector2i(0, 0), Vector2i(9, 9), [E]),
		_room("table", Vector2i(15, 0), Vector2i(9, 9), [W, S], {"gated": true}),
		_room("c", Vector2i(15, 15), Vector2i(9, 9), [N, W]),
	], [_link("a", "c")])
	var plan := LayoutPlanner.plan(input, 3)
	check(plan.ok, str(plan.problems))
	var states: Array = [plan.doors.get(LayoutPlanner.door_key("table", 0), {}).get("state"), plan.doors.get(LayoutPlanner.door_key("table", 1), {}).get("state")]
	check(states.has(LayoutPlanner.GATE), "a gate into the closed room: %s" % [states])
	check(not states.has(LayoutPlanner.OPEN), "never an open way in")

func test_overlapping_rooms_are_a_problem() -> void:
	var plan := LayoutPlanner.plan(_input([_room("a", Vector2i(0, 0), Vector2i(9, 9), [E]), _room("b", Vector2i(5, 5), Vector2i(9, 9), [W])]), 1)
	check(not plan.ok)
	check(str(plan.problems).contains("overlap"), str(plan.problems))

func test_long_way_round_is_dropped_for_closer_rooms() -> void:
	# a's only doorway faces away from c: the a-c corridor would loop round a
	# long way. The link is dropped and a gets a short corridor to b instead.
	var rooms := [
		_room("a", Vector2i(0, 0), Vector2i(9, 9), [W]),
		_room("b", Vector2i(-14, 0), Vector2i(9, 9), [E, S]),
		_room("c", Vector2i(30, 0), Vector2i(9, 9), [W, S]),
	]
	var input := _input(rooms, [_link("a", "c")])
	input.settings.max_detour = 1.0
	var plan := LayoutPlanner.plan(input, 1)
	check(plan.ok, str(plan.problems))
	check(not plan.links.any(func(l): return l[0] == "a" and l[1] == "c" and not l[2]), "the long a-c corridor is not carved")
	check(plan.links.any(func(l): return "a" in [l[0], l[1]] and "b" in [l[0], l[1]]), "a joins its neighbour b: %s" % [plan.links])
	check_eq(_reachable(input, plan, "a").size(), 3, "every room still reachable")
	input.settings.max_detour = 5.0
	var relaxed := LayoutPlanner.plan(input, 1)
	check(relaxed.links.any(func(l): return l[0] == "a" and l[1] == "c" and not l[2]), "with a high Max Detour the link stays")

func test_link_width_and_wide_doorways() -> void:
	var wide := _room("b", Vector2i(15, 0), Vector2i(9, 9), [W])
	# A 5-tile doorway on b; the corridor is only 3 wide.
	wide.doors[0].cells = [Vector2i(15, 2), Vector2i(15, 3), Vector2i(15, 4), Vector2i(15, 5), Vector2i(15, 6)]
	var input := _input([_room("a", Vector2i(0, 0), Vector2i(9, 9), [E]), wide], [_link("a", "b")])
	var plan := LayoutPlanner.plan(input, 1)
	check_eq(plan.doors[LayoutPlanner.door_key("b", 0)].open, [1, 2, 3], "the middle 3 tiles stay open, the rest is walled up")
	var five := LayoutPlanner.plan(_input([_room("a", Vector2i(0, 0), Vector2i(9, 9), [E]), _room("b", Vector2i(15, 0), Vector2i(9, 9), [W])], [_link("a", "b", 1.0, 5)]), 1)
	check_eq(five.floor.size(), 5 * 6, "a 5-wide corridor across the 6-tile gap")
