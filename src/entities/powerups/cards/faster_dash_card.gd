extends BasePowerupCard
class_name FasterDashCard

func _init():
	type = BasePowerupCard.PowerupType.FASTER_DASH
	name = "Quick Dash"
	description = "Reduces dash cooldown by 25%"
	base_effect_value = 0.25
	duration = 30.0
	stack_multiplier = 2.0
	stack_bonus_per_card = 0.05
	rarity_color = Color.GREEN

func apply_effect(target_player: Node, effect_value: float) -> void:
	var player_controller = _get_player_controller(target_player)
	if not player_controller:
		return
	player_controller.apply_dash_cooldown_reduction(effect_value)

func remove_effect(target_player: Node, effect_value: float) -> void:
	var player_controller = _get_player_controller(target_player)
	if not player_controller:
		return
	player_controller.remove_dash_cooldown_reduction(effect_value)
