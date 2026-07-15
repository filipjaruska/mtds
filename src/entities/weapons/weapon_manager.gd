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

const DUAL_WIELD_VERTICAL_SPACING := 14.0

func _ready() -> void:
	if weapons.size() > 0:
		equip_weapon(0)
	update_weapon_slots()
	is_authority = (multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id())
	if not is_authority:
		rpc_id(multiplayer_sync.get_multiplayer_authority(), "request_inventory_sync")
# TODO: Consider when moving forward
	# EventManager.register(EventManager.Events.WEAPON_FIRED, self, "_on_weapon_fired")
	# EventManager.register(EventManager.Events.WEAPON_RELOADED, self, "_on_weapon_reloaded")

#func _exit_tree() -> void:
	# EventManager.unregister(EventManager.Events.WEAPON_FIRED, self, "_on_weapon_fired")
	# EventManager.unregister(EventManager.Events.WEAPON_RELOADED, self, "_on_weapon_reloaded")

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
	rpc("sync_inventory_state", weapon_paths, current_weapon_index)
	
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
		
		rpc("remove_weapon", index)
		rpc("spawn_weapon_pickup", weapon.resource_path, player.position)
		
		weapons.remove_at(index)
		weapon.queue_free()
		
	update_weapon_slots()
	if is_authority and index >= 0 and index < weapon_paths.size():
		weapon_paths.remove_at(index)
		rpc("sync_inventory_state", weapon_paths, current_weapon_index)

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
	rpc("sync_inventory_state", weapon_paths, current_weapon_index)
	
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
		current_weapon().show()
		
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
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		if not dual_wield_active:
			if InputManager.is_weapon_switch_pressed():
				switch_weapon()
			if InputManager.is_weapon_1_pressed():
				equip_weapon(0)
				rpc("sync_inventory_state", weapon_paths, 0)
			if InputManager.is_weapon_2_pressed():
				equip_weapon(1)
				rpc("sync_inventory_state", weapon_paths, 1)
			if InputManager.is_drop_weapon_pressed():
				delete_current_weapon()

		if weapons.size() > 0 and current_weapon() != null:
			var weapon = current_weapon()
			if InputManager.is_shoot_pressed():
				var fired := false
				if powerup_manager:
					fired = powerup_manager.trigger_burst_if_ready(weapon)
				if not fired:
					if dual_wield_active:
						weapon.shoot_with_spread_penalty(dual_wield_spread_penalty)
						if off_hand_weapon:
							off_hand_weapon.shoot_with_spread_penalty(dual_wield_spread_penalty)
					else:
						weapon.shoot()
				
				update_hud()

				if weapon.slowness_duration > 0 and weapon.ammo > 0:
					player_controller.apply_weapon_slowness(weapon.slowness)
					slow_timer.start(weapon.slowness_duration / 1000.0)
			elif not dual_wield_active and InputManager.is_reload_pressed():
				if reload_speed_multiplier > 1.0:
					weapon.reload_time /= reload_speed_multiplier
				
				weapon.reload()
				update_hud()
		
		if dual_wield_active and are_dual_wield_magazines_empty() and powerup_manager:
			powerup_manager.expire_active_powerup_of_type(BasePowerupCard.PowerupType.DUAL_WIELD)

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

@rpc("any_peer", "call_local", "reliable")
func _sync_reset_weapons_on_death(death_position: Vector2, drop_weapon_path: String) -> void:
	if not drop_weapon_path.is_empty():
		spawn_weapon_pickup(drop_weapon_path, death_position)
	_load_default_weapon_loadout()

@rpc("any_peer", "reliable")
func request_inventory_sync():
	if is_authority:
		rpc_id(multiplayer.get_remote_sender_id(), "sync_inventory_state", weapon_paths, current_weapon_index)

