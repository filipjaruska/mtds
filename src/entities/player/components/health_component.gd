extends Node2D
class_name HealthComponent

@onready var UI = $"../CameraComponent/PlayerCamera/PlayerUI"
@onready var heal_timer = $HealthRegenTimer
@onready var health_bar = $"../PlayerHealthBar"

@export var MAX_HEALTH: float = 100.0
var current_health: float
var is_dying: bool = false

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
	current_health = MAX_HEALTH

	await get_tree().process_frame # wait one frame for all nodes to be ready
	if health_bar:
		health_bar.max_value = MAX_HEALTH
		health_bar.value = current_health
	update_ui()

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	current_health = new_health
	update_ui()
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	EventManager.emit_event(EventManager.Events.UI_HEALTH_UPDATED, [int(current_health), int(MAX_HEALTH)])

func damage(dmg: float, penetration: float):
	if dmg < 0.0:
		return
		
	var effective_resist: float = max(physical_resist - penetration, 0.0)
	var final_dmg: float = dmg * (1.0 - effective_resist)
	current_health -= final_dmg
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	rpc("update_health", current_health)
	update_ui()
	heal_timer.start(5.0)
	
	EventManager.emit_event(EventManager.Events.PLAYER_DAMAGED, [get_parent(), final_dmg, current_health])

func heal(amount: float):
	current_health = min(current_health + amount, MAX_HEALTH)
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	rpc("update_health", current_health)
	update_ui()
	
	EventManager.emit_event(EventManager.Events.PLAYER_HEALED, [get_parent(), amount, current_health])

func death():
	if current_health <= 0 and not is_dying:
		is_dying = true
		var player = get_parent()
		player.visible = false
		
		EventManager.emit_event(EventManager.Events.PLAYER_DIED, [player])
		
		await get_tree().create_timer(1.0).timeout
		respawn_player(player)

func respawn_player(player):
	player.visible = true
	player.position = get_spawn_location(player.name)
	current_health = MAX_HEALTH
	rpc("update_health", current_health)
	update_ui()

	EventManager.emit_event(EventManager.Events.PLAYER_RESPAWNED, [player])
	is_dying = false

func get_spawn_location(player_name: String) -> Vector2:
	for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
		if spawn.name == player_name:
			return spawn.global_position
	return Vector2.ZERO

func _on_heal_timer_timeout():
	if get_parent().is_in_group("Player"):
		heal(MAX_HEALTH - current_health)

func update_ui():
	if UI and is_instance_valid(UI):
		UI.update_health(int(current_health), int(MAX_HEALTH))
