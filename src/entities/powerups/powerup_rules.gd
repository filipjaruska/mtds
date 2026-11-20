extends RefCounted
class_name PowerupRules
## Pure functions over powerup inventories and active powerups.
## Time is passed in as `now` (msec); nothing here touches nodes or the network.
##
## Active powerup entry: {def: StringName, stacks: int, expires_at: int, uses_left: int}
##   uses_left is -1 when the powerup has no use limit.
## Inventory: Array of slots {def: StringName, count: int, hole: int}; an empty
## slot has def &"". `hole` is the slot's playing card under Poker (-1 otherwise).

## Card rules (independent of the game type).
const RULES_STANDARD := "standard"
const RULES_SHUFFLE := "shuffle"
const RULES_POKER := "poker"

# --- Stacking -----------------------------------------------------------------

## How strongly a powerup applies at a given stack count (1.0 at one stack).
static func stack_scale(def: PowerupDef, stacks: int) -> float:
	if stacks <= 1:
		return 1.0
	return def.stack_multiplier + (stacks - 1) * def.stack_bonus_per_card

static func max_uses(def: PowerupDef, stacks: int) -> int:
	if def.max_uses <= 0:
		return -1
	return def.max_uses + maxi(stacks - 1, 0) * def.uses_per_stack

## Stacks granted when using a card: poker plays the stacks of the card's poker
## hand (PokerRules), shuffle uses the merged inventory count, standard is one.
static func activation_stacks(def: PowerupDef, inventory_count: int, rules: String, poker_stacks: int) -> int:
	if rules == RULES_POKER:
		return clampi(poker_stacks, 1, def.max_stack_count)
	if rules == RULES_SHUFFLE:
		return clampi(inventory_count, 1, def.max_stack_count)
	return 1

# --- Active powerups ----------------------------------------------------------

static func new_entry(def: PowerupDef, stacks: int, now: int) -> Dictionary:
	var clamped := clampi(stacks, 1, def.max_stack_count)
	return {
		"def": def.id,
		"stacks": clamped,
		"expires_at": now + int(def.duration * 1000.0),
		"uses_left": max_uses(def, clamped),
	}

static func find(active: Array, def_id: StringName) -> Dictionary:
	for entry in active:
		if entry.def == def_id:
			return entry
	return {}

## Activates a card. Re-activating an active powerup refreshes it; outside
## poker rules the stacks add up (capped), under poker rules they are replaced.
static func activate(active: Array, def: PowerupDef, stacks: int, rules: String, now: int) -> Array:
	var next := without(active, def.id)
	var existing := find(active, def.id)
	var total := stacks
	if not existing.is_empty() and rules != RULES_POKER:
		total = existing.stacks + stacks
	next.append(new_entry(def, total, now))
	return next

static func without(active: Array, def_id: StringName) -> Array:
	return active.filter(func(entry): return entry.def != def_id)

