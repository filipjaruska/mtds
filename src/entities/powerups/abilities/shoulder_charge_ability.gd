extends CardAbility
class_name ShoulderChargeAbility
## Dashing into a player damages and knocks them back. Behaviour: CardEffects.

## Damage at one stack; more stacks scale it like the card's stats.
@export var damage: float = 25.0
## How hard the target is pushed, in px/s.
@export var knockback: float = 650.0

func get_kind() -> StringName:
	return &"shoulder_charge"
