extends CharacterBody2D
## Shady Fella's body: what shots hit and players bump into (physics layer 5
## "npcs"). Hits go to the event (ShadyFellaEvent.on_hit). His look is the
## Look node in shady_fella.tscn: placeholder sprites until he has art; the
## cigarette's ember glows.

@onready var _cigarette: Sprite2D = $Look/Cigarette

func _ready() -> void:
	add_to_group(CombatServer.SHOOTABLE)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var glow := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	glow.tween_property(_cigarette, "self_modulate", Color(1.5, 1.35, 1.2), 0.9)
	glow.tween_property(_cigarette, "self_modulate", Color.WHITE, 0.9)

func is_hittable() -> bool:
	var event := get_parent() as ShadyFellaEvent
	return event != null and (event.state == ShadyFellaRules.State.ROAMING or event.state == ShadyFellaRules.State.BUSY)

## Host: a shot or swing hit him.
func take_hit(amount: float, shooter_id: int = 0) -> void:
	var event := get_parent() as ShadyFellaEvent
	if event:
		event.on_hit(amount, shooter_id)
