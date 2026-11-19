extends RefCounted
class_name LoadoutRules
## Pure functions over a player's loadout. A loadout is a plain Dictionary:
##   slots              Array[Dictionary]  weapon states (see WeaponRules)
##   active             int                index into slots
##   offhand            Dictionary         mirrored weapon while dual wielding, {} otherwise
##   dual_spread        float              extra spread multiplier while dual wielding
##   dual_primary_next  bool               which hand fires next
##   dual_next_shot_at  int                msec, shared cadence of both hands
##
## Every function returns a new loadout and never modifies its argument.
## While dual wielding the loadout is locked: no switching, dropping or pickups.

const MAX_SLOTS := 2

static func empty() -> Dictionary:
	return {
		"slots": [],
		"active": 0,
		"offhand": {},
		"dual_spread": 0.0,
		"dual_primary_next": true,
		"dual_next_shot_at": 0,
	}

static func with_weapon(def: WeaponDef) -> Dictionary:
	var loadout := empty()
	loadout.slots.append(WeaponRules.new_state(def))
	return loadout

static func active(loadout: Dictionary) -> Dictionary:
	if loadout.active >= 0 and loadout.active < loadout.slots.size():
		return loadout.slots[loadout.active]
	return {}

static func is_dual(loadout: Dictionary) -> bool:
	return not loadout.offhand.is_empty()

static func has_weapon(loadout: Dictionary, def_id: StringName) -> bool:
	for state in loadout.slots:
		if state.def == def_id:
			return true
	return false

static func can_pick_up(loadout: Dictionary) -> bool:
	return not is_dual(loadout)

static func with_active_state(loadout: Dictionary, state: Dictionary) -> Dictionary:
	var next := loadout.duplicate(true)
	if next.active < next.slots.size():
		next.slots[next.active] = state
	return next

static func with_offhand_state(loadout: Dictionary, state: Dictionary) -> Dictionary:
	var next := loadout.duplicate(true)
	next.offhand = state
	return next

## Adds a weapon and equips it. With full slots the active weapon is replaced.
## Returns {loadout, accepted: bool, dropped: Array[StringName]}.
static func add(loadout: Dictionary, state: Dictionary) -> Dictionary:
	if not can_pick_up(loadout):
		return {"loadout": loadout, "accepted": false, "dropped": []}
	var next := loadout.duplicate(true)
	var dropped: Array[StringName] = []
	if next.slots.size() >= MAX_SLOTS:
		dropped.append(next.slots[next.active].def)
		next.slots[next.active] = state
	else:
		next.slots.append(state)
		next.active = next.slots.size() - 1
	return {"loadout": next, "accepted": true, "dropped": dropped}

## Returns {loadout, dropped: Array[StringName]}.
static func drop(loadout: Dictionary, index: int) -> Dictionary:
	if is_dual(loadout) or index < 0 or index >= loadout.slots.size():
		return {"loadout": loadout, "dropped": []}
	var next := loadout.duplicate(true)
	var dropped: Array[StringName] = [next.slots[index].def]
	next.slots.remove_at(index)
	if next.active > index or next.active >= next.slots.size():
		next.active = maxi(next.active - 1, 0)
	return {"loadout": next, "dropped": dropped}

static func equip(loadout: Dictionary, index: int) -> Dictionary:
	if is_dual(loadout) or index < 0 or index >= loadout.slots.size() or index == loadout.active:
		return loadout
	var next := loadout.duplicate(true)
	next.active = index
	return next

static func switch_next(loadout: Dictionary) -> Dictionary:
	if loadout.slots.size() < 2:
		return loadout
	return equip(loadout, (loadout.active + 1) % loadout.slots.size())

## Mirrors the active weapon into the off hand. Refuses with an empty magazine.
## Calling it while already dual wielding only updates the spread.
static func enable_dual(loadout: Dictionary, spread_mult: float, offhand_ammo: int = -1) -> Dictionary:
	var next := loadout.duplicate(true)
	if is_dual(loadout):
		next.dual_spread = spread_mult
		return next
	var primary := active(loadout)
	if primary.is_empty() or primary.ammo <= 0 or primary.burst_left > 0:
		return loadout
	var offhand: Dictionary = primary.duplicate()
	offhand.ammo = primary.ammo if offhand_ammo < 0 else offhand_ammo
	offhand.reload_done_at = 0
	next.slots[next.active].reload_done_at = 0
	next.offhand = offhand
	next.dual_spread = spread_mult
	next.dual_primary_next = true
	next.dual_next_shot_at = 0
	return next

static func disable_dual(loadout: Dictionary) -> Dictionary:
	if not is_dual(loadout):
		return loadout
	var next := loadout.duplicate(true)
	next.offhand = {}
	next.dual_spread = 0.0
	next.dual_primary_next = true
	next.dual_next_shot_at = 0
	return next

static func dual_magazines_empty(loadout: Dictionary) -> bool:
	return is_dual(loadout) and active(loadout).ammo <= 0 and loadout.offhand.ammo <= 0

static func any_bursting(loadout: Dictionary) -> bool:
	var primary := active(loadout)
	if not primary.is_empty() and WeaponRules.is_bursting(primary):
		return true
	return is_dual(loadout) and WeaponRules.is_bursting(loadout.offhand)

## Which hand should fire next while dual wielding: &"primary", &"offhand" or
## &"" when neither may fire yet. Hands alternate; an empty hand is skipped.
static func pick_dual_hand(loadout: Dictionary, now: int) -> StringName:
	if not is_dual(loadout) or now < loadout.dual_next_shot_at:
		return &""
	var order: Array = [&"primary", &"offhand"] if loadout.dual_primary_next else [&"offhand", &"primary"]
	for hand in order:
		var state: Dictionary = active(loadout) if hand == &"primary" else loadout.offhand
		if WeaponRules.can_fire(state, now):
			return hand
	return &""

## Records a dual shot: only one hand may fire per fire-rate interval.
static func after_dual_shot(loadout: Dictionary, hand: StringName, interval_msec: int, now: int) -> Dictionary:
	var next := loadout.duplicate(true)
	next.dual_next_shot_at = now + interval_msec
	next.dual_primary_next = hand != &"primary"
	return next

static func hand_state(loadout: Dictionary, hand: StringName) -> Dictionary:
	return loadout.offhand if hand == &"offhand" else active(loadout)

static func with_hand_state(loadout: Dictionary, hand: StringName, state: Dictionary) -> Dictionary:
	if hand == &"offhand":
		return with_offhand_state(loadout, state)
	return with_active_state(loadout, state)
