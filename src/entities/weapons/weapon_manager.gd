extends Node2D

@onready var switch_cooldown_timer: Timer = $WeaponSwitchTimer
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"
@onready var UI = $"../../CameraComponent/PlayerCamera/PlayerUI"
@onready var player = $"../.."
@onready var player_controller = $".."
@onready var slow_timer = $MovementSlowTimer
@onready var weapon_slots_ui = $"../../CameraComponent/PlayerCamera/PlayerUI/WeaponSlots"
@onready var powerup_manager = $"../../PowerupManager"

const MAX_WEAPONS: int = 2
const BULLET_SCENE := preload("res://src/entities/weapons/bullet.tscn")
const DEFAULT_WEAPON_SCENE := preload("res://src/entities/weapons/pistol.tscn")

var weapons: Array = []
var current_weapon_index: int = 0
var can_switch: bool = true
var is_authority: bool = false
var weapon_paths: Array = []
var can_drop: bool = true

var damage_multiplier: float = 1.0
var reload_speed_multiplier: float = 1.0

var off_hand_weapon: RangedWeapon = null
var dual_wield_active: bool = false
var dual_wield_spread_penalty: float = 0.0
var _dual_fire_primary_next: bool = true
var _dual_next_shot_msec: int = 0
var _end_dual_after_burst: bool = false

const DUAL_WIELD_VERTICAL_SPACING := 18.0

func _ready() -> void:
	if weapons.size() > 0:
		equip_weapon(0)
	update_weapon_slots()
	# Authority is assigned deferred on the player; refresh once after the tree settles.
	call_deferred("refresh_authority_state")

func refresh_authority_state() -> void:
	var was_authority := is_authority
	is_authority = _is_local_authority()
	if is_authority and not was_authority:
		if not EventManager._signal_dict.is_empty():
			EventManager.register(EventManager.Events.WEAPON_RELOADED, _on_weapon_reloaded)
		_sync_weapons_to_peers()
	elif not is_authority and was_authority:
		EventManager.unregister(EventManager.Events.WEAPON_RELOADED, _on_weapon_reloaded)
	elif not is_authority:
		var authority_id := multiplayer_sync.get_multiplayer_authority()
		if authority_id > 0 and authority_id != multiplayer.get_unique_id():
			rpc_id(authority_id, "request_inventory_sync")

func _is_local_authority() -> bool:
	return multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id()

func _exit_tree() -> void:
	if _is_local_authority():
		EventManager.unregister(EventManager.Events.WEAPON_RELOADED, _on_weapon_reloaded)

func add_weapon(weapon: RangedWeapon, equip_immediately: bool = false) -> void:
	if dual_wield_active:
		return
	if weapons.size() >= MAX_WEAPONS:
		drop_weapon(current_weapon_index)
		
	weapon.hide()
	weapons.append(weapon)
	add_child(weapon)
	
	if weapons.size() == 1 or equip_immediately:
		equip_weapon(weapons.size() - 1)
	update_weapon_slots()
	
	weapon_paths.append(weapon.resource_path)
	_sync_weapons_to_peers()
	
	EventManager.emit_event(EventManager.Events.WEAPON_PICKED_UP, [player, weapon])
	

func drop_weapon(index: int) -> void:
	if dual_wield_active:
		return
	if index >= 0 and index < weapons.size():
		var weapon = weapons[index]
		
		var weapon_scene = load(weapon.resource_path) as PackedScene
		var weapon_pickup_scene = preload("res://src/entities/weapons/weapon_pickup.tscn")
		var weapon_pickup = weapon_pickup_scene.instantiate()
		weapon_pickup.position = player.position
		weapon_pickup.set_weapon_scene(weapon_scene)
		get_tree().root.add_child(weapon_pickup)
		
		EventManager.emit_event(EventManager.Events.WEAPON_DROPPED, [player, weapon])
		
		rpc("spawn_weapon_pickup", weapon.resource_path, player.position)
		
		weapons.remove_at(index)
		if index >= 0 and index < weapon_paths.size():
			weapon_paths.remove_at(index)
		weapon.queue_free()
		
		if current_weapon_index >= weapons.size():
			current_weapon_index = maxi(weapons.size() - 1, 0)
		elif current_weapon_index > index:
			current_weapon_index -= 1
		
		if weapons.size() > 0:
			equip_weapon(current_weapon_index)
		
	update_weapon_slots()
	if _is_local_authority():
		_sync_weapons_to_peers()

