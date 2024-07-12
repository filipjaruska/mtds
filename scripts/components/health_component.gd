extends Node2D
class_name HealthComponent

# TODO FIX: not reusable anymore

@onready var UI = $"../Camera2D/UI"
@onready var heal_timer = $HealTimer

@export var MAX_HEALTH: float = 100.0
var currentHealth: float

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
	currentHealth = MAX_HEALTH
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	currentHealth = new_health
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func damage(dmg: float, penetration: float):
	var final_dmg: float = dmg
	var effective_resist: float = max(physical_resist - penetration, 0.0)
	final_dmg = dmg * (1.0 - effective_resist)
	currentHealth -= final_dmg
	rpc("update_health", currentHealth)
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

	heal_timer.start(5.0)

func heal(amount: float):
	currentHealth += amount
	if currentHealth > MAX_HEALTH:
		currentHealth = MAX_HEALTH
	rpc("update_health", currentHealth)
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func death():
	if currentHealth <= 0:
		get_parent().queue_free()

func _on_heal_timer_timeout():
	if get_parent().is_in_group("Player"):
		heal(MAX_HEALTH - currentHealth)