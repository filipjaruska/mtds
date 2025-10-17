extends Node2D
class_name PowerupSpawner

enum SpawnType {
	RANDOM,
	SPEED_BOOST,
	DAMAGE_BOOST,
	HEALTH_BOOST,
	RELOAD_SPEED,
	FIRE_RATE,
	ARMOR
}

@export var spawn_type: SpawnType = SpawnType.RANDOM
@export var spawn_frequency: float = 15.0
@export var max_powerups: int = 5
@export_group("Spawn Area")
@export var use_spawn_area: bool = true
@export var spawn_area_size: Vector2 = Vector2(800, 600)

var spawn_timer: Timer
var current_powerups: int = 0

func _ready():
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_powerup)
	spawn_timer.start(spawn_frequency)
	queue_redraw()

func _spawn_powerup():
	if current_powerups >= max_powerups:
		return
	
	var card = _create_card_by_type()
	var spawn_position = _get_spawn_position()
	var powerup_pickup = PowerupPickup.create_pickup(card, spawn_position)
	
	get_parent().add_child(powerup_pickup)
	current_powerups += 1
	powerup_pickup.tree_exiting.connect(_on_powerup_picked_up)

func _on_powerup_picked_up():
	current_powerups = max(0, current_powerups - 1)

func _create_card_by_type() -> BasePowerupCard:
	match spawn_type:
		SpawnType.SPEED_BOOST:
			return PowerupFactory.create_speed_boost()
		SpawnType.DAMAGE_BOOST:
			return PowerupFactory.create_damage_boost()
		SpawnType.HEALTH_BOOST:
			return PowerupFactory.create_health_boost()
		SpawnType.RELOAD_SPEED:
			return PowerupFactory.create_reload_speed()
		SpawnType.FIRE_RATE:
			return PowerupFactory.create_fire_rate()
		SpawnType.ARMOR:
			return PowerupFactory.create_armor()
		_:
			return PowerupFactory.create_random_powerup()

func _get_spawn_position() -> Vector2:
	if use_spawn_area and spawn_area_size != Vector2.ZERO:
		var half_size = spawn_area_size / 2
		var random_offset = Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		return global_position + random_offset
	else:
		return global_position

func _draw():
	if not use_spawn_area:
		return
	
	var half_size = spawn_area_size / 2
	draw_rect(Rect2(-half_size, spawn_area_size), Color(0, 1, 0, 0.2), true)
	draw_rect(Rect2(-half_size, spawn_area_size), Color(0, 1, 0, 0.8), false, 3.0)
