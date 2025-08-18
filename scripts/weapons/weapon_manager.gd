extends Node2D

@onready var switch_cooldown_timer: Timer = $WeaponSwitchTimer
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"
@onready var UI = $"../../CameraComponent/PlayerCamera/PlayerUI"
@onready var player = $"../.."
@onready var player_controller = $".."
@onready var slow_timer = $MovementSlowTimer
@onready var weapon_slots_ui = $"../../CameraComponent/PlayerCamera/PlayerUI/WeaponSlots"

const MAX_WEAPONS: int = 2

var weapons: Array = []
var current_weapon_index: int = 0
var can_switch: bool = true
var is_authority: bool = false
var weapon_paths: Array = []
var can_drop: bool = true

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
	if index >= 0 and index < weapons.size():
		var weapon = weapons[index]
		
		var weapon_scene = load(weapon.resource_path) as PackedScene
		var weapon_pickup_scene = preload("res://nodes/weapons/weapon_pickup.tscn")
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
	if not can_switch or weapons.size() == 0:
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
	if index < 0 or index > weapons.size():
		return
		
	var previous_weapon = current_weapon()
	var previous_index = current_weapon_index
	
	if current_weapon_index < weapons.size():
		current_weapon().hide()
		
	current_weapon_index = index
	
	if index < weapons.size():
		current_weapon().show()
		
	update_hud()
	update_weapon_slots()
	
	# Don't emit event if equipping same weapon or during initialization
	if previous_weapon != current_weapon() and previous_weapon != null:
		EventManager.emit_event(EventManager.Events.WEAPON_SWITCHED, [player, current_weapon_index, current_weapon()])

func current_weapon() -> RangedWeapon:
	if current_weapon_index < weapons.size():
		return weapons[current_weapon_index]
	return null

func update_hud() -> void:
	if weapons.size() > 0 and current_weapon() != null:
		EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [current_weapon().ammo, current_weapon().max_ammo])

func update_weapon_slots() -> void:
	var slot_info = []
	for i in range(MAX_WEAPONS):
		if i < weapons.size():
			weapon_slots_ui.update_slot(i, weapons[i].name)
			slot_info.append(weapons[i].name)
		else:
			weapon_slots_ui.update_slot(i, "")
			slot_info.append("")
	
	EventManager.emit_event(EventManager.Events.UI_WEAPON_SLOTS_UPDATED, [slot_info])

func delete_current_weapon() -> void:
	if not can_drop or weapons.size() == 0 or current_weapon() == null:
		return
		
	can_drop = false
	drop_weapon(current_weapon_index)
	await get_tree().create_timer(1.0).timeout
	can_drop = true

func _process(_delta: float) -> void:
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
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
				weapon.shoot()
				update_hud()

				if weapon.slowness_duration > 0 and weapon.ammo > 0:
					player_controller.apply_weapon_slowness(weapon.slowness)
					slow_timer.start(weapon.slowness_duration / 1000.0)
			if InputManager.is_reload_pressed():
				weapon.reload()
				update_hud()

func _on_switch_cooldown_timer_timeout() -> void:
	can_switch = true

func _on_slow_timer_timeout():
	var weapon = current_weapon()
	if weapon != null:
		player_controller.remove_weapon_slowness(weapon.slowness)

func on_weapon_picked_up(weapon_scene: PackedScene) -> void:
	var weapon_path = weapon_scene.resource_path
	
	if weapons.size() >= MAX_WEAPONS:
		add_weapon(weapon_scene.instantiate(), true)
		return
		
	add_weapon(weapon_scene.instantiate(), true)
	await get_tree().process_frame

@rpc("any_peer", "reliable")
func request_inventory_sync():
	if is_authority:
		rpc_id(multiplayer.get_remote_sender_id(), "sync_inventory_state", weapon_paths, current_weapon_index)

@rpc("any_peer", "reliable")
func sync_inventory_state(paths: Array, new_index: int):
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

@rpc("any_peer", "reliable")
func spawn_weapon_pickup(weapon_path: String, pos: Vector2) -> void:
	var weapon_scene = load(weapon_path) as PackedScene
	var weapon_pickup_scene = preload("res://nodes/weapons/weapon_pickup.tscn")
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
