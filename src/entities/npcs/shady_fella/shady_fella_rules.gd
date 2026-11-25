extends RefCounted
class_name ShadyFellaRules
## Pure rules for Shady Fella: what he offers and who may trade with him.
## Nothing here touches nodes or the network.

enum State { ROAMING, BUSY, FLEEING, LEAVING }

## `count` different cards picked from `ids` (fewer when there are not enough).
static func roll_offer(ids: Array, count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var pool := ids.duplicate()
	var offer: Array[StringName] = []
	while offer.size() < count and not pool.is_empty():
		offer.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return offer

## Why `peer` may not open the trade right now, or "" when it may.
## `picked`: peers that already took a card from him.
static func open_refusal(state: State, chooser: int, peer: int, picked: Dictionary, offer: Array,
		distance: float, reach: float, has_room: bool) -> String:
	if state == State.FLEEING or state == State.LEAVING or offer.is_empty():
		return "gone"
	if picked.has(peer):
		return "already picked"
	if chooser != 0 and chooser != peer:
		return "busy"
	if distance > reach:
		return "too far"
	if not has_room:
		return "hands full"
	return ""

## Whether `peer` may take card `index` of the offer now.
static func can_pick(state: State, chooser: int, peer: int, offer: Array, index: int, distance: float, reach: float, has_room: bool) -> bool:
	return state == State.BUSY and chooser == peer and index >= 0 and index < offer.size() \
		and distance <= reach and has_room

## Shot: one card he still has drops (random), the rest go with him.
static func dropped_card(offer: Array, rng: RandomNumberGenerator) -> StringName:
	return offer[rng.randi_range(0, offer.size() - 1)] if not offer.is_empty() else &""