func switch_weapon() -> void:
	if dual_wield_active or not can_switch or weapons.size() == 0:
		return
		
	can_switch = false
	switch_cooldown_timer.start()
	
	var current = current_weapon()
	if current != null:
		current.hide()
		
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	var next_weapon = current_weapon()
	if next_weapon != null:
		next_weapon.show()
		
	update_hud()
	update_weapon_slots()
	_sync_weapons_to_peers()
	
	EventManager.emit_event(EventManager.Events.WEAPON_SWITCHED, [player, current_weapon_index, next_weapon])

func equip_weapon(index: int) -> void:
	if dual_wield_active:
		return
	if index < 0 or index > weapons.size():
		return
		
	var previous_weapon = current_weapon()
	var _previous_index = current_weapon_index
	
	if current_weapon_index < weapons.size():
		current_weapon().hide()
		
	current_weapon_index = index
	
	if index < weapons.size():
		var equipped := current_weapon()
		equipped.position = Vector2.ZERO
		equipped.rotation = 0.0
		equipped.scale = Vector2.ONE
		equipped.z_index = 0
		equipped.show()
		
	update_hud()
	update_weapon_slots()
	
	if previous_weapon != current_weapon() and previous_weapon != null:
		EventManager.emit_event(EventManager.Events.WEAPON_SWITCHED, [player, current_weapon_index, current_weapon()])

func current_weapon() -> RangedWeapon:
	if current_weapon_index < weapons.size():
		return weapons[current_weapon_index]
	return null

func update_hud() -> void:
	if weapons.size() > 0 and current_weapon() != null:
		if dual_wield_active and off_hand_weapon != null:
			EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [
				get_parent(),
				current_weapon().ammo,
				current_weapon().max_ammo,
				off_hand_weapon.ammo,
				off_hand_weapon.max_ammo
			])
		else:
			EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [
				get_parent(),
				current_weapon().ammo,
				current_weapon().max_ammo,
				-1,
				-1
			])

func update_weapon_slots() -> void:
	var slot_info = []
	for i in range(MAX_WEAPONS):
		if i < weapons.size():
			var display_name = weapons[i].get_display_name()
			weapon_slots_ui.update_slot(i, display_name)
			slot_info.append(display_name)
		else:
			weapon_slots_ui.update_slot(i, "")
			slot_info.append("")
	
	EventManager.emit_event(EventManager.Events.UI_WEAPON_SLOTS_UPDATED, [slot_info])

func delete_current_weapon() -> void:
	if dual_wield_active or not can_drop or weapons.size() == 0 or current_weapon() == null:
		return
		
	can_drop = false
	drop_weapon(current_weapon_index)
	await get_tree().create_timer(1.0).timeout
	can_drop = true

func _process(_delta: float) -> void:
	# Dual wield must never remain active without its powerup — that permanently
	# blocks switching/dropping and leaves weapons offset.
	if dual_wield_active and (powerup_manager == null or not powerup_manager.has_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD)):
		disable_dual_wield(true)
	
	if not _is_local_authority():
		return
	
	is_authority = true
	if not dual_wield_active:
		if InputManager.is_weapon_switch_pressed():
			switch_weapon()
		if InputManager.is_weapon_1_pressed():
			equip_weapon(0)
			_sync_weapons_to_peers()
		if InputManager.is_weapon_2_pressed():
			equip_weapon(1)
			_sync_weapons_to_peers()
		if InputManager.is_drop_weapon_pressed():
			delete_current_weapon()

	if weapons.size() > 0 and current_weapon() != null:
		var weapon = current_weapon()
		var burst_locked := _is_any_weapon_bursting()
		if InputManager.is_shoot_pressed() and not burst_locked:
			var fired := false
			if powerup_manager:
				var offhand: RangedWeapon = off_hand_weapon if dual_wield_active else null
				fired = powerup_manager.trigger_burst_if_ready(weapon, offhand)
				if fired and dual_wield_active:
					_queue_end_dual_after_burst()
			if not fired:
				if dual_wield_active:
					_try_dual_wield_shot()
				else:
					weapon.shoot()
			
			update_hud()
			_sync_weapons_to_peers()

			if weapon.slowness_duration > 0 and weapon.ammo > 0:
				player_controller.apply_weapon_slowness(weapon.slowness)
				slow_timer.start(weapon.slowness_duration / 1000.0)
		elif not dual_wield_active and not burst_locked and InputManager.is_reload_pressed():
			if reload_speed_multiplier > 1.0:
				weapon.reload_time /= reload_speed_multiplier
			
			weapon.reload()
			update_hud()
	
	if _end_dual_after_burst and not _is_any_weapon_bursting():
		_end_dual_after_burst = false
		_end_dual_wield_from_empty_mags()
	elif dual_wield_active and are_dual_wield_magazines_empty() and not _is_any_weapon_bursting():
		_end_dual_wield_from_empty_mags()

