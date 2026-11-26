extends "res://tests/test_case.gd"
## Tutankhamun: when he leaves his tomb, whom he shoots, and his staff.

const State := TutankhamunRules.State

func test_held_in_his_tomb_until_his_time_is_up() -> void:
	check_eq(TutankhamunRules.next_state(State.BOUND, 100.0, 5000, 6000), State.BOUND)
	check_eq(TutankhamunRules.next_state(State.BOUND, 100.0, 6000, 6000), State.ROAMING, "free once the minute is up")
	check_eq(TutankhamunRules.next_state(State.ROAMING, 100.0, 9000, 6000), State.ROAMING)
	check_eq(TutankhamunRules.next_state(State.BOUND, 0.0, 1000, 6000), State.DEAD, "no health: dead")
	check_eq(TutankhamunRules.next_state(State.DEAD, 100.0, 9000, 6000), State.DEAD, "dead stays dead")

func test_shoots_the_nearest_player_he_can_see() -> void:
	var candidates := [
		{"id": 2, "position": Vector2(300, 0), "visible": true},
		{"id": 3, "position": Vector2(100, 0), "visible": false},
		{"id": 4, "position": Vector2(200, 0), "visible": true},
	]
	check_eq(TutankhamunRules.pick_target(Vector2.ZERO, candidates, 650.0), 4, "nearest one in sight")
	check_eq(TutankhamunRules.pick_target(Vector2.ZERO, candidates, 150.0), 0, "nobody close enough")
	check_eq(TutankhamunRules.pick_target(Vector2.ZERO, [], 650.0), 0)

func test_closes_in_then_stands() -> void:
	check(TutankhamunRules.should_close_in(Vector2.ZERO, Vector2(500, 0), 320.0))
	check(not TutankhamunRules.should_close_in(Vector2.ZERO, Vector2(300, 0), 320.0))

func test_staff_costs_health_not_ammo() -> void:
	var def := WeaponDefs.get_def(&"pharaoh_staff")
	check(def != null, "the Pharaoh's Staff exists")
	if def == null:
		return
	check(def.health_cost > 0.0, "it costs health")
	check(def.armor_penetration >= 1.0, "fire ignores armor")
	check(def.burn_seconds > 0.0 and def.burn_damage_per_second > 0.0, "and burns")
	check(def.bullet_scene != null, "it throws fireballs")
	var stats := WeaponRules.effective_stats(def)
	var state := WeaponRules.new_state(def)
	var rng := RandomNumberGenerator.new()
	var result := WeaponRules.fire(state, stats, 1000, rng)
	check_eq(result.shots.size(), 1, "fires")
	check_eq(result.state.ammo, state.ammo, "no ammo used")
	result = WeaponRules.fire(result.state, stats, 1000 + WeaponRules.interval_msec(stats.fire_rate), rng)
	check_eq(result.shots.size(), 1, "and again: it never runs dry")

func test_fire_ignores_armor() -> void:
	check_eq(DamageRules.final_damage(10.0, 1.0, 0.3), 10.0, "full damage through armor")
	check(not WeaponDefs.get_def(&"pharaoh_staff").one_location, "not tied to a weapon spot")
