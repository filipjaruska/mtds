extends Node2D
class_name HealthComponent

# TODO FIX: not reusable anymore

@onready var UI = $"../Camera2D/UI"
@onready var heal_timer = $HealTimer

@export var MAX_HEALTH: float = 100.0
var current_health: float

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0

func _ready():
	current_health = MAX_HEALTH
	update_ui()

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float):
	current_health = new_health
	update_ui()

func damage(dmg: float, penetration: float):
	if dmg < 0.0:
		return
	var effective_resist: float = max(physical_resist - penetration, 0.0)
	var final_dmg: float = dmg * (1.0 - effective_resist)
	current_health -= final_dmg
	rpc("update_health", current_health)
	update_ui()
	heal_timer.start(5.0)

func heal(amount: float):
	current_health = min(current_health + amount, MAX_HEALTH)
	rpc("update_health", current_health)
	update_ui()

func death():
	if current_health <= 0:
		print("Player died")
		var player = get_parent()
		player.visible = false
		await get_tree().create_timer(1.0).timeout
		print("Time out done")
		respawn_player(player)
		print("Player respawned")

func respawn_player(player):
	player.visible = true
	player.position = get_spawn_location(player.name)
	current_health = MAX_HEALTH
	update_ui()

func get_spawn_location(player_name: String) -> Vector2:
	for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
		if spawn.name == player_name:
			return spawn.global_position
	return Vector2.ZERO

func _on_heal_timer_timeout():
	if get_parent().is_in_group("Player"):
		heal(MAX_HEALTH - current_health)

func update_ui():
	UI.update_health(int(current_health), int(MAX_HEALTH))