static func expired_ids(active: Array, now: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in active:
		if now >= entry.expires_at or entry.uses_left == 0:
			out.append(entry.def)
	return out

## Spends one use. Returns the updated array; an entry reaching 0 uses is
## reported by expired_ids().
static func consume_use(active: Array, def_id: StringName) -> Array:
	var next: Array = []
	for entry in active:
		if entry.def == def_id and entry.uses_left > 0:
			var updated: Dictionary = entry.duplicate()
			updated.uses_left -= 1
			next.append(updated)
		else:
			next.append(entry)
	return next

static func remaining_fraction(entry: Dictionary, now: int) -> float:
	var def := PowerupDefs.get_def(entry.def)
	if def == null or def.duration <= 0.0:
		return 0.0
	return clampf((entry.expires_at - now) / (def.duration * 1000.0), 0.0, 1.0)

## Sum of every active stat modifier, scaled by stacks.
static func modifiers(active: Array) -> Dictionary:
	var out := {}
	for entry in active:
		var def := PowerupDefs.get_def(entry.def)
		if def == null:
			continue
		var scale := stack_scale(def, entry.stacks)
		for key in def.modifiers:
			out[key] = out.get(key, 0.0) + float(def.modifiers[key]) * scale
	return out

static func entry_with_ability(active: Array, ability: StringName) -> Dictionary:
	for entry in active:
		var def := PowerupDefs.get_def(entry.def)
		if def and def.ability == ability:
			return entry
	return {}

## Spread multiplier while dual wielding; more stacks tighten it.
static func dual_spread(def: PowerupDef, stacks: int) -> float:
	var p := def.ability_params
	var reduction: float = p.get("spread_reduction_per_stack", 0.0) * maxi(stacks - 1, 0)
	return float(p.get("spread", 0.0)) * maxf(1.0 - reduction, 0.0)

## {spread_degrees, shots_per_second} for a burst; more stacks tighten it.
static func burst_params(def: PowerupDef, stacks: int) -> Dictionary:
	var p := def.ability_params
	var base: float = p.get("spread_degrees", 12.0) * p.get("spread_multiplier", 1.0)
	var reduction: float = p.get("spread_reduction_per_stack", 0.0) * maxi(stacks - 1, 0)
	return {
		"spread_degrees": maxf(base * (1.0 - reduction), p.get("min_spread_degrees", 0.0)),
		"shots_per_second": float(p.get("shots_per_second", 18.0)),
	}

# --- Card abilities -------------------------------------------------------------

## Riot Shield: {hp, width, distance}. More stacks: more HP (stack scale) and wider.
static func shield_params(def: PowerupDef, stacks: int) -> Dictionary:
	var p := def.ability_params
	return {
		"hp": float(p.get("hp", 150.0)) * stack_scale(def, stacks),
		"width": float(p.get("width", 72.0)) + float(p.get("width_per_stack", 0.0)) * maxi(stacks - 1, 0),
		"distance": float(p.get("distance", 52.0)),
	}

## Shoulder Charge: {damage, knockback}. Damage scales with stacks.
static func charge_params(def: PowerupDef, stacks: int) -> Dictionary:
	var p := def.ability_params
	return {
		"damage": float(p.get("damage", 25.0)) * stack_scale(def, stacks),
		"knockback": float(p.get("knockback", 650.0)),
	}

## Piercing Rounds: extra players a shot passes through (0 = stops at the first).
static func pierce(active: Array) -> int:
	var entry := entry_with_ability(active, &"piercing")
	if entry.is_empty():
		return 0
	var p := PowerupDefs.get_def(entry.def).ability_params
	return int(p.get("pierce", 1)) + int(p.get("pierce_per_stack", 1)) * maxi(entry.stacks - 1, 0)

## The Last Stand entry that can still save its owner, or {}.
static func last_stand_entry(active: Array) -> Dictionary:
	var entry := entry_with_ability(active, &"last_stand")
	if entry.is_empty() or entry.uses_left == 0:
		return {}
	return entry

# --- Inventory ----------------------------------------------------------------

static func empty_inventory(slots: int) -> Array:
	var out: Array = []
	for i in range(slots):
		out.append({"def": &"", "count": 0, "hole": -1})
	return out

static func empty_slot(inventory: Array) -> int:
	for i in range(inventory.size()):
		if inventory[i].def == &"":
			return i
	return -1

static func with_slot(inventory: Array, index: int, def_id: StringName, count: int, hole: int = -1) -> Array:
	var next := inventory.duplicate(true)
	var empty := def_id == &""
	next[index] = {"def": def_id, "count": 0 if empty else count, "hole": -1 if empty else hole}
	return next

## Moves as many cards as fit from `source` onto a matching `target` stack.
static func merge(inventory: Array, source: int, target: int, max_stack: int) -> Array:
	var from: Dictionary = inventory[source]
	var to: Dictionary = inventory[target]
	if source == target or from.def == &"" or from.def != to.def or to.count >= max_stack:
		return inventory
	var moved := mini(from.count, max_stack - to.count)
	var next := with_slot(inventory, target, to.def, to.count + moved, to.get("hole", -1))
	var left: int = from.count - moved
	return with_slot(next, source, from.def if left > 0 else &"", left, from.get("hole", -1))
