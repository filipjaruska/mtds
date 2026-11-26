@tool
extends Node2D
class_name PowerupSpawner
## Puts cards on the map (the host decides; every peer shows them). Cards
## appear at random spots inside the area, which is drawn in the editor only.

## The card to spawn. Leave empty for a random card each time.
@export var powerup_def: PowerupDef
## Seconds between new cards.
@export var spawn_frequency: float = 15.0
## No new cards while this many are lying in the area.
@export var max_powerups: int = 5
## Off: no cards until something switches it on (set_enabled), like the card
## area of the blackjack room, which starts once the game there is over.
@export var enabled: bool = true
@export_group("Spawn Area")
## Off: every card appears exactly at this node.
@export var use_spawn_area: bool = true:
	set(value):
		use_spawn_area = value
		queue_redraw()
@export var spawn_area_size: Vector2 = Vector2(800, 600):
	set(value):
		spawn_area_size = value
		queue_redraw()

const FIRST_CARD_SECONDS := 2.0

var spawn_timer: Timer
var current_powerups: int = 0
var spawn_counter: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if multiplayer.is_server():
		spawn_timer = Timer.new()
		add_child(spawn_timer)
		spawn_timer.timeout.connect(_spawn_powerup)
		spawn_timer.start(spawn_frequency)

## Switches it on or off. Switched on, the first card comes after a moment.
func set_enabled(on: bool) -> void:
	enabled = on
	if on and multiplayer.is_server() and is_inside_tree():
		get_tree().create_timer(FIRST_CARD_SECONDS).timeout.connect(_spawn_powerup)

func _spawn_powerup() -> void:
	if not enabled or current_powerups >= max_powerups or not is_inside_tree():
		return
	var def_id: StringName = powerup_def.id if powerup_def else PowerupDefs.random_id()
	spawn_counter += 1
	_spawn_powerup_at.rpc(def_id, _get_spawn_position(), spawn_counter)

@rpc("authority", "call_local", "reliable")
func _spawn_powerup_at(def_id: StringName, spawn_position: Vector2, unique_id: int) -> void:
	var def := PowerupDefs.get_def(def_id)
	if def == null:
		return
	var pickup := PowerupPickup.create_pickup(def, spawn_position)
	# Include the spawner's name: several spawners share the same parent, and
	# the name must be identical on every peer for the pickup's RPCs.
	pickup.name = "Powerup_%s_%d" % [name, unique_id]
	get_parent().add_child(pickup)
	current_powerups += 1
	pickup.tree_exiting.connect(_on_powerup_removed)

func _on_powerup_removed() -> void:
	current_powerups = maxi(0, current_powerups - 1)

func _get_spawn_position() -> Vector2:
	if use_spawn_area and spawn_area_size != Vector2.ZERO:
		var half_size := spawn_area_size / 2
		return global_position + Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
	return global_position

func _draw() -> void:
	if not Engine.is_editor_hint() or not use_spawn_area:
		return
	var half_size := spawn_area_size / 2
	draw_rect(Rect2(-half_size, spawn_area_size), Color(0, 1, 0, 0.2), true)
	draw_rect(Rect2(-half_size, spawn_area_size), Color(0, 1, 0, 0.8), false, 3.0)
