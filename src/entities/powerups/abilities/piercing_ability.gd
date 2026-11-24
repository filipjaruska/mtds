extends CardAbility
class_name PiercingAbility
## Shots pass through players. Behaviour: CombatServer.

## Players a shot passes through at one stack.
@export var pierce: int = 1
## Extra players per stack after the first.
@export var pierce_per_stack: int = 1

func get_kind() -> StringName:
	return &"piercing"
