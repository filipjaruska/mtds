extends Area2D

@export var health_component: HealthComponent

func damage():
	if !health_component:
		return
	
	health_component.damage(5)


