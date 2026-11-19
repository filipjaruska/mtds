extends "res://tests/test_case.gd"

func _def(id: StringName, mag: int = 5) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = id
	def.mag_size = mag
	def.fire_rate = 2.0
	return def

func _loadout_with(ids: Array) -> Dictionary:
	var loadout := LoadoutRules.empty()
	for id in ids:
		loadout = LoadoutRules.add(loadout, WeaponRules.new_state(_def(id))).loadout
	return loadout

func test_add_equips_new_weapon() -> void:
	var loadout := _loadout_with([&"a", &"b"])
	check_eq(loadout.slots.size(), 2)
	check_eq(LoadoutRules.active(loadout).def, &"b")

func test_add_when_full_replaces_active_and_reports_drop() -> void:
	var loadout := LoadoutRules.equip(_loadout_with([&"a", &"b"]), 0)
	var r := LoadoutRules.add(loadout, WeaponRules.new_state(_def(&"c")))
	check(r.accepted)
	check_eq(r.dropped, [&"a"] as Array[StringName])
	check_eq(r.loadout.slots.size(), LoadoutRules.MAX_SLOTS)
	check_eq(LoadoutRules.active(r.loadout).def, &"c")
	check_eq(r.loadout.slots[1].def, &"b")

func test_drop_keeps_active_index_valid() -> void:
	var loadout := _loadout_with([&"a", &"b"]) # active = 1
	var r := LoadoutRules.drop(loadout, 1)
	check_eq(r.dropped, [&"b"] as Array[StringName])
	check_eq(r.loadout.active, 0)
	check_eq(LoadoutRules.active(r.loadout).def, &"a")
	var r2 := LoadoutRules.drop(r.loadout, 0)
	check(LoadoutRules.active(r2.loadout).is_empty(), "no weapon left")

func test_equip_bounds() -> void:
	# Regression: equip_weapon used to accept index == size.
	var loadout := _loadout_with([&"a"])
	check_eq(LoadoutRules.equip(loadout, 1).active, 0)
	check_eq(LoadoutRules.equip(loadout, -1).active, 0)

func test_switch_next_wraps() -> void:
	var loadout := _loadout_with([&"a", &"b"])
	check_eq(LoadoutRules.switch_next(loadout).active, 0)
	check_eq(LoadoutRules.switch_next(LoadoutRules.switch_next(loadout)).active, 1)

func test_dual_wield_locks_loadout() -> void:
	var loadout := LoadoutRules.enable_dual(_loadout_with([&"a", &"b"]), 0.15)
	check(LoadoutRules.is_dual(loadout))
	check_eq(loadout.offhand.def, &"b")
	check_eq(loadout.offhand.ammo, 5)
	check(not LoadoutRules.add(loadout, WeaponRules.new_state(_def(&"c"))).accepted, "no pickup")
	check(LoadoutRules.drop(loadout, 0).dropped.is_empty(), "no drop")
	check_eq(LoadoutRules.switch_next(loadout).active, loadout.active, "no switch")
	check(not LoadoutRules.is_dual(LoadoutRules.disable_dual(loadout)))

func test_dual_refused_with_empty_magazine() -> void:
	var loadout := LoadoutRules.empty()
	loadout = LoadoutRules.add(loadout, WeaponRules.new_state(_def(&"a"), 0)).loadout
	check(not LoadoutRules.is_dual(LoadoutRules.enable_dual(loadout, 0.1)))

func test_dual_hands_alternate_and_skip_empty() -> void:
	var loadout := LoadoutRules.enable_dual(_loadout_with([&"a"]), 0.0)
	check_eq(LoadoutRules.pick_dual_hand(loadout, 0), &"primary")
	loadout = LoadoutRules.after_dual_shot(loadout, &"primary", 500, 0)
	check_eq(LoadoutRules.pick_dual_hand(loadout, 499), &"", "shared cadence")
	check_eq(LoadoutRules.pick_dual_hand(loadout, 500), &"offhand")
	var empty_off: Dictionary = loadout.offhand.duplicate()
	empty_off.ammo = 0
	loadout = LoadoutRules.with_offhand_state(loadout, empty_off)
	check_eq(LoadoutRules.pick_dual_hand(loadout, 500), &"primary", "falls back to loaded hand")

func test_dual_magazines_empty() -> void:
	var loadout := LoadoutRules.enable_dual(_loadout_with([&"a"]), 0.0)
	check(not LoadoutRules.dual_magazines_empty(loadout))
	var p: Dictionary = LoadoutRules.active(loadout).duplicate()
	p.ammo = 0
	var o: Dictionary = loadout.offhand.duplicate()
	o.ammo = 0
	loadout = LoadoutRules.with_offhand_state(LoadoutRules.with_active_state(loadout, p), o)
	check(LoadoutRules.dual_magazines_empty(loadout))
