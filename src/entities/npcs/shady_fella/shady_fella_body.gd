extends CharacterBody2D
## Shady Fella's body: what shots hit and players bump into (physics layer 5
## "npcs"). Hits go to the event (ShadyFellaEvent.on_hit). The look is drawn
## here until he has art: a long dark coat, a wide hat and a glowing cigarette.

const COAT := Color(0.24, 0.2, 0.28)
const COAT_EDGE := Color(0.12, 0.1, 0.14)
const HAT := Color(0.1, 0.09, 0.11)
const BAND := Color(0.55, 0.12, 0.16)
const EMBER := Color(1.0, 0.55, 0.15)

func _ready() -> void:
	add_to_group(CombatServer.SHOOTABLE)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func is_hittable() -> bool:
	var event := get_parent() as ShadyFellaEvent
	return event != null and (event.state == ShadyFellaRules.State.ROAMING or event.state == ShadyFellaRules.State.BUSY)

## Host: a shot or swing hit him.
func take_hit(amount: float, shooter_id: int = 0) -> void:
	var event := get_parent() as ShadyFellaEvent
	if event:
		event.on_hit(amount, shooter_id)

func _process(_delta: float) -> void:
	queue_redraw() # the ember glows

func _draw() -> void:
	draw_circle(Vector2(3, 5), 24.0, Color(0, 0, 0, 0.3)) # shadow
	draw_circle(Vector2.ZERO, 22.0, COAT_EDGE)
	draw_circle(Vector2.ZERO, 19.0, COAT)
	draw_circle(Vector2(0, -2), 17.0, HAT) # brim, seen from above
	draw_arc(Vector2(0, -2), 10.0, 0.0, TAU, 24, BAND, 3.0)
	draw_circle(Vector2(0, -2), 9.0, HAT.lightened(0.08)) # crown
	var glow := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
	draw_line(Vector2(10, 8), Vector2(20, 12), Color(0.9, 0.9, 0.85), 3.0)
	draw_circle(Vector2(21, 12.5), 2.5, Color(EMBER, glow))
