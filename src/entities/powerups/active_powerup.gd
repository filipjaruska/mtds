extends Node
class_name ActivePowerup

var powerup_card: BasePowerupCard
var stack_count: int = 1
var remaining_duration: float
var effect_value: float
var target_player: Node

signal powerup_expired(active_powerup: ActivePowerup)

func _init(card: BasePowerupCard, player: Node, initial_stack_count: int = 1):
	powerup_card = card
	target_player = player
	stack_count = initial_stack_count
	remaining_duration = card.duration
	effect_value = card.get_stacked_effect_value(stack_count)

func _ready():
	set_process(true)
	apply_effect()

func _process(delta):
	if target_player and target_player.is_multiplayer_authority():
		remaining_duration -= delta
		if remaining_duration <= 0:
			powerup_expired.emit(self)
			remove_effect()
			queue_free()

func apply_effect():
	if not target_player or not powerup_card:
		return
	powerup_card.apply_effect(target_player, effect_value)

func remove_effect():
	if not target_player or not powerup_card:
		return
	powerup_card.remove_effect(target_player, effect_value)

func add_stack(additional_cards: int = 1):
	stack_count += additional_cards
	stack_count = min(stack_count, powerup_card.max_stack_count)
	
	remove_effect()
	effect_value = powerup_card.get_stacked_effect_value(stack_count)
	apply_effect()
	remaining_duration = powerup_card.duration

func get_remaining_time_percentage() -> float:
	return remaining_duration / powerup_card.duration
