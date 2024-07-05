extends Area2D

@export var health_component: HealthComponent

func damage() -> void:
	if !health_component:
		return
	
	health_component.damage(5)


