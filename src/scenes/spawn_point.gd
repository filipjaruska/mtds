@tool
extends Marker2D
class_name SpawnPoint
## Where a player starts and comes back after dying. In team matches each team
## uses its own spawn points: `team`, or when that is Auto, even/odd numbers on
## fixed maps named 0, 1, 2 ... and the west/east half of the map otherwise.
## In the editor it shows as a circle in its team colour; in game it is invisible.

enum Team { AUTO = -1, RED = 0, BLUE = 1 }

const RADIUS := 22.0

## Which team spawns here in team matches.
@export var team: Team = Team.AUTO:
	set(value):
		team = value
		queue_redraw()

func _enter_tree() -> void:
	add_to_group("PlayerSpawnLocation")
	if Engine.is_editor_hint() and not renamed.is_connected(queue_redraw):
		renamed.connect(queue_redraw)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color.GRAY
	if team != Team.AUTO:
		color = TeamRules.COLORS[team]
	elif String(name).is_valid_int():
		color = TeamRules.COLORS[String(name).to_int() % TeamRules.TEAM_COUNT]
	draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.35))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, color, 3.0)
	var label := String(name) if String(name).length() <= 2 else "S"
	draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, 7), label, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 20, Color.WHITE)
