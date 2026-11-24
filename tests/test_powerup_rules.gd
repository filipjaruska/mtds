extends "res://tests/test_case.gd"

func _def(id: StringName, overrides: Dictionary = {}) -> PowerupDef:
	var def := PowerupDef.new()
	def.id = id
	def.duration = 10.0
	def.max_stack_count = 4
	def.stack_multiplier = 2.0
	def.stack_bonus_per_card = 0.1
	for key in overrides:
		def.set(key, overrides[key])
	return def

func _mods(values: Dictionary) -> CardModifiers:
	var mods := CardModifiers.new()
	for key in values:
		mods.set(key, values[key])
	return mods

func test_stack_scale() -> void:
	var def := _def(&"x")
	check_eq(PowerupRules.stack_scale(def, 1), 1.0)
	check_eq(PowerupRules.stack_scale(def, 2), 2.1)
	check_eq(PowerupRules.stack_scale(def, 4), 2.3)

func test_activation_stacks_per_card_rules() -> void:
	var def := _def(&"x")
	check_eq(PowerupRules.activation_stacks(def, 3, PowerupRules.RULES_STANDARD, 1), 1)
	check_eq(PowerupRules.activation_stacks(def, 3, PowerupRules.RULES_SHUFFLE, 1), 3)
	check_eq(PowerupRules.activation_stacks(def, 9, PowerupRules.RULES_SHUFFLE, 1), 4, "capped")
	check_eq(PowerupRules.activation_stacks(def, 3, PowerupRules.RULES_POKER, 2), 2, "poker plays the hand's stacks")
	check_eq(PowerupRules.activation_stacks(def, 1, PowerupRules.RULES_POKER, 9), 4, "capped at max stacks")

func test_reactivation_adds_stacks_and_refreshes() -> void:
	var def := _def(&"x")
	var active := PowerupRules.activate([], def, 1, PowerupRules.RULES_STANDARD, 0)
	active = PowerupRules.activate(active, def, 1, PowerupRules.RULES_STANDARD, 5000)
	check_eq(active.size(), 1, "one entry per powerup")
	check_eq(active[0].stacks, 2)
	check_eq(active[0].expires_at, 15000, "duration refreshed")

func test_poker_reactivation_replaces_stacks() -> void:
	var def := _def(&"x")
	var active := PowerupRules.activate([], def, 4, PowerupRules.RULES_POKER, 0)
	active = PowerupRules.activate(active, def, 1, PowerupRules.RULES_POKER, 0)
	check_eq(active[0].stacks, 1)

func test_expiry_by_time_and_uses() -> void:
	var timed := _def(&"timed")
	var limited := _def(&"limited", {"max_uses": 1})
	var active := PowerupRules.activate([], timed, 1, PowerupRules.RULES_STANDARD, 0)
	active = PowerupRules.activate(active, limited, 1, PowerupRules.RULES_STANDARD, 0)
	check(PowerupRules.expired_ids(active, 9999).is_empty())
	check_eq(PowerupRules.expired_ids(active, 10000).size(), 2)
	active = PowerupRules.consume_use(active, &"limited")
	check_eq(PowerupRules.expired_ids(active, 0), [&"limited"] as Array[StringName], "used up")

func test_modifiers_sum_and_disappear_without_drift() -> void:
	# Regression: apply/remove with +=/-= used to leave values behind.
	var armor := _def(&"armor", {"modifiers": _mods({"damage_resist": 0.15}), "stack_multiplier": 1.5})
	var dmg := _def(&"dmg", {"modifiers": _mods({"damage_mult": 0.2})})
	var active := PowerupRules.activate([], armor, 2, PowerupRules.RULES_SHUFFLE, 0)
	active = PowerupRules.activate(active, dmg, 1, PowerupRules.RULES_STANDARD, 0)
	# Defs are looked up through the registry, so register these test defs.
	PowerupDefs._by_id[&"armor"] = armor
	PowerupDefs._by_id[&"dmg"] = dmg
	var mods := PowerupRules.modifiers(active)
	check_eq(mods.damage_resist, 0.15 * 1.6)
	check_eq(mods.damage_mult, 0.2)
	check(PowerupRules.modifiers(PowerupRules.without(active, &"armor")).get("damage_resist", 0.0) == 0.0)
	PowerupDefs._by_id.erase(&"armor")
	PowerupDefs._by_id.erase(&"dmg")