func _on_switch_cooldown_timer_timeout() -> void:
	can_switch = true

func _on_slow_timer_timeout():
	var weapon = current_weapon()
	if weapon != null:
		player_controller.remove_weapon_slowness(weapon.slowness)

func on_weapon_picked_up(weapon_scene: PackedScene) -> bool:
	if dual_wield_active:
		return false
	add_weapon(weapon_scene.instantiate(), true)
	return true

func _on_weapon_reloaded(weapon_node: Node, is_reloading_start: bool, _remaining_reload_time: float) -> void:
	if not _is_local_authority() or is_reloading_start:
		return
	if weapon_node.get_parent() != self and weapon_node != off_hand_weapon:
		return
	_sync_weapons_to_peers()

func _build_weapon_sync_payload() -> Dictionary:
	var ammo_counts: Array[int] = []
	for w in weapons:
		ammo_counts.append(w.ammo if w else 0)
	
	var primary := current_weapon()
	var offhand_ammo := 0
	if off_hand_weapon and is_instance_valid(off_hand_weapon):
		offhand_ammo = off_hand_weapon.ammo
	return {
		"paths": weapon_paths.duplicate(),
		"index": current_weapon_index,
		"ammo": ammo_counts,
		"dual_wield": {
			"active": dual_wield_active,
			"spread": dual_wield_spread_penalty,
			"primary_ammo": primary.ammo if primary else 0,
			"offhand_ammo": offhand_ammo,
		},
	}

func _sync_weapons_to_peers() -> void:
	if not _is_local_authority():
		return
	rpc("apply_weapon_sync", _build_weapon_sync_payload())

func _paths_match(paths: Array) -> bool:
	if paths.size() != weapon_paths.size():
		return false
	for i in range(paths.size()):
		if paths[i] != weapon_paths[i]:
			return false
	return true

func _apply_ammo_and_dual_state(payload: Dictionary) -> void:
	var ammo_counts: Array = payload.get("ammo", [])
	for i in range(mini(ammo_counts.size(), weapons.size())):
		weapons[i].ammo = ammo_counts[i]
	
	current_weapon_index = payload.get("index", current_weapon_index)
	if current_weapon_index >= weapons.size():
		current_weapon_index = maxi(weapons.size() - 1, 0)
	
	var dual: Dictionary = payload.get("dual_wield", {})
	var dual_active: bool = dual.get("active", false)
	var spread: float = dual.get("spread", 0.0)
	var ammo_snap := {
		"primary": dual.get("primary_ammo", 0),
		"offhand": dual.get("offhand_ammo", 0),
	}
	var has_dual_powerup: bool = powerup_manager != null and powerup_manager.has_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD)
	
	# Powerup apply/remove owns enabling dual wield. Sync only updates ammo / cleans
	# stale dual state so late packets cannot permanently lock switching.
	if dual_wield_active and not has_dual_powerup:
		disable_dual_wield(true)
	elif dual_wield_active and dual_active:
		dual_wield_spread_penalty = spread
		_apply_dual_wield_offsets()
		var primary := current_weapon()
		if primary:
			primary.ammo = ammo_snap["primary"]
		if off_hand_weapon:
			off_hand_weapon.ammo = ammo_snap["offhand"]
	elif dual_wield_active and not dual_active:
		# Owning peer already ended dual; keep local powerup-driven state if present.
		if not has_dual_powerup:
			disable_dual_wield(true)
	elif not dual_wield_active:
		_reset_weapon_positions()
		_free_orphaned_offhand_weapons()
	
	if weapons.size() > 0 and not dual_wield_active:
		equip_weapon(current_weapon_index)
	update_weapon_slots()
	update_hud()

