extends RefCounted
class_name DamageRules
## Pure damage math, shared by the host and the tests.

## Resistance is a fraction (0.15 = 15% less damage); penetration cancels it out.
static func final_damage(damage: float, penetration: float, resistance: float) -> float:
	if damage <= 0.0:
		return 0.0
	var effective_resist := clampf(resistance - penetration, 0.0, 1.0)
	return damage * (1.0 - effective_resist)

## Returns {health, died: bool} after applying `amount` to `health`.
static func apply(health: float, amount: float) -> Dictionary:
	var next := health - maxf(amount, 0.0)
	return {"health": next, "died": health > 0.0 and next <= 0.0}

## Sliding one-second window of accepted shots. Returns {allowed, recent};
## keep `recent` for the next call.
static func fire_budget(recent: Array, shot_count: int, now: int, max_per_second: int) -> Dictionary:
	var kept := recent.filter(func(t): return now - t < 1000)
	if kept.size() + shot_count > max_per_second:
		return {"allowed": false, "recent": kept}
	for i in range(shot_count):
		kept.append(now)
	return {"allowed": true, "recent": kept}

static func regen_amount(max_health: float, percent_per_tick: float, current: float) -> float:
	return clampf(max_health * percent_per_tick, 0.0, maxf(max_health - current, 0.0))
