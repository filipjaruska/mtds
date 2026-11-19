extends "res://tests/test_case.gd"

func _def(overrides: Dictionary = {}) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = &"test_gun"
	def.fire_rate = 2.0 # 500 ms between shots
	def.spread_degrees = 10.0
	def.pellets = 1
	def.damage = 10.0
	def.mag_size = 3
	def.reload_time = 2.0
	for key in overrides:
		def.set(key, overrides[key])
	return def

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return rng

func test_new_state_starts_full() -> void:
	var state := WeaponRules.new_state(_def())
	check_eq(state.ammo, 3)
	check_eq(state.def, &"test_gun")

func test_fire_consumes_ammo_and_gates_on_fire_rate() -> void:
	var def := _def()
	var stats := WeaponRules.effective_stats(def)
	var state := WeaponRules.new_state(def)
	var r := WeaponRules.fire(state, stats, 1000, _rng())
	check_eq(r.state.ammo, 2, "ammo after shot")
	check_eq(r.shots.size(), 1, "one pellet")
	check(r.events.has(&"fired"), "fired event")
	check_eq(state.ammo, 3, "input state untouched")

	var too_soon := WeaponRules.fire(r.state, stats, 1499, _rng())
	check(too_soon.shots.is_empty(), "blocked before interval")
	var on_time := WeaponRules.fire(r.state, stats, 1500, _rng())
	check_eq(on_time.shots.size(), 1, "allowed after interval")

func test_cannot_fire_empty() -> void:
	var def := _def()
	var state := WeaponRules.new_state(def, 0)
	var r := WeaponRules.fire(state, WeaponRules.effective_stats(def), 0, _rng())
	check(r.shots.is_empty())

func test_pellets_and_spread_bounds() -> void:
	var def := _def({"pellets": 5, "spread_degrees": 12.0})
	var r := WeaponRules.fire(WeaponRules.new_state(def), WeaponRules.effective_stats(def), 0, _rng())
	check_eq(r.shots.size(), 5)
	for offset in r.shots:
		check(absf(offset) <= deg_to_rad(12.0) + 0.0001, "offset inside spread")

func test_even_pattern_is_symmetric() -> void:
	var offsets := WeaponRules.shot_offsets(&"even", 3, 10.0, _rng())
	check_eq(offsets[0], -deg_to_rad(10.0))
	check_eq(offsets[1], 0.0)
	check_eq(offsets[2], deg_to_rad(10.0))

func test_reload_cycle() -> void:
	var def := _def()
	var stats := WeaponRules.effective_stats(def)
	var state := WeaponRules.new_state(def, 1)
	var r := WeaponRules.start_reload(state, stats, 1000)
	check(r.events.has(&"reload_started"))
	check(WeaponRules.is_reloading(r.state, 2999), "still reloading")
	check(not WeaponRules.can_fire(r.state, 2000), "cannot fire while reloading")
	var done := WeaponRules.tick(r.state, stats, 3000, _rng())
	check(done.events.has(&"reloaded"))
	check_eq(done.state.ammo, 3)
	check(not WeaponRules.is_reloading(done.state, 3000))

func test_reload_ignored_when_full() -> void:
	var def := _def()
	var r := WeaponRules.start_reload(WeaponRules.new_state(def), WeaponRules.effective_stats(def), 0)
	check(r.events.is_empty())

func test_reload_modifier_never_mutates_definition() -> void:
	# Regression: reloading used to divide reload_time on the weapon forever.
	var def := _def()
	var mods := {"reload_mult": 0.5}
	for i in range(5):
		var stats := WeaponRules.effective_stats(def, mods)
		check_eq(stats.reload_time, 2.0 / 1.5, "reload %d" % i)
	check_eq(def.reload_time, 2.0, "definition untouched")
	check_eq(WeaponRules.effective_stats(def).reload_time, 2.0, "back to base without modifier")

func test_damage_modifier_applies() -> void:
	# Regression: Damage Boost used to have no effect.
	var stats := WeaponRules.effective_stats(_def(), {"damage_mult": 0.2})
	check_eq(stats.damage, 12.0)

func test_burst_empties_magazine_over_ticks() -> void:
	var def := _def()
	var stats := WeaponRules.effective_stats(def)
	var r := WeaponRules.start_burst(WeaponRules.new_state(def), 0, 30.0, 10.0) # 100 ms apart
	check(r.events.has(&"burst_started"))
	check(not WeaponRules.can_fire(r.state, 0), "normal fire blocked during burst")
	var t1 := WeaponRules.tick(r.state, stats, 0, _rng())
	check_eq(t1.shots.size(), 1, "first burst shot immediately")
	check_eq(t1.state.ammo, 2)
	var t2 := WeaponRules.tick(t1.state, stats, 250, _rng())
	check_eq(t2.shots.size(), 2, "catches up on due shots")
	check_eq(t2.state.ammo, 0)
	check(t2.events.has(&"burst_finished"))
	check(not WeaponRules.is_bursting(t2.state))
