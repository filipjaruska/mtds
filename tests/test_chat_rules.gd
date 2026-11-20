extends "res://tests/test_case.gd"

func test_sanitize() -> void:
	check_eq(ChatRules.sanitize("  hello  "), "hello", "trimmed")
	check_eq(ChatRules.sanitize("gg\n\twp"), "gg wp", "newlines and tabs become one space")
	check_eq(ChatRules.sanitize("a    b"), "a b", "spaces collapsed")
	check_eq(ChatRules.sanitize("bell\u0007!"), "bell!", "control characters removed")
	check_eq(ChatRules.sanitize("   "), "", "only whitespace is empty")
	check_eq(ChatRules.sanitize("x".repeat(200)).length(), ChatRules.MAX_LENGTH, "capped")
	check_eq(ChatRules.sanitize("čau 👋"), "čau 👋", "unicode kept")

func test_rate_limit() -> void:
	var recent: Array = []
	for i in range(ChatRules.RATE_COUNT):
		var r := ChatRules.rate_ok(recent, 1000 + i * 100)
		check(r.allowed, "message %d allowed" % i)
		recent = r.recent
	var blocked := ChatRules.rate_ok(recent, 1500)
	check(not blocked.allowed, "burst blocked")
	var later := ChatRules.rate_ok(blocked.recent, 1000 + ChatRules.RATE_WINDOW_MSEC + 1)
	check(later.allowed, "allowed again once the window passed")

func test_timing_grows_with_length() -> void:
	check(ChatRules.reveal_seconds("hello there") > ChatRules.reveal_seconds("hi"))
	check_eq(ChatRules.reveal_seconds(""), 0.0)
	check(ChatRules.hold_seconds("x".repeat(80)) > ChatRules.HOLD_BASE)

func test_queue_drops_oldest_when_full() -> void:
	var q: Array = []
	for text in ["a", "b", "c", "d"]:
		q = ChatRules.enqueue(q, text)
	check_eq(q, ["b", "c", "d"])

func test_bar_sides_teams() -> void:
	var players := {
		1: {"id": 1, "team": 0}, 2: {"id": 2, "team": 1},
		3: {"id": 3, "team": 0}, 4: {"id": 4, "team": 1}, 5: {"id": 5, "team": 1},
	}
	var sides := ChatRules.bar_sides(players, true)
	check_eq(sides.left, [1, 3] as Array[int], "Red on the left")
	check_eq(sides.right, [2, 4, 5] as Array[int], "Blue on the right")

func test_bar_sides_deathmatch_alternates() -> void:
	var players := {7: {"id": 7}, 1: {"id": 1}, 3: {"id": 3}, 9: {"id": 9}}
	var sides := ChatRules.bar_sides(players, false)
	check_eq(sides.left, [1, 7] as Array[int])
	check_eq(sides.right, [3, 9] as Array[int])
