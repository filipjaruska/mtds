extends RefCounted
class_name EventSchedule
## When a match's big events happen. Pure functions (tests call them).
##
## Big events (a boss, a room game) are the match's landmarks: they start at
## set points of the match (GameRules.big_event_marks, about a third and two
## thirds of the way through), a little earlier or later, in random order.
## Small events (a roaming NPC) keep their own timing (EventSpec) and can come
## any time.

## Start times (match seconds) for `count` big events, in the order given:
## each takes one of the marks (fractions of `duration`), shuffled, moved by up
## to `jitter` seconds. Events beyond the number of marks get INF (never).
static func big_starts(count: int, marks: Array, duration: float, jitter: float, rng: RandomNumberGenerator) -> Array[float]:
	var order: Array = range(marks.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var out: Array[float] = []
	for i in range(count):
		if i >= order.size():
			out.append(INF)
			continue
		var at := float(marks[order[i]]) * duration + rng.randf_range(-jitter, jitter)
		out.append(clampf(at, 0.0, duration))
	return out
