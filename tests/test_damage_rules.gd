extends "res://tests/test_case.gd"

func test_resistance_reduces_damage() -> void:
	check_eq(DamageRules.final_damage(100.0, 0.0, 0.25), 75.0)

func test_penetration_cancels_resistance() -> void:
	check_eq(DamageRules.final_damage(100.0, 0.1, 0.25), 85.0)
	check_eq(DamageRules.final_damage(100.0, 0.5, 0.25), 100.0, "penetration never adds damage")

func test_resistance_is_capped() -> void:
	check_eq(DamageRules.final_damage(100.0, 0.0, 2.0), 0.0, "never heals")

func test_apply_reports_death_once() -> void:
	var first := DamageRules.apply(10.0, 15.0)
	check(first.died)
	check(not DamageRules.apply(first.health, 5.0).died, "already dead")

func test_fire_budget_allows_dual_bursts() -> void:
	# Regression: a 30 ms minimum interval rejected the off hand of a dual burst
	# (both hands fire in the same frame) and slow-frame burst catch-up.
	var recent: Array = []
	for i in range(36): # two hands at 18 shots/s for one second
		var r := DamageRules.fire_budget(recent, 1, i * 27, 50)
		check(r.allowed, "shot %d allowed" % i)
		recent = r.recent
	check(DamageRules.fire_budget(recent, 2, 990, 50).allowed, "two shots in one request")

func test_fire_budget_blocks_spam_and_recovers() -> void:
	var recent: Array = []
	for i in range(50):
		recent = DamageRules.fire_budget(recent, 1, 0, 50).recent
	check(not DamageRules.fire_budget(recent, 1, 500, 50).allowed, "51st shot within a second blocked")
	check(DamageRules.fire_budget(recent, 1, 1000, 50).allowed, "allowed again a second later")

func test_regen_does_not_overheal() -> void:
	check_eq(DamageRules.regen_amount(100.0, 0.1, 95.0), 5.0)
	check_eq(DamageRules.regen_amount(100.0, 0.1, 50.0), 10.0)
