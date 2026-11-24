extends CardAbility
class_name DualWieldAbility
## A copy of your gun in the other hand. Behaviour: WeaponHolder / LoadoutRules.

## Extra spread while dual wielding. 0.15 = 15% more spread.
@export_range(0.0, 2.0, 0.01) var spread: float = 0.15
## Less extra spread per stack after the first. 0.15 = 15% less.
@export_range(0.0, 1.0, 0.01) var spread_reduction_per_stack: float = 0.15

func get_kind() -> StringName:
	return &"dual_wield"
