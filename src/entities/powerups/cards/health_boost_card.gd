extends BasePowerupCard
class_name HealthBoostCard

func _init():
	type = PowerupType.HEALTH_BOOST
	name = "Warmog"
	description = "Increases maximum health by 25%"
	base_effect_value = 0.25
	duration = 45.0
	stack_multiplier = 1.5
	stack_bonus_per_card = 0.15
	rarity_color = Color.BLUE

func apply_effect(target_player: Node, effect_value: float):
	var health_component = _get_health_component(target_player)
	if health_component and target_player.multiplayer.is_server():
		health_component.set_max_health_bonus(health_component.max_health_bonus + health_component.MAX_HEALTH * effect_value)

func remove_effect(target_player: Node, effect_value: float):
	var health_component = _get_health_component(target_player)
	if health_component and target_player.multiplayer.is_server():
		health_component.set_max_health_bonus(health_component.max_health_bonus - health_component.MAX_HEALTH * effect_value)