func _rebuild_weapons_from_payload(payload: Dictionary) -> void:
	var paths: Array = payload.get("paths", [])
	var new_index: int = payload.get("index", 0)
	var ammo_counts: Array = payload.get("ammo", [])
	var dual: Dictionary = payload.get("dual_wield", {})
	
	disable_dual_wield(true)
	weapon_paths = paths.duplicate()
	current_weapon_index = new_index
	
	for w in weapons:
		w.queue_free()
	weapons.clear()
	
	for i in range(weapon_paths.size()):
		var scene := load(weapon_paths[i]) as PackedScene
		if scene:
			var new_weapon := scene.instantiate() as RangedWeapon
			new_weapon.hide()
			if i < ammo_counts.size():
				new_weapon.ammo = ammo_counts[i]
			weapons.append(new_weapon)
			add_child(new_weapon)
	
	if current_weapon_index >= weapons.size():
		current_weapon_index = maxi(weapons.size() - 1, 0)
	
	if weapons.size() > 0:
		equip_weapon(current_weapon_index)
	else:
		update_weapon_slots()
		update_hud()
	
	# Re-enable only when the dual powerup is still active locally.
	if dual.get("active", false) and powerup_manager and powerup_manager.has_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD):
		enable_dual_wield(dual.get("spread", 0.0), {
			"primary": dual.get("primary_ammo", 0),
			"offhand": dual.get("offhand_ammo", 0),
		})
	else:
		_reset_weapon_positions()
		_free_orphaned_offhand_weapons()
	
	update_weapon_slots()
	update_hud()

func reset_weapons_on_death() -> void:
	if multiplayer_sync.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
	var default_path := DEFAULT_WEAPON_SCENE.resource_path
	var non_default_paths: Array[String] = []
	for path in weapon_paths:
		if path != default_path:
			non_default_paths.append(path)
	
	var drop_path := ""
	if not non_default_paths.is_empty():
		drop_path = non_default_paths.pick_random()
	
	_sync_reset_weapons_on_death.rpc(player.global_position, drop_path)

func _load_default_weapon_loadout() -> void:
	disable_dual_wield(true)
	for w in weapons:
		w.queue_free()
	weapons.clear()
	
	var default_weapon: RangedWeapon = DEFAULT_WEAPON_SCENE.instantiate()
	default_weapon.hide()
	weapons.append(default_weapon)
	add_child(default_weapon)
	
	weapon_paths = [DEFAULT_WEAPON_SCENE.resource_path]
	current_weapon_index = 0
	equip_weapon(0)
	update_weapon_slots()
	update_hud()
	if _is_local_authority():
		_sync_weapons_to_peers()

@rpc("any_peer", "call_local", "reliable")
func _sync_reset_weapons_on_death(death_position: Vector2, drop_weapon_path: String) -> void:
	if not drop_weapon_path.is_empty():
		spawn_weapon_pickup(drop_weapon_path, death_position)
	_load_default_weapon_loadout()

@rpc("any_peer", "reliable")
func request_inventory_sync():
	if _is_local_authority():
		rpc_id(multiplayer.get_remote_sender_id(), "apply_weapon_sync", _build_weapon_sync_payload())

@rpc("any_peer", "reliable")
func apply_weapon_sync(payload: Dictionary) -> void:
	var paths: Array = payload.get("paths", [])
	if _paths_match(paths) and weapons.size() == paths.size():
		_apply_ammo_and_dual_state(payload)
	else:
		_rebuild_weapons_from_payload(payload)

@rpc("any_peer", "reliable")
func sync_inventory_state(paths: Array, new_index: int) -> void:
	apply_weapon_sync({
		"paths": paths,
		"index": new_index,
		"ammo": [],
		"dual_wield": {"active": false, "spread": 0.0, "primary_ammo": 0, "offhand_ammo": 0},
	})

@rpc("any_peer", "reliable")
func spawn_weapon_pickup(weapon_path: String, pos: Vector2) -> void:
	var weapon_scene = load(weapon_path) as PackedScene
	var weapon_pickup_scene = preload("res://src/entities/weapons/weapon_pickup.tscn")
	var weapon_pickup = weapon_pickup_scene.instantiate()
	weapon_pickup.position = pos
	weapon_pickup.set_weapon_scene(weapon_scene)
	get_tree().root.add_child(weapon_pickup)

