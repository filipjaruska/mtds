extends BasePowerupCard
class_name DualWieldCard

var spread_reduction_per_stack: float = 0.15
var _ammo_snapshot: Dictionary = {}

func _init():
	type = PowerupType.DUAL_WIELD
	name = "Dual Wield"
	description = "Mirror your weapon to both hands. No reload. Stacking reduces spread."
	base_effect_value = 0.15
	duration = 20.0
	stack_multiplier = 1.0
	stack_bonus_per_card = 0.0
	max_stack_count = 4
	rarity_color = Color.CYAN

func get_stacked_effect_value(stack_count: int) -> float:
	return get_spread_penalty(stack_count)

func get_spread_penalty(stack_count: int) -> float:
	var extra := maxi(stack_count - 1, 0)
	return base_effect_value * maxf(1.0 - extra * spread_reduction_per_stack, 0.0)

func apply_effect(target_player: Node, effect_value: float) -> void:
	var weapon_manager = _get_weapon_manager(target_player)
	if not weapon_manager:
		return
	if weapon_manager.is_dual_wield_active():
		weapon_manager.update_dual_wield_spread(effect_value)
		return
	if not weapon_manager.enable_dual_wield(effect_value, _ammo_snapshot):
		var powerup_manager = target_player.get_node_or_null("PowerupManager")
		if powerup_manager:
			powerup_manager.call_deferred(
				"expire_active_powerup_of_type",
				BasePowerupCard.PowerupType.DUAL_WIELD
			)
	_ammo_snapshot = {}

func remove_effect(target_player: Node, _effect_value: float) -> void:
	var weapon_manager = _get_weapon_manager(target_player)
	# Clear snapshot on remove so an empty dual cannot be restarted with stale ammo.
	_ammo_snapshot = {}
	if not weapon_manager:
		return
	# Always force cleanup so a desynced dual flag cannot permanently lock switching.
	weapon_manager.disable_dual_wield()
