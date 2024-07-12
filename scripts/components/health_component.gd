extends Node2D
class_name HealthComponent

# TODO FIX: not reusable anymore

@onready var UI = $"../Camera2D/UI"
@onready var heal_timer = $HealTimer

@export var MAX_HEALTH: float = 100.0
var current_health: float

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
	current_health = MAX_HEALTH
	UI.update_health(int(current_health), int(MAX_HEALTH))

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	current_health = new_health
	UI.update_health(int(current_health), int(MAX_HEALTH))

func damage(dmg: float, penetration: float):
	var final_dmg: float = dmg
	var effective_resist: float = max(physical_resist - penetration, 0.0)
	final_dmg = dmg * (1.0 - effective_resist)
	current_health -= final_dmg
	rpc("update_health", current_health)
	UI.update_health(int(current_health), int(MAX_HEALTH))

	heal_timer.start(5.0)

func heal(amount: float):
	current_health += amount
	if current_health > MAX_HEALTH:
		current_health = MAX_HEALTH
	rpc("update_health", current_health)
	UI.update_health(int(current_health), int(MAX_HEALTH))

func death():
	if current_health <= 0:
		get_parent().queue_free()

func _on_heal_timer_timeout():
	if get_parent().is_in_group("Player"):
		heal(MAX_HEALTH - current_health)