@rpc("any_peer", "reliable")
func sync_inventory_state(paths: Array, new_index: int):
	var spread := dual_wield_spread_penalty
	var was_dual := dual_wield_active
	var ammo_snap := get_dual_wield_ammo_snapshot() if was_dual else {}
	disable_dual_wield()
	
	weapon_paths = paths
	current_weapon_index = new_index
	for w in weapons:
		w.queue_free()
	weapons.clear()
	for path in weapon_paths:
		var scene := load(path) as PackedScene
		if scene:
			var new_weapon := scene.instantiate()
			new_weapon.hide()
			weapons.append(new_weapon)
			add_child(new_weapon)
	equip_weapon(current_weapon_index)
	
	if was_dual:
		enable_dual_wield(spread, ammo_snap)

@rpc("any_peer", "reliable")
func spawn_weapon_pickup(weapon_path: String, pos: Vector2) -> void:
	var weapon_scene = load(weapon_path) as PackedScene
	var weapon_pickup_scene = preload("res://src/entities/weapons/weapon_pickup.tscn")
	var weapon_pickup = weapon_pickup_scene.instantiate()
	weapon_pickup.position = pos
	weapon_pickup.set_weapon_scene(weapon_scene)
	get_tree().root.add_child(weapon_pickup)

@rpc("any_peer", "reliable")
func remove_weapon(index: int) -> void:
	if index >= 0 and index < weapons.size():
		var weapon = weapons[index]
		weapons.remove_at(index)
		weapon.queue_free()

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
		return true
	
	var primary := current_weapon()
	if primary == null or primary.resource_path.is_empty():
		return false
	if primary.ammo <= 0 and not saved_ammo.has("primary"):
		return false
	
	var scene := load(primary.resource_path) as PackedScene
	if scene == null:
		return false
	
	off_hand_weapon = scene.instantiate() as RangedWeapon
	add_child(off_hand_weapon)
	
	var half_spacing := DUAL_WIELD_VERTICAL_SPACING * 0.5
	primary.position = Vector2(0.0, half_spacing)
	off_hand_weapon.position = Vector2(0.0, -half_spacing)
	primary.rotation = 0.0
	primary.scale = Vector2.ONE
	off_hand_weapon.rotation = 0.0
	off_hand_weapon.scale = Vector2.ONE
	off_hand_weapon.z_index = 1
	
	if saved_ammo.has("primary"):
		primary.ammo = saved_ammo["primary"]
	if saved_ammo.has("offhand"):
		off_hand_weapon.ammo = saved_ammo["offhand"]
	else:
		off_hand_weapon.ammo = primary.ammo
	
	off_hand_weapon.show()
	primary.show()
	dual_wield_active = true
	dual_wield_spread_penalty = spread_penalty
	update_hud()
	return true

func disable_dual_wield() -> void:
	if off_hand_weapon:
		off_hand_weapon.queue_free()
		off_hand_weapon = null
	var primary := current_weapon()
	if primary:
		primary.position = Vector2.ZERO
		primary.z_index = 0
	dual_wield_active = false
	dual_wield_spread_penalty = 0.0
	update_hud()

func update_dual_wield_spread(spread_penalty: float) -> void:
	dual_wield_spread_penalty = spread_penalty

func are_dual_wield_magazines_empty() -> bool:
	var primary := current_weapon()
	if primary == null or off_hand_weapon == null:
		return false
	return primary.ammo <= 0 and off_hand_weapon.ammo <= 0

func get_dual_wield_ammo_snapshot() -> Dictionary:
	var primary := current_weapon()
	return {
		"primary": primary.ammo if primary else 0,
		"offhand": off_hand_weapon.ammo if off_hand_weapon else 0,
	}

func get_dual_wield_ammo_display() -> String:
	var primary := current_weapon()
	if primary == null or off_hand_weapon == null:
		return ""
	return "%d / %d | %d / %d" % [
		primary.ammo,
		primary.max_ammo,
		off_hand_weapon.ammo,
		off_hand_weapon.max_ammo
	]
