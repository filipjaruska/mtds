extends Resource
class_name CardModifiers
## Stat bonuses a card gives while it is active. Every value is scaled by the
## card's stacks (see Stacking on the card). Leave a value at 0 for no effect.
##
## To add a new stat: add a field here, add it to to_dict(), and read it where
## the stat is used (the key is the field name, see PowerupManager.get_modifiers).

## More weapon damage. 0.2 = +20%.
@export_range(0.0, 2.0, 0.01) var damage_mult: float = 0.0
## Faster reloads. 0.3 = reloads take 30% less time.
@export_range(0.0, 0.9, 0.01) var reload_mult: float = 0.0
## Less damage taken. 0.15 = 15% less.
@export_range(0.0, 0.9, 0.01) var damage_resist: float = 0.0
## More max health. 0.25 = +25%.
@export_range(0.0, 2.0, 0.01) var max_health_mult: float = 0.0
## Shorter dash cooldown. 0.25 = 25% shorter (capped at 90% in total).
@export_range(0.0, 0.9, 0.01) var dash_cooldown_reduction: float = 0.0
## Faster walking (and crouching). 0.15 = 15% faster.
@export_range(0.0, 1.0, 0.01) var move_speed_mult: float = 0.0

## The non-zero values by name, e.g. {"damage_mult": 0.2}.
func to_dict() -> Dictionary:
	var out := {}
	for key in ["damage_mult", "reload_mult", "damage_resist", "max_health_mult", "dash_cooldown_reduction", "move_speed_mult"]:
		var value: float = get(key)
		if value != 0.0:
			out[key] = value
	return out
