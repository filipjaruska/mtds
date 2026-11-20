extends RefCounted
class_name WeaponRules
## Pure functions over a single weapon's state. Nothing here touches nodes,
## the scene tree, the network or the clock: time is passed in as `now` (msec)
## and randomness as a RandomNumberGenerator, so every function is testable.
##
## Weapon state is a plain Dictionary (cheap to copy and to send over RPC):
##   def            StringName  WeaponDef id
##   ammo           int
##   next_shot_at   int         msec, earliest time the next shot may fire
##   reload_done_at int         msec, 0 when not reloading
##   burst_left     int         shots left in an active burst, 0 when none
##   burst_spread   float       degrees, spread used by burst shots
##   burst_interval int         msec between burst shots
##
## Functions that change state return a result Dictionary:
##   {state: Dictionary, shots: Array[float], events: Array[StringName]}
## `shots` are angle offsets in radians from the aim direction, one per pellet.
## Events: &"fired", &"reload_started", &"reloaded", &"burst_started", &"burst_finished".

static func new_state(def: WeaponDef, ammo: int = -1) -> Dictionary:
	return {
		"def": def.id,
		"ammo": def.mag_size if ammo < 0 else mini(ammo, def.mag_size),
		"next_shot_at": 0,
		"reload_done_at": 0,
		"burst_left": 0,
		"burst_spread": 0.0,
		"burst_interval": 0,
	}

## Base stats from the definition with modifiers folded in. Modifiers never
## change the definition, so removing a powerup simply means calling this again
## without it.
##   mods.damage_mult  +0.2 => 20% more damage
##   mods.reload_mult  +0.3 => reloads 30% faster
##   mods.spread_mult  +0.15 => 15% wider spread
##   mods.pierce       2     => a shot passes through 2 players
static func effective_stats(def: WeaponDef, mods: Dictionary = {}) -> Dictionary:
	return {
		"fire_rate": def.fire_rate,
		"spread_degrees": def.spread_degrees * maxf(1.0 + mods.get("spread_mult", 0.0), 0.0),
		"pellets": def.pellets,
		"fire_pattern": def.fire_pattern,
		"damage": def.damage * maxf(1.0 + mods.get("damage_mult", 0.0), 0.0),
		"armor_penetration": def.armor_penetration,
		"max_range": def.max_range,
		"mag_size": def.mag_size,
		"reload_time": def.reload_time / maxf(1.0 + mods.get("reload_mult", 0.0), 0.1),
		"move_speed_mult": def.move_speed_mult,
		"slow_duration": def.slow_duration,
		"pierce": int(mods.get("pierce", 0)),
	}

## A full magazine right now (Kill Reload). Cancels a reload in progress.
static func refill(state: Dictionary, stats: Dictionary) -> Dictionary:
	var next := state.duplicate()
	next.ammo = stats.mag_size
	next.reload_done_at = 0
	return next

static func is_reloading(state: Dictionary, now: int) -> bool:
	return state.reload_done_at > 0 and now < state.reload_done_at

static func is_bursting(state: Dictionary) -> bool:
	return state.burst_left > 0

## Ready to start a new shot, burst or reload sequence (not busy).
static func is_idle(state: Dictionary, now: int) -> bool:
	return not is_bursting(state) and not is_reloading(state, now)

static func can_fire(state: Dictionary, now: int) -> bool:
	return is_idle(state, now) and state.ammo > 0 and now >= state.next_shot_at

static func fire(state: Dictionary, stats: Dictionary, now: int, rng: RandomNumberGenerator) -> Dictionary:
	if not can_fire(state, now):
		return _result(state)
	var next := state.duplicate()
	next.ammo -= 1
	next.next_shot_at = now + interval_msec(stats.fire_rate)
	var shots := shot_offsets(stats.fire_pattern, stats.pellets, stats.spread_degrees, rng)
	return _result(next, shots, [&"fired"])

static func start_reload(state: Dictionary, stats: Dictionary, now: int) -> Dictionary:
	if not is_idle(state, now) or state.ammo >= stats.mag_size:
		return _result(state)
	var next := state.duplicate()
	next.reload_done_at = now + int(stats.reload_time * 1000.0)
	return _result(next, [], [&"reload_started"])

## Empties the magazine as a rapid burst; the shots are produced by tick().
static func start_burst(state: Dictionary, now: int, spread_degrees: float, shots_per_second: float) -> Dictionary:
	if not is_idle(state, now) or state.ammo <= 0:
		return _result(state)
	var next := state.duplicate()
	next.burst_left = next.ammo
	next.burst_spread = spread_degrees
	next.burst_interval = interval_msec(shots_per_second)
	next.next_shot_at = now
	return _result(next, [], [&"burst_started"])

## Advances time: finishes reloads and fires due burst shots.
static func tick(state: Dictionary, stats: Dictionary, now: int, rng: RandomNumberGenerator) -> Dictionary:
	var next := state.duplicate()
	var shots: Array[float] = []
	var events: Array[StringName] = []

	if next.reload_done_at > 0 and now >= next.reload_done_at:
		next.reload_done_at = 0
		next.ammo = stats.mag_size
		events.append(&"reloaded")

	if next.burst_left > 0:
		var fired_this_tick := 0
		while next.burst_left > 0 and now >= next.next_shot_at and fired_this_tick < 32:
			next.ammo -= 1
			next.burst_left = 0 if next.ammo <= 0 else next.burst_left - 1
			next.next_shot_at += next.burst_interval
			shots.append_array(shot_offsets(stats.fire_pattern, stats.pellets, next.burst_spread, rng))
			events.append(&"fired")
			fired_this_tick += 1
		if next.burst_left == 0:
			# Normal fire-rate cooldown applies after the burst.
			next.next_shot_at = maxi(next.next_shot_at, now + interval_msec(stats.fire_rate))
			events.append(&"burst_finished")

	return _result(next, shots, events)

## Angle offsets (radians) for one trigger pull. Add a new pattern by adding a
## match arm here and setting `fire_pattern` on a WeaponDef.
static func shot_offsets(pattern: StringName, pellets: int, spread_degrees: float, rng: RandomNumberGenerator) -> Array[float]:
	var spread := deg_to_rad(spread_degrees)
	var out: Array[float] = []
	match pattern:
		&"even":
			for i in range(pellets):
				var t := 0.5 if pellets == 1 else float(i) / float(pellets - 1)
				out.append(lerpf(-spread, spread, t))
		_: # &"random"
			for i in range(pellets):
				out.append(rng.randf_range(-spread, spread))
	return out

static func interval_msec(rate_per_second: float) -> int:
	return int(1000.0 / maxf(rate_per_second, 0.01))

static func _result(state: Dictionary, shots: Array[float] = [], events: Array[StringName] = []) -> Dictionary:
	return {"state": state, "shots": shots, "events": events}