@rpc("any_peer", "call_local", "reliable")
func spawn_bullet(pos: Vector2, rot: float, weapon_range: float, dmg: float, pen: float, shooter_id: int) -> void:
	if not BULLET_SCENE:
		return
	
	var bullet = BULLET_SCENE.instantiate()
	get_tree().root.add_child(bullet)
	
	bullet.global_position = pos
	bullet.global_rotation = rot
	bullet.target_position = Vector2(weapon_range, 0)
	bullet.set_visual_range(weapon_range)
	bullet.set_bullet_damage(dmg, pen)
	bullet.set_shooter_authority(shooter_id)
	
	await get_tree().process_frame
	bullet.force_raycast_update()
	bullet.force_raycast_update()

func is_dual_wield_active() -> bool:
	return dual_wield_active

func enable_dual_wield(spread_penalty: float, saved_ammo: Dictionary = {}) -> bool:
	if dual_wield_active:
		update_dual_wield_spread(spread_penalty)
		_apply_dual_wield_offsets()
		return true
	
	var primary := current_weapon()
	if primary == null or primary.resource_path.is_empty():
		return false
	
	var primary_ammo: int = int(saved_ammo.get("primary", primary.ammo))
	var offhand_ammo: int = int(saved_ammo.get("offhand", primary_ammo))
	# Never start/restart dual wield with empty magazines — that caused the mirrored
	# gun to respawn with default scene ammo and keep the player locked in dual.
	if primary_ammo <= 0 and primary.ammo <= 0:
		return false
	if primary.ammo <= 0 and primary_ammo > 0:
		primary.ammo = primary_ammo
	
	var scene := load(primary.resource_path) as PackedScene
	if scene == null:
		return false
	
	_free_orphaned_offhand_weapons()
	off_hand_weapon = scene.instantiate() as RangedWeapon
	off_hand_weapon.name = "OffHandWeapon"
	add_child(off_hand_weapon)
	
	_apply_dual_wield_offsets()
	primary.rotation = 0.0
	primary.scale = Vector2.ONE
	off_hand_weapon.rotation = 0.0
	off_hand_weapon.scale = Vector2.ONE
	off_hand_weapon.z_index = 1
	
	# Always overwrite scene-default ammo after instantiate.
	off_hand_weapon.ammo = offhand_ammo if offhand_ammo > 0 else primary.ammo
	if off_hand_weapon.ammo <= 0:
		off_hand_weapon.queue_free()
		off_hand_weapon = null
		_reset_weapon_positions()
		return false
	
	off_hand_weapon.show()
	primary.show()
	dual_wield_active = true
	dual_wield_spread_penalty = spread_penalty
	_dual_fire_primary_next = true
	_dual_next_shot_msec = 0
	update_hud()
	if _is_local_authority():
		_sync_weapons_to_peers()
	return true

func disable_dual_wield(silent: bool = false) -> void:
	if off_hand_weapon and is_instance_valid(off_hand_weapon):
		off_hand_weapon.queue_free()
	off_hand_weapon = null
	_free_orphaned_offhand_weapons()
	_reset_weapon_positions()
	dual_wield_active = false
	dual_wield_spread_penalty = 0.0
	_dual_fire_primary_next = true
	_dual_next_shot_msec = 0
	_end_dual_after_burst = false
	update_hud()
	if _is_local_authority() and not silent:
		_sync_weapons_to_peers()

func update_dual_wield_spread(spread_penalty: float) -> void:
	dual_wield_spread_penalty = spread_penalty
	if _is_local_authority():
		_sync_weapons_to_peers()

func _end_dual_wield_from_empty_mags() -> void:
	_end_dual_after_burst = false
	if powerup_manager and powerup_manager.has_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD):
		powerup_manager.expire_active_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD)
	# Ensure local state ends even if the powerup RPC is delayed or already gone.
	if dual_wield_active:
		disable_dual_wield()

func _queue_end_dual_after_burst() -> void:
	_end_dual_after_burst = true

func _is_any_weapon_bursting() -> bool:
	var primary := current_weapon()
	if primary and primary.is_burst_in_progress():
		return true
	if off_hand_weapon and is_instance_valid(off_hand_weapon) and off_hand_weapon.is_burst_in_progress():
		return true
	return false

