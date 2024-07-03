extends Node2D
class_name HealthComponent

@export var MAX_HEALTH: float = 10.0
var currentHealth: float
# Called when the node enters the scene tree for the first time.
func _ready():
	currentHealth = MAX_HEALTH

func damage(dmg: float):
	currentHealth -= dmg

	if currentHealth <= 0:
		get_parent().queue_free()

func heal(amount: float):
	currentHealth += amount
	if currentHealth > MAX_HEALTH:
		currentHealth = MAX_HEALTH
