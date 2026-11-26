extends RefCounted
class_name EventSchedule
## When a match's big events happen. Pure functions (tests call them).
##
## Big events (a boss, a room game) are the match's landmarks: they start at
## set points of the match (GameRules.big_event_marks, about a third and two
## thirds of the way through), a little earlier or later, in random order.
## Small events (a roaming NPC) keep their own timing (EventSpec) and can come
## any time.

## Start times (match seconds) for a map's `count` big events, one per event:
## as many as there are marks (fractions of `duration`) are picked at random,
## each takes one of the marks in random order, moved by up to `jitter`
## seconds. The ones not picked get INF: they do not happen this match.
static func big_starts(count: int, marks: Array, duration: float, jitter: float, rng: RandomNumberGenerator) -> Array[float]:
	var order: Array = range(marks.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var picked: Array = range(count)
	for i in range(picked.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = picked[i]
		picked[i] = picked[j]
		picked[j] = tmp
	var out: Array[float] = []
	out.resize(count)
	out.fill(INF)
	for k in range(mini(count, order.size())):
		var at := float(marks[order[k]]) * duration + rng.randf_range(-jitter, jitter)
		out[picked[k]] = clampf(at, 0.0, duration)
	return out
