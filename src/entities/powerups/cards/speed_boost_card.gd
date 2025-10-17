extends BasePowerupCard
class_name SpeedBoostCard

func _init():
	type = PowerupType.SPEED_BOOST
	name = "Speed Surge"
	description = "Increases movement speed by 15%"
	base_effect_value = 0.15
	duration = 30.0
	stack_multiplier = 2.0
	stack_bonus_per_card = 0.05
	rarity_color = Color.GREEN

func apply_effect(target_player: Node, effect_value: float):
	var player_controller = _get_player_controller(target_player)
	if not player_controller:
		return
	player_controller.normal_speed += player_controller.normal_speed * effect_value
	player_controller._recompute_current_speed()

func remove_effect(target_player: Node, effect_value: float):
	var player_controller = _get_player_controller(target_player)
	if not player_controller:
		return
	player_controller.normal_speed -= player_controller.normal_speed * effect_value / (1.0 + effect_value)
	player_controller._recompute_current_speed()
