extends Node2D
class_name HealthComponent
## Health is owned by the host. Only the host applies damage, heals, runs
## regeneration and decides deaths/respawns; every peer (including the host)
## receives the result through the _sync/_on_* RPCs below.

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector
var RESPAWN_DELAY: float = RULES.respawn_seconds

@onready var heal_timer: Timer = $HealthRegenTimer
@onready var health_bar = $"../PlayerHealthBar"
@onready var powerup_manager: PowerupManager = get_node_or_null("../PowerupManager")

## Base maximum health (set from the player's inspector values).
@export var MAX_HEALTH: float = 100.0
@export var physical_resist: float = 0.0 # fraction, 0.15 = 15% less damage
@export var resist_penetration: float = 0.0 # 0.0 to 1.0
@export var regen_delay_after_damage: float = 5.0
@export_range(0.0, 1.0, 0.01) var regen_percent_per_tick: float = 0.10
@export var regen_tick_interval: float = 1.0

var max_health: float
var current_health: float
var is_dead: bool = false

var max_health_bonus: float = 0.0
## Host: no damage is taken before this time (msec), set by Last Stand.
var invulnerable_until: int = 0

func _ready() -> void:
	max_health = MAX_HEALTH
	current_health = max_health
	heal_timer.one_shot = true
	if powerup_manager:
		powerup_manager.active_changed.connect(_on_powerups_changed)
	call_deferred("_broadcast_health_change")

## Called by the player root with its configured max health.
func set_base_max_health(value: float) -> void:
	MAX_HEALTH = value
	_recompute_max_health()

## The host derives max health from the player's active powerups.
func _on_powerups_changed(_active: Array) -> void:
	if not _is_host():
		return
	var bonus: float = MAX_HEALTH * float(powerup_manager.get_modifiers().get("max_health_mult", 0.0))
	if not is_equal_approx(bonus, max_health_bonus):
		max_health_bonus = bonus
		_recompute_max_health()

func _damage_resistance() -> float:
	if powerup_manager == null:
		return 0.0
	return float(powerup_manager.get_modifiers().get("damage_resist", 0.0))

## Raising max health also grants the difference; lowering it clamps.
func _recompute_max_health() -> void:
	var new_max := MAX_HEALTH + max_health_bonus
	if is_equal_approx(new_max, max_health):
		return
	if new_max > max_health:
		current_health += new_max - max_health
	max_health = new_max
	current_health = minf(current_health, max_health)
	if _is_host():
		_sync_health.rpc(current_health, max_health, 0.0)
	else:
		_broadcast_health_change()

# --- Host only ----------------------------------------------------------------

func apply_damage(amount: float, penetration: float, attacker_id: int) -> void:
	if not _is_host() or is_dead or Time.get_ticks_msec() < invulnerable_until:
		return
	var final_damage := DamageRules.final_damage(amount, penetration, physical_resist + _damage_resistance())
	if final_damage <= 0.0:
		return
	var result := DamageRules.apply(current_health, final_damage)
	if result.died and _try_last_stand():
		final_damage = current_health - 1.0
		result = {"health": 1.0, "died": false}
	current_health = result.health
	if attacker_id > 0:
		GameManager.record_damage(attacker_id, final_damage)
	_sync_health.rpc(current_health, max_health, -final_damage)
	if result.died:
		_die(attacker_id)
	else:
		_start_regen_delay()

## Warmog's Last Stand: a lethal hit leaves 1 HP and a moment of invulnerability.
func _try_last_stand() -> bool:
	if powerup_manager == null:
		return false
	var entry := PowerupRules.last_stand_entry(powerup_manager.active)
	if entry.is_empty():
		return false
	var def := PowerupDefs.get_def(entry.def)
	invulnerable_until = Time.get_ticks_msec() + int((def.ability as LastStandAbility).invulnerable_seconds * 1000.0)
	powerup_manager.host_consume_use(entry.def)
	var effects := get_parent().get_node_or_null("CardEffects")
	if effects:
		effects.play_last_stand.rpc()
	return true

func heal(amount: float) -> void:
	if not _is_host() or is_dead:
		return
	var healed := minf(amount, max_health - current_health)
	if healed <= 0.0:
		return
	current_health += healed
	_sync_health.rpc(current_health, max_health, healed)

func _die(attacker_id: int) -> void:
	is_dead = true
	heal_timer.stop()
	GameManager.record_death(get_multiplayer_authority(), attacker_id)
	var killer := get_parent().get_parent().get_node_or_null(str(attacker_id)) if attacker_id > 0 else null
	if killer and killer != get_parent() and killer.has_node("CardEffects"):
		killer.get_node("CardEffects").notify_kill()
	_on_died.rpc()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return
	current_health = max_health
	_on_respawned.rpc(get_random_spawn_location(), current_health, max_health)

## In team matches players respawn on their own team's side (see TeamRules).
func get_random_spawn_location() -> Vector2:
	var by_index := {}
	for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
		by_index[spawn.name.to_int()] = spawn
	if by_index.is_empty():
		return Vector2.ZERO
	var team := GameManager.get_team(get_multiplayer_authority())
	var choices := TeamRules.respawn_indices(team, by_index.size(), GameManager.is_team_mode())
	var spawn: Node2D = by_index.get(choices.pick_random(), by_index.values()[0])
	return spawn.global_position

func _start_regen_delay() -> void:
	if regen_percent_per_tick <= 0.0 or current_health >= max_health:
		return
	heal_timer.start(regen_delay_after_damage)

func _on_heal_timer_timeout() -> void:
	if not _is_host() or is_dead:
		return
	heal(DamageRules.regen_amount(max_health, regen_percent_per_tick, current_health))
	if current_health < max_health:
		heal_timer.start(regen_tick_interval)

# --- Host -> everyone ---------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _sync_health(hp: float, max_hp: float, change: float) -> void:
	if not _from_host():
		return
	current_health = hp
	max_health = max_hp
	_broadcast_health_change()
	if change < 0.0:
		EventManager.emit_event(EventManager.Events.PLAYER_DAMAGED, [get_parent(), -change, hp])
	elif change > 0.0:
		EventManager.emit_event(EventManager.Events.PLAYER_HEALED, [get_parent(), change, hp])

@rpc("any_peer", "call_local", "reliable")
func _on_died() -> void:
	if not _from_host():
		return
	is_dead = true
	var player := get_parent()
	player.visible = false
	if player.is_multiplayer_authority():
		if powerup_manager:
			powerup_manager.clear_on_death()
		var weapon_holder = player.get_node_or_null("PlayerController/WeaponHolder")
		if weapon_holder:
			weapon_holder.reset_on_death()
	EventManager.emit_event(EventManager.Events.PLAYER_DIED, [player])

@rpc("any_peer", "call_local", "reliable")
func _on_respawned(spawn_position: Vector2, hp: float, max_hp: float) -> void:
	if not _from_host():
		return
	is_dead = false
	current_health = hp
	max_health = max_hp
	var player := get_parent()
	player.global_position = spawn_position
	player.visible = true
	_broadcast_health_change()
	EventManager.emit_event(EventManager.Events.PLAYER_RESPAWNED, [player])

# --- Helpers ------------------------------------------------------------------

func _is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func _from_host() -> bool:
	return multiplayer.get_remote_sender_id() == 1

func _broadcast_health_change() -> void:
	if health_bar and is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = current_health
	EventManager.emit_event(EventManager.Events.UI_HEALTH_UPDATED, [get_parent(), int(current_health), int(max_health)])