func test_dual_and_burst_params_tighten_with_stacks() -> void:
	var dual := _def(&"dual", {"ability": DualWieldAbility.new()}) # 0.15, -15% per stack
	check_eq(PowerupRules.dual_spread(dual, 1), 0.15)
	check_eq(PowerupRules.dual_spread(dual, 3), 0.15 * 0.7)
	var burst := _def(&"burst", {"ability": BurstAbility.new()}) # 12 deg x4, -20% per stack, min 8
	check_eq(PowerupRules.burst_params(burst, 1).spread_degrees, 48.0)
	check_eq(PowerupRules.burst_params(burst, 4).spread_degrees, 48.0 * 0.4)

func test_inventory_merge() -> void:
	var inv := PowerupRules.empty_inventory(4)
	inv = PowerupRules.with_slot(inv, 0, &"x", 3)
	inv = PowerupRules.with_slot(inv, 1, &"x", 2)
	inv = PowerupRules.with_slot(inv, 2, &"y", 1)
	var merged := PowerupRules.merge(inv, 0, 1, 4)
	check_eq(merged[1].count, 4, "target filled to max")
	check_eq(merged[0].count, 1, "remainder stays")
	check_eq(PowerupRules.merge(inv, 0, 2, 4), inv, "different cards do not merge")
	check_eq(PowerupRules.empty_slot(merged), 3)

func test_real_defs_load() -> void:
	check_eq(PowerupDefs.ids().size(), 7, "all seven powerups registered")
	for id in PowerupDefs.ids():
		check(not PowerupDefs.get_def(id).get_display_name().is_empty(), "%s has a name" % id)
	check_eq(PowerupDefs.get_def(&"dual_wield").ability_kind(), &"dual_wield")
	check(WeaponDefs.has(&"pistol") and WeaponDefs.has(&"shotgun"), "weapon defs registered")

# --- Card abilities (these use the real defs in src/entities/powerups/defs) ---

func test_shield_grows_with_stacks() -> void:
	var def := PowerupDefs.get_def(&"armor")
	var one := PowerupRules.shield_params(def, 1)
	var two := PowerupRules.shield_params(def, 2)
	check_eq(one.hp, 150.0)
	check(two.hp > one.hp, "more HP with 2 stacks")
	check_eq(two.width, one.width + 16.0, "wider per extra stack")

func test_pierce_counts_stacks() -> void:
	var def := PowerupDefs.get_def(&"damage_boost")
	check_eq(PowerupRules.pierce([]), 0, "no card, no pierce")
	check_eq(PowerupRules.pierce(PowerupRules.activate([], def, 1, PowerupRules.RULES_STANDARD, 0)), 1)
	check_eq(PowerupRules.pierce(PowerupRules.activate([], def, 3, PowerupRules.RULES_STANDARD, 0)), 3)

func test_last_stand_charges_run_out() -> void:
	var def := PowerupDefs.get_def(&"health_boost")
	var active := PowerupRules.activate([], def, 2, PowerupRules.RULES_STANDARD, 0)
	check_eq(PowerupRules.last_stand_entry(active).uses_left, 2, "one charge per stack")
	active = PowerupRules.consume_use(active, def.id)
	check(not PowerupRules.last_stand_entry(active).is_empty(), "one charge left")
	active = PowerupRules.consume_use(active, def.id)
	check(PowerupRules.last_stand_entry(active).is_empty(), "spent")
	check(PowerupRules.expired_ids(active, 0).has(def.id), "Warmog fades once spent")

func test_charge_damage_scales() -> void:
	var def := PowerupDefs.get_def(&"faster_dash")
	check_eq(PowerupRules.charge_params(def, 1).damage, 25.0)
	check(PowerupRules.charge_params(def, 2).damage > 25.0)

func test_slots_keep_their_hole_card() -> void:
	var inv := PowerupRules.empty_inventory(3)
	check_eq(inv[0].hole, -1)
	inv = PowerupRules.with_slot(inv, 0, &"x", 1, 17)
	check_eq(inv[0].hole, 17)
	inv = PowerupRules.with_slot(inv, 1, &"x", 1, 30)
	var merged := PowerupRules.merge(inv, 0, 1, 4)
	check_eq(merged[1].hole, 30, "target keeps its card")
	check_eq(merged[0].hole, -1, "emptied slot has no card")
