extends Node
class_name CardEffects
## The behaviour of card abilities that are more than stat modifiers.
## Runs on every peer and, like WeaponHolder, derives its state from the
## player's active powerups (PowerupManager.active_changed), so nothing has to be
## undone when a card ends.
##
##   riot_shield      every peer shows the shield; the host owns its HP
##   shoulder_charge  the dashing owner reports a body hit; the host validates,
##                    damages and knocks the target back
##   last_stand       host side, see HealthComponent.apply_damage
##   kill_reload      host side: notify_kill() refills the killer's magazines
## Burst Fire, Dual Wield and Piercing Rounds live in WeaponHolder / CombatServer.

## How close (px) a charge target may be when the host checks the hit.
const CHARGE_RANGE := 110.0
## Each target can be charged once per dash.
const CHARGE_REPEAT_MSEC := 400

@onready var player: Node2D = get_parent()
@onready var powerup_manager: PowerupManager = player.get_node_or_null("PowerupManager")
@onready var controller: Node2D = player.get_node_or_null("PlayerController")

var _shield: RiotShield = null
var _shield_key := -1 # expires_at of the activation that made the shield
var _charge_hits := {} # host: target id -> msec of the last charge hit

func _ready() -> void:
	if powerup_manager:
		powerup_manager.active_changed.connect(_on_powerups_changed)

func _on_powerups_changed(active: Array) -> void:
	_update_shield(active)

# --- Riot Shield ---------------------------------------------------------------

func get_shield() -> RiotShield:
	return _shield if is_instance_valid(_shield) else null

## A fresh shield per activation; a shattered one stays gone until the card is
## played again.
func _update_shield(active: Array) -> void:
	var entry := PowerupRules.entry_with_ability(active, &"riot_shield")
	if entry.is_empty():
		_remove_shield()
		_shield_key = -1
		return
	if entry.expires_at == _shield_key:
		return
	_remove_shield()
	_shield_key = entry.expires_at
	var def := PowerupDefs.get_def(entry.def)
	var params := PowerupRules.shield_params(def, entry.stacks)
	_shield = RiotShield.create(params.width, params.distance, params.hp, def.rarity_color)
	controller.add_child(_shield)

func _remove_shield() -> void:
	if is_instance_valid(_shield):
		# Free the name now so a new shield can take it in the same frame.
		_shield.name = "RiotShieldOld"
		_shield.queue_free()
	_shield = null

# --- Shoulder Charge -------------------------------------------------------------

## Owner: is a charge active? (checked while dashing)
func can_charge() -> bool:
	return powerup_manager != null and not PowerupRules.entry_with_ability(powerup_manager.active, &"shoulder_charge").is_empty()

## Owner -> host: "my dash ran into this player".
@rpc("any_peer", "call_local", "reliable")
func request_charge_hit(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var attacker_id := multiplayer.get_remote_sender_id()
	if attacker_id != player.get_multiplayer_authority():
		return
	var entry := PowerupRules.entry_with_ability(powerup_manager.active, &"shoulder_charge")
	var target := player.get_parent().get_node_or_null(str(target_id)) as Node2D
	if entry.is_empty() or target == null or target == player or GameManager.are_teammates(attacker_id, target_id):
		return
	var target_health: HealthComponent = target.get_health_component()
	var my_health: HealthComponent = player.get_health_component()
	if target_health == null or target_health.is_dead or my_health.is_dead:
		return
	if target.global_position.distance_to(player.global_position) > CHARGE_RANGE:
		return
	var now := Time.get_ticks_msec()
	if now - int(_charge_hits.get(target_id, -CHARGE_REPEAT_MSEC)) < CHARGE_REPEAT_MSEC:
		return
	_charge_hits[target_id] = now
	var params := PowerupRules.charge_params(PowerupDefs.get_def(entry.def), entry.stacks)
	var direction := (target.global_position - player.global_position).normalized()
	target_health.apply_damage(params.damage, 0.0, attacker_id)
	target.get_player_controller().apply_knockback.rpc_id(target_id, direction * params.knockback)

# --- Kill Reload -----------------------------------------------------------------

## Host: this player just killed someone.
func notify_kill() -> void:
	if not multiplayer.is_server() or powerup_manager == null:
		return
	if PowerupRules.entry_with_ability(powerup_manager.active, &"kill_reload").is_empty():
		return
	var holder: WeaponHolder = player.get_weapon_holder()
	if holder:
		holder.refill_magazines.rpc_id(player.get_multiplayer_authority())

# --- Last Stand ------------------------------------------------------------------

## Host -> everyone: the player survived a lethal hit.
@rpc("any_peer", "call_local", "reliable")
func play_last_stand() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var sprite := player.get_node_or_null("PlayerSprite") as CanvasItem
	if sprite == null:
		return
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(sprite, "self_modulate", Color(2.0, 1.7, 0.6), 0.08)
		tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.12)
