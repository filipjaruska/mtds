extends Node2D
class_name HealthComponent

@onready var UI = $"../Camera2D/UI"

@export var MAX_HEALTH: float = 100.0
var currentHealth: float

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
	currentHealth = MAX_HEALTH
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func _process(delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	currentHealth = new_health
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func damage(dmg: float, penetration: float = 0.0):
	var final_dmg: float = dmg
	var effective_resist: float = max(physical_resist - penetration, 0.0)
	final_dmg = dmg * (1.0 - effective_resist)
	currentHealth -= final_dmg
	rpc("update_health", currentHealth)
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func heal(amount: float):
	currentHealth += amount
	if currentHealth > MAX_HEALTH:
		currentHealth = MAX_HEALTH
	rpc("update_health", currentHealth)
	UI.update_health(int(currentHealth), int(MAX_HEALTH))

func death():
	if currentHealth <= 0:
		get_parent().queue_free()