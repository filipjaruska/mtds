extends "res://tests/test_case.gd"

func _inv(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		out.append({"def": e[0], "count": e[1]})
	return out

func test_fan_is_symmetric() -> void:
	var left := HandLayout.slot_transform(0, 4, &"normal")
	var right := HandLayout.slot_transform(3, 4, &"normal")
	check_eq(left.position.x, -right.position.x)
	check_eq(left.position.y, right.position.y)
	check_eq(left.rotation, -right.rotation)
	check(left.rotation < 0.0, "left card tilts left")

func test_fan_overlaps_and_arcs() -> void:
	var a := HandLayout.slot_transform(1, 4, &"normal")
	var b := HandLayout.slot_transform(2, 4, &"normal")
	check(b.position.x - a.position.x < HandLayout.CARD_SIZE.x, "neighbours overlap")
	var outer := HandLayout.slot_transform(0, 4, &"normal")
	check(outer.position.y > a.position.y, "outer cards sit lower")

func test_lifted_and_spread() -> void:
	var normal := HandLayout.slot_transform(1, 4, &"normal")
	var lifted := HandLayout.slot_transform(1, 4, &"lifted")
	check_eq(lifted.position.y, normal.position.y - HandLayout.LIFT)
	var s0 := HandLayout.slot_transform(0, 4, &"spread")
	var s1 := HandLayout.slot_transform(1, 4, &"spread")
	check(s1.position.x - s0.position.x >= HandLayout.CARD_SIZE.x * HandLayout.SPREAD_SCALE, "spread cards do not overlap")
	check_eq(s0.rotation, 0.0)

func test_pile_offsets() -> void:
	check(HandLayout.pile_offsets(1).is_empty(), "single card has no pile")
	var pile := HandLayout.pile_offsets(3)
	check_eq(pile.size(), 2)
	check(pile[1].offset.length() > pile[0].offset.length(), "further back, further offset")
	check(pile[1].shade < pile[0].shade, "further back, darker")
	check_eq(HandLayout.pile_offsets(9).size(), HandLayout.MAX_PILE_SHOWN, "capped")

func test_diff_collect_play_clear() -> void:
	var empty := _inv([[&"", 0], [&"", 0]])
	var one := _inv([[&"armor", 1], [&"", 0]])
	check_eq(HandLayout.diff(empty, one, -1), [{"kind": &"collected", "slot": 0, "from": -1}] as Array[Dictionary])
	check_eq(HandLayout.diff(one, empty, 0), [{"kind": &"played", "slot": 0, "from": -1}] as Array[Dictionary])
	check_eq(HandLayout.diff(one, empty, -1), [{"kind": &"cleared", "slot": 0, "from": -1}] as Array[Dictionary])

func test_diff_merge() -> void:
	var before := _inv([[&"armor", 1], [&"burst", 1], [&"armor", 2]])
	var after := _inv([[&"", 0], [&"burst", 1], [&"armor", 3]])
	check_eq(HandLayout.diff(before, after, -1), [{"kind": &"merged", "slot": 2, "from": 0}] as Array[Dictionary])
