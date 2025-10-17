extends Node2D
class_name HealthComponent

@onready var UI = $"../CameraComponent/PlayerCamera/PlayerUI"
@onready var heal_timer = $HealthRegenTimer
@onready var health_bar = $"../PlayerHealthBar"

@export var MAX_HEALTH: float = 100.0
var max_health: float
var current_health: float
var is_dying: bool = false

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0
var damage_resistance: float = 0.0

func _ready():
	max_health = MAX_HEALTH
	current_health = max_health

	await get_tree().process_frame
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	update_ui()

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	current_health = new_health
	var player = get_parent()
	if player and player.is_multiplayer_authority():
		update_ui()
		EventManager.emit_event(EventManager.Events.UI_HEALTH_UPDATED, [int(current_health), int(max_health)])
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health

func damage(dmg: float, penetration: float):
	if dmg < 0.0:
		return
		
	var total_resist: float = max(physical_resist + damage_resistance - penetration, 0.0)
	var final_dmg: float = dmg * (1.0 - total_resist)
	current_health -= final_dmg
	if health_bar and is_instance_valid(health_bar):
		health_bar.value = current_health
	rpc("update_health", current_health)
	update_ui()
	heal_timer.start(5.0)
	
	EventManager.emit_event(EventManager.Events.PLAYER_DAMAGED, [get_parent(), final_dmg, current_health])

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
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
	current_health = max_health
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
		heal(max_health - current_health)

func update_ui():
	if UI and is_instance_valid(UI):
		UI.update_health(int(current_health), int(max_health))
