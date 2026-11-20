extends RefCounted
class_name HandLayout
## Pure layout math for the hand of cards (PowerupHandUI). Positions are the
## bottom-centre of each card, relative to the hand's origin (bottom-centre of
## the screen); rotation turns around that point, so the fan opens upwards.

## Size a card is drawn at (the PNGs are 160x224).
const CARD_SIZE := Vector2(88, 123)
## Distance between neighbouring cards in the fan; less than the width so they overlap.
const SPACING := 62.0
## Degrees between neighbouring cards.
const FAN_DEGREES := 6.0
## How much lower each step away from the centre sits (makes the arc).
const ARC_DROP := 5.0
## Selected / merging cards rise out of the hand.
const LIFT := 30.0
## Details mode: cards side by side, bigger, not overlapping.
const SPREAD_SPACING := 150.0
const SPREAD_SCALE := 1.3
const SPREAD_RAISE := 12.0
## Stacked copies behind a card (shuffle merges): shown up to this many.
const MAX_PILE_SHOWN := 3

## state: &"normal", &"lifted" or &"spread".
## Returns {position: Vector2, rotation: float (radians), scale: float}.
static func slot_transform(index: int, slot_count: int, state: StringName) -> Dictionary:
	var centered := index - (slot_count - 1) / 2.0
	if state == &"spread":
		return {"position": Vector2(centered * SPREAD_SPACING, -SPREAD_RAISE), "rotation": 0.0, "scale": SPREAD_SCALE}
	var position := Vector2(centered * SPACING, centered * centered * ARC_DROP)
	var scale := 1.0
	if state == &"lifted":
		position.y -= LIFT
		scale = 1.08
	return {"position": position, "rotation": deg_to_rad(centered * FAN_DEGREES), "scale": scale}

## Copies drawn behind a card with `count` stacked, nearest first:
## [{offset: Vector2, rotation: float, shade: float (0 = black, 1 = unchanged)}].
static func pile_offsets(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in range(1, mini(count, MAX_PILE_SHOWN + 1)):
		out.append({
			"offset": Vector2(-7.0, -7.0) * k,
			"rotation": deg_to_rad(-3.0 * k),
			"shade": 1.0 - 0.22 * k,
		})
	return out

## Works out what changed between two inventories (arrays of {def, count} per
## slot) so the hand can pick an animation. `played` is the slot the player
## just used, or -1. Returns [{kind, slot, from}] with kind one of
## &"collected", &"merged" (from = source slot), &"played", &"cleared".
static func diff(before: Array, after: Array, played: int) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var lost := {} # slot -> def that lost cards
	for i in range(mini(before.size(), after.size())):
		var a: Dictionary = before[i]
		var b: Dictionary = after[i]
		if a.def != &"" and (b.def != a.def or b.count < a.count):
			lost[i] = a.def
	for i in range(mini(before.size(), after.size())):
		var a: Dictionary = before[i]
		var b: Dictionary = after[i]
		if b.def == &"" or (b.def == a.def and b.count <= a.count):
			continue
		var source := -1
		for j in lost:
			if lost[j] == b.def and j != i:
				source = j
		if source >= 0 and a.def == b.def:
			changes.append({"kind": &"merged", "slot": i, "from": source})
			lost.erase(source)
		else:
			changes.append({"kind": &"collected", "slot": i, "from": -1})
	for i in lost:
		changes.append({"kind": &"played" if i == played else &"cleared", "slot": i, "from": -1})
	return changes
