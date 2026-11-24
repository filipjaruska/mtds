@tool
extends Marker2D
class_name SpawnPoint
## Where a player starts and comes back after dying. Name them 0, 1, 2 ...
## (player 1 starts on 0 and so on). In team matches Red uses the even numbers
## and Blue the odd ones. In the editor it shows as a numbered circle in the
## team colour; in the game it is invisible.

const RADIUS := 22.0

func _enter_tree() -> void:
	add_to_group("PlayerSpawnLocation")
	if Engine.is_editor_hint() and not renamed.is_connected(queue_redraw):
		renamed.connect(queue_redraw)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var number := String(name).to_int()
	var color: Color = TeamRules.COLORS[number % TeamRules.TEAM_COUNT] if String(name).is_valid_int() else Color.GRAY
	draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.35))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, color, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-RADIUS, 7), String(name), HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 20, Color.WHITE)
