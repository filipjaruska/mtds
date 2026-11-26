extends CharacterBody2D
class_name NpcBody
## The body of an event's NPC (Shady Fella, Tutankhamun...): what shots hit and
## players bump into, on physics layer 5 "npcs". Its parent is the event, which
## decides: is_hittable() and on_hit(amount, shooter_id).

func _ready() -> void:
	add_to_group(CombatServer.SHOOTABLE)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func is_hittable() -> bool:
	var event := get_parent()
	return visible and event != null and event.has_method("is_hittable") and event.is_hittable()

## Host: a shot or a blade hit it.
func take_hit(amount: float, shooter_id: int = 0) -> void:
	if is_hittable():
		get_parent().on_hit(amount, shooter_id)
