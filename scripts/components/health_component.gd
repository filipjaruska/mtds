extends Node2D
class_name HealthComponent

@export var MAX_HEALTH: float = 10.0
var currentHealth: float

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
    currentHealth = MAX_HEALTH

func damage(dmg: float, penetration: float = 0.0):
    var final_dmg: float = dmg
    
    var effective_resist: float = max(physical_resist - penetration, 0.0)
    final_dmg = dmg * (1.0 - effective_resist)

    currentHealth -= final_dmg

    if currentHealth <= 0:
        get_parent().queue_free()

func heal(amount: float):
    currentHealth += amount
    if currentHealth > MAX_HEALTH:
        currentHealth = MAX_HEALTH