extends "res://tests/test_case.gd"
## When the big events happen: at a third and two thirds of the match, in
## random order, a little earlier or later.

const MARKS := [0.33, 0.67]

func test_two_big_events_take_both_marks() -> void:
	var rng := RandomNumberGenerator.new()
	var first_seen := {}
	for game_seed in range(40):
		rng.seed = game_seed
		var starts := EventSchedule.big_starts(2, MARKS, 300.0, 10.0, rng)
		check_eq(starts.size(), 2)
		var early := minf(starts[0], starts[1])
		var late := maxf(starts[0], starts[1])
		check(absf(early - 99.0) <= 10.0, "one about a third in: %s" % [starts])
		check(absf(late - 201.0) <= 10.0, "the other about two thirds in: %s" % [starts])
		first_seen[starts[0] < starts[1]] = true
	check_eq(first_seen.size(), 2, "either one may come first")

func test_one_big_event_takes_one_of_the_marks() -> void:
	var rng := RandomNumberGenerator.new()
	var marks_seen := {}
	for game_seed in range(40):
		rng.seed = game_seed
		var at: float = EventSchedule.big_starts(1, MARKS, 300.0, 0.0, rng)[0]
		check(is_equal_approx(at, 99.0) or is_equal_approx(at, 201.0), "on a mark: %s" % at)
		marks_seen[roundi(at)] = true
	check_eq(marks_seen.size(), 2, "sometimes the first mark, sometimes the second")

func test_more_big_events_than_marks() -> void:
	var rng := RandomNumberGenerator.new()
	var left_out := {}
	for game_seed in range(60):
		rng.seed = game_seed
		var starts := EventSchedule.big_starts(4, MARKS, 300.0, 0.0, rng)
		check_eq(starts.count(INF), 2, "two of four happen, two do not: %s" % [starts])
		for i in range(4):
			if starts[i] == INF:
				left_out[i] = true
	check_eq(left_out.size(), 4, "which ones are left out is random")

func test_stays_inside_the_match() -> void:
	var rng := RandomNumberGenerator.new()
	for at in EventSchedule.big_starts(2, [0.0, 1.0], 60.0, 30.0, rng):
		check(at >= 0.0 and at <= 60.0, "inside the match: %s" % at)
