extends BasePowerupCard
class_name ReloadSpeedCard

func _init():
	type = PowerupType.RELOAD_SPEED
	name = "Quick Reload"
	description = "Increases reload speed by 30%"
	base_effect_value = 0.30
	duration = 20.0
	stack_multiplier = 1.8
	stack_bonus_per_card = 0.10
	rarity_color = Color.YELLOW

func apply_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.reload_speed_multiplier == 0.0:
		weapon_manager.reload_speed_multiplier = 1.0
	weapon_manager.reload_speed_multiplier += effect_value

func remove_effect(target_player: Node, effect_value: float):
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.reload_speed_multiplier == 0.0:
		weapon_manager.reload_speed_multiplier = 1.0
	weapon_manager.reload_speed_multiplier -= effect_value
