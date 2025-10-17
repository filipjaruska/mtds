extends BasePowerupCard
class_name DamageBoostCard

func _init():
	type = PowerupType.DAMAGE_BOOST
	name = "Power Strike"
	description = "Increases weapon damage by 20%"
	base_effect_value = 0.20
	duration = 25.0
	stack_multiplier = 2.0
	stack_bonus_per_card = 0.10
	rarity_color = Color.RED

func apply_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.damage_multiplier == 0.0:
		weapon_manager.damage_multiplier = 1.0
	weapon_manager.damage_multiplier += effect_value

func remove_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.damage_multiplier == 0.0:
		weapon_manager.damage_multiplier = 1.0
	weapon_manager.damage_multiplier -= effect_value
