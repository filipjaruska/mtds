extends CardAbility
class_name LastStandAbility
## A lethal hit leaves 1 HP instead (once per use of the card).
## Behaviour: HealthComponent.apply_damage.

## Seconds of invulnerability after surviving.
@export var invulnerable_seconds: float = 1.0

func get_kind() -> StringName:
	return &"last_stand"
