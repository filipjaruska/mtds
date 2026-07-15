extends BasePowerupCard
class_name BurstCard

var spread_multiplier: float = 4.0
var burst_fire_rate: float = 18.0
var burst_spread_degrees: float = 12.0
var spread_reduction_per_stack: float = 0.2
var min_burst_spread_degrees: float = 8.0

func _init():
	type = BasePowerupCard.PowerupType.BURST
	name = "Burst Fire"
	description = "Once while active, empty your magazine in a spread burst. Stacking tightens the spread."
	base_effect_value = 0.0
	duration = 10.0
	max_uses = 1
	use_trigger = BasePowerupCard.UseTrigger.NONE
	stack_multiplier = 1.0
	stack_bonus_per_card = 0.0
	max_stack_count = 4
	rarity_color = Color.ORANGE

func apply_effect(_target_player: Node, _effect_value: float) -> void:
	pass

func remove_effect(_target_player: Node, _effect_value: float) -> void:
	pass

func get_burst_spread_degrees(stack_count: int) -> float:
	var base_spread := burst_spread_degrees * spread_multiplier
	var extra_stacks := maxi(stack_count - 1, 0)
	var reduction_factor := 1.0 - extra_stacks * spread_reduction_per_stack
	return maxf(base_spread * reduction_factor, min_burst_spread_degrees)

func execute_burst(weapon: RangedWeapon, stack_count: int = 1) -> void:
	weapon.burst_fire(get_burst_spread_degrees(stack_count), burst_fire_rate)
