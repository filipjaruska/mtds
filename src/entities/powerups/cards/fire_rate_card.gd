extends BasePowerupCard
class_name FireRateCard

func _init():
	type = PowerupType.FIRE_RATE
	name = "Rapid Fire"
	description = "Increases fire rate by 25%"
	base_effect_value = 0.25
	duration = 20.0
	stack_multiplier = 2.0
	stack_bonus_per_card = 0.05
	rarity_color = Color.ORANGE

func apply_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.fire_rate_multiplier == 0.0:
		weapon_manager.fire_rate_multiplier = 1.0
	weapon_manager.fire_rate_multiplier += effect_value

func remove_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.fire_rate_multiplier == 0.0:
		weapon_manager.fire_rate_multiplier = 1.0
	weapon_manager.fire_rate_multiplier -= effect_value
