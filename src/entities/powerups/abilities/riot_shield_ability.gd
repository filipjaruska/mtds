extends CardAbility
class_name RiotShieldAbility
## Raises a shield in front of the player that blocks shots until it breaks.
## Behaviour: CardEffects and RiotShield.

## Shield health at one stack; more stacks scale it like the card's stats.
@export var hp: float = 150.0
## Width at one stack, in pixels.
@export var width: float = 72.0
## Extra width per stack after the first.
@export var width_per_stack: float = 16.0
## How far in front of the player it stands.
@export var distance: float = 52.0

func get_kind() -> StringName:
	return &"riot_shield"
