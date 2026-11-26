extends CharacterBody2D
## Tutankhamun's body: what shots hit and players bump into (physics layer 5
## "npcs"). Hits go to the event (TutankhamunEvent.on_hit). His look is the
## Look node in tutankhamun.tscn: placeholder sprites until he has art.

func _ready() -> void:
	add_to_group(CombatServer.SHOOTABLE)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func is_hittable() -> bool:
	var event := get_parent() as TutankhamunEvent
	return event != null and visible and event.state != TutankhamunRules.State.DEAD

## Host: a shot or swing hit him.
func take_hit(amount: float, shooter_id: int = 0) -> void:
	var event := get_parent() as TutankhamunEvent
	if event and is_hittable():
		event.on_hit(amount, shooter_id)
