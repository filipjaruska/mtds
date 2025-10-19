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
var spawn_counter: int = 0

func _ready():
	if multiplayer.is_server():
		spawn_timer = Timer.new()
		add_child(spawn_timer)
		spawn_timer.timeout.connect(_spawn_powerup)
		spawn_timer.start(spawn_frequency)
	queue_redraw()

func _spawn_powerup():
	if current_powerups >= max_powerups:
		return
	
	var powerup_type_index = _get_powerup_type_index()
	var spawn_position = _get_spawn_position()
	spawn_counter += 1
	
	_spawn_powerup_at.rpc(powerup_type_index, spawn_position, spawn_counter)

@rpc("authority", "call_local", "reliable")
func _spawn_powerup_at(powerup_type_index: int, spawn_position: Vector2, unique_id: int):
	var card = _create_card_by_index(powerup_type_index)
	var powerup_pickup = PowerupPickup.create_pickup(card, spawn_position)
	powerup_pickup.name = "PowerupPickup_" + str(unique_id)
	
	get_parent().add_child(powerup_pickup, true) # true = use deferred call
	current_powerups += 1
	powerup_pickup.tree_exiting.connect(_on_powerup_picked_up)

func _get_powerup_type_index() -> int:
	match spawn_type:
		SpawnType.SPEED_BOOST:
			return 0
		SpawnType.DAMAGE_BOOST:
			return 1
		SpawnType.HEALTH_BOOST:
			return 2
		SpawnType.RELOAD_SPEED:
			return 3
		SpawnType.FIRE_RATE:
			return 4
		SpawnType.ARMOR:
			return 5
		_:
			return randi() % 6 # Random

func _on_powerup_picked_up():
	current_powerups = max(0, current_powerups - 1)

func _create_card_by_index(index: int) -> BasePowerupCard:
	match index:
		0:
			return PowerupFactory.create_speed_boost()
		1:
			return PowerupFactory.create_damage_boost()
		2:
			return PowerupFactory.create_health_boost()
		3:
			return PowerupFactory.create_reload_speed()
		4:
			return PowerupFactory.create_fire_rate()
		5:
			return PowerupFactory.create_armor()
		_:
			return PowerupFactory.create_speed_boost()

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
