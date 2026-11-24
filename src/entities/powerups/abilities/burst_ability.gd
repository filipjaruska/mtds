extends CardAbility
class_name BurstAbility
## Empties the magazine in one fast, spread-out burst.
## Behaviour: WeaponHolder / WeaponRules.

## Base spread of the burst, in degrees...
@export var spread_degrees: float = 12.0
## ...multiplied by this.
@export var spread_multiplier: float = 4.0
## Tighter per stack after the first. 0.2 = 20% less spread per stack.
@export_range(0.0, 1.0, 0.01) var spread_reduction_per_stack: float = 0.2
## The spread never goes below this.
@export var min_spread_degrees: float = 8.0
@export var shots_per_second: float = 18.0

func get_kind() -> StringName:
	return &"burst"
