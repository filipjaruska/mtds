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

func test_regen_does_not_overheal() -> void:
	check_eq(DamageRules.regen_amount(100.0, 0.1, 95.0), 5.0)
	check_eq(DamageRules.regen_amount(100.0, 0.1, 50.0), 10.0)