func _try_dual_wield_shot() -> bool:
	var primary := current_weapon()
	if primary == null or off_hand_weapon == null or not is_instance_valid(off_hand_weapon):
		return false
	if _is_any_weapon_bursting():
		return false
	
	var now: int = Time.get_ticks_msec()
	if now < _dual_next_shot_msec:
		return false
	
	var preferred: RangedWeapon = primary if _dual_fire_primary_next else off_hand_weapon
	var fallback: RangedWeapon = off_hand_weapon if _dual_fire_primary_next else primary
	var gun: RangedWeapon = preferred
	if gun.ammo <= 0 or gun.is_reloading or gun.is_burst_in_progress():
		gun = fallback
	if gun.ammo <= 0 or gun.is_reloading or gun.is_burst_in_progress():
		return false
	
	# Shared dual cadence: only one gun may fire per interval.
	if not gun.force_shoot_with_spread_penalty(dual_wield_spread_penalty):
		return false
	
	_dual_next_shot_msec = now + int(1000.0 / maxf(gun.fire_rate, 0.01))
	_dual_fire_primary_next = gun != primary
	return true

func _sprite_local_offset(weapon: RangedWeapon) -> Vector2:
	if weapon == null or weapon.sprite == null:
		return Vector2.ZERO
	return weapon.sprite.position

func _apply_dual_wield_offsets() -> void:
	var primary := current_weapon()
	var half_spacing := DUAL_WIELD_VERTICAL_SPACING * 0.5
	# Shotgun art sits at Sprite2D (40, -10). Compensate that local offset so dual
	# guns stay visually centered, then restore root position to zero on disable.
	if primary:
		var sprite_offset := _sprite_local_offset(primary)
		primary.position = Vector2(0.0, half_spacing - sprite_offset.y)
		primary.z_index = 0
	if off_hand_weapon and is_instance_valid(off_hand_weapon):
		var sprite_offset := _sprite_local_offset(off_hand_weapon)
		off_hand_weapon.position = Vector2(0.0, -half_spacing - sprite_offset.y)
		off_hand_weapon.z_index = 1

func _reset_weapon_positions() -> void:
	for weapon in weapons:
		if weapon and is_instance_valid(weapon):
			weapon.position = Vector2.ZERO
			weapon.rotation = 0.0
			weapon.scale = Vector2.ONE
			weapon.z_index = 0

func _free_orphaned_offhand_weapons() -> void:
	for child in get_children():
		if child is RangedWeapon and not weapons.has(child):
			if off_hand_weapon == child:
				off_hand_weapon = null
			child.queue_free()

func notify_weapon_shot_fx(weapon: RangedWeapon) -> void:
	if not _is_local_authority() or weapon == null:
		return
	var is_offhand := weapon == off_hand_weapon
	var weapon_index := current_weapon_index
	if not is_offhand:
		weapon_index = weapons.find(weapon)
		if weapon_index < 0:
			weapon_index = current_weapon_index
	sync_weapon_shot_fx.rpc(weapon_index, is_offhand)

@rpc("any_peer", "reliable")
func sync_weapon_shot_fx(weapon_index: int, is_offhand: bool) -> void:
	# Authority already played visuals locally when firing.
	if _is_local_authority():
		return
	var weapon: RangedWeapon = null
	if is_offhand:
		weapon = off_hand_weapon
	elif weapon_index >= 0 and weapon_index < weapons.size():
		weapon = weapons[weapon_index]
	else:
		weapon = current_weapon()
	if weapon and is_instance_valid(weapon):
		weapon.play_shoot_visuals()

func are_dual_wield_magazines_empty() -> bool:
	var primary := current_weapon()
	if primary == null or off_hand_weapon == null or not is_instance_valid(off_hand_weapon):
		return false
	return primary.ammo <= 0 and off_hand_weapon.ammo <= 0

func get_dual_wield_ammo_snapshot() -> Dictionary:
	var primary := current_weapon()
	return {
		"primary": primary.ammo if primary else 0,
		"offhand": off_hand_weapon.ammo if off_hand_weapon and is_instance_valid(off_hand_weapon) else 0,
	}

func get_dual_wield_ammo_display() -> String:
	var primary := current_weapon()
	if primary == null or off_hand_weapon == null or not is_instance_valid(off_hand_weapon):
		return ""
	return "%d / %d | %d / %d" % [
		primary.ammo,
		primary.max_ammo,
		off_hand_weapon.ammo,
		off_hand_weapon.max_ammo
	]
