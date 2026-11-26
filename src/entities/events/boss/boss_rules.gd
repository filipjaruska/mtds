extends RefCounted
class_name BossRules
## Pure rules for a boss (Tutankhamun...): when he may leave his lair and whom
## he shoots. Nothing here touches nodes or the network.

## BOUND: awake but held in his lair. ROAMING: hunting round the map. DEAD:
## down, his drops on the floor.
enum State { BOUND, ROAMING, DEAD }

## His state after `now` (msec) with `hp` left; he roams once `free_at` passes
## (free_at < 0: never, he guards his lair).
static func next_state(state: State, hp: float, now: int, free_at: int) -> State:
	if state == State.DEAD or hp <= 0.0:
		return State.DEAD
	if state == State.BOUND and free_at >= 0 and now >= free_at:
		return State.ROAMING
	return state

## Whom he shoots: the nearest candidate he can see within `sight`, or 0.
## candidates: [{id: int, position: Vector2, visible: bool}]
static func pick_target(from: Vector2, candidates: Array, sight: float) -> int:
	var best := 0
	var best_distance := sight
	for candidate in candidates:
		if not candidate.visible:
			continue
		var distance: float = from.distance_to(candidate.position)
		if distance <= best_distance:
			best_distance = distance
			best = candidate.id
	return best

## Roaming with someone in sight: walk closer until `keep` away, then stand and shoot.
static func should_close_in(from: Vector2, target: Vector2, keep: float) -> bool:
	return from.distance_to(target) > keep
