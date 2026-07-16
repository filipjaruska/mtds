extends Node2D
class_name HealthComponent

@onready var heal_timer = $HealthRegenTimer
@onready var health_bar = $"../PlayerHealthBar"

@export var MAX_HEALTH: float = 100.0
var max_health: float
var current_health: float
var is_dying: bool = false

@export var physical_resist: float = 0.0 # Percentage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0
@export var regen_delay_after_damage: float = 5.0
@export_range(0.0, 1.0, 0.01) var regen_percent_per_tick: float = 0.10
@export var regen_tick_interval: float = 1.0
var damage_resistance: float = 0.0
var _waiting_for_regen: bool = false

func _ready():
	max_health = MAX_HEALTH
	current_health = max_health

	await get_tree().process_frame
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	_broadcast_health_change()

func _process(_delta):
	death()

@rpc("any_peer", "reliable")
func update_health(new_health: float, new_max_health: float = -1.0):
	if new_max_health > 0.0:
		max_health = new_max_health
	current_health = new_health
	_broadcast_health_change()

func sync_health_state() -> void:
	if get_parent() and get_parent().is_multiplayer_authority():
		rpc("update_health", current_health, max_health)
	_broadcast_health_change()

func damage(dmg: float, penetration: float, attacker_id: int = -1):
	if dmg < 0.0:
		return

	var total_resist: float = max(physical_resist + damage_resistance - penetration, 0.0)
	var final_dmg: float = dmg * (1.0 - total_resist)
	var was_alive: bool = current_health > 0.0
	current_health -= final_dmg
	rpc("update_health", current_health, max_health)
	_broadcast_health_change()
	_start_regen_delay()

	EventManager.emit_event(EventManager.Events.PLAYER_DAMAGED, [get_parent(), final_dmg, current_health])
	
	if attacker_id > 0 and final_dmg > 0.0:
		GameManager.report_damage_dealt.rpc_id(1, attacker_id, final_dmg)
		if was_alive and current_health <= 0.0:
			var victim_id: int = int(get_parent().name)
			GameManager.report_player_death.rpc_id(1, victim_id, attacker_id)

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
	rpc("update_health", current_health, max_health)
	_broadcast_health_change()

	EventManager.emit_event(EventManager.Events.PLAYER_HEALED, [get_parent(), amount, current_health])

func death():
	if current_health <= 0 and not is_dying:
		_stop_regen()
		is_dying = true
		var player = get_parent()
		player.visible = false

		var powerup_manager = player.get_node_or_null("PowerupManager")
		if powerup_manager:
			powerup_manager.clear_inventory_on_death()
			powerup_manager.clear_active_powerups_on_death()

		var weapon_manager = player.get_node_or_null("PlayerController/WeaponManager")
		if weapon_manager:
			weapon_manager.reset_weapons_on_death()

		EventManager.emit_event(EventManager.Events.PLAYER_DIED, [player])

		await get_tree().create_timer(1.0).timeout
		respawn_player(player)

func respawn_player(player):
	player.visible = true
	player.global_position = get_random_spawn_location()
	current_health = max_health
	rpc("update_health", current_health, max_health)
	_broadcast_health_change()

	EventManager.emit_event(EventManager.Events.PLAYER_RESPAWNED, [player])
	is_dying = false

func get_random_spawn_location() -> Vector2:
	var spawns := get_tree().get_nodes_in_group("PlayerSpawnLocation")
	if spawns.is_empty():
		return Vector2.ZERO
	return spawns.pick_random().global_position

func _start_regen_delay() -> void:
	if regen_percent_per_tick <= 0.0 or current_health >= max_health:
		return

	_waiting_for_regen = true
	heal_timer.stop()
	heal_timer.one_shot = true
	heal_timer.wait_time = regen_delay_after_damage
	heal_timer.start()

func _schedule_regen_tick() -> void:
	if current_health >= max_health:
		_stop_regen()
		return

	heal_timer.one_shot = true
	heal_timer.wait_time = regen_tick_interval
	heal_timer.start()

func _apply_regen_tick() -> void:
	if not get_parent().is_in_group("Player"):
		return

	if current_health >= max_health:
		_stop_regen()
		return

	var heal_amount := max_health * regen_percent_per_tick
	heal(heal_amount)

	if current_health < max_health:
		_schedule_regen_tick()
	else:
		_stop_regen()

func _stop_regen() -> void:
	_waiting_for_regen = false
	heal_timer.stop()

func _on_heal_timer_timeout() -> void:
	if _waiting_for_regen:
		_waiting_for_regen = false
		_apply_regen_tick()
		return

	_apply_regen_tick()

func _broadcast_health_change():
	if health_bar and is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = current_health
	EventManager.emit_event(EventManager.Events.UI_HEALTH_UPDATED, [get_parent(), int(current_health), int(max_health)])
