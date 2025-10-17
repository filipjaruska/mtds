extends BasePowerupCard
class_name ArmorCard

func _init():
	type = PowerupType.ARMOR
	name = "Steel Skin"
	description = "Reduces incoming damage by 15%"
	base_effect_value = 0.15
	duration = 40.0
	stack_multiplier = 1.5
	stack_bonus_per_card = 0.10
	rarity_color = Color.GRAY

func apply_effect(target_player: Node, effect_value: float):
	var health_component = _get_health_component(target_player)
	if not health_component:
		return
	if health_component.damage_resistance == null:
		health_component.damage_resistance = 0.0
	health_component.damage_resistance += effect_value

func remove_effect(target_player: Node, effect_value: float):
	var health_component = _get_health_component(target_player)
	if not health_component:
		return
	if health_component.damage_resistance == null:
		health_component.damage_resistance = 0.0
	health_component.damage_resistance -= effect_value
