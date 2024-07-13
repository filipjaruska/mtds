extends Node2D

@onready var switch_cooldown_timer = $"../WeaponManager/SwitchCooldownTimer"
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"
@onready var UI = $"../../Camera2D/UI"
@onready var player = $"../.."
@onready var slow_timer = $SlowTimer

const MAX_WEAPONS: int = 2

var weapons: Array = []
var current_weapon_index: int = 0
var can_switch: bool = true

func _ready():
	var pistol_scene: PackedScene = preload("res://nodes/weapons/pistol.tscn")
	var shotgun_scene: PackedScene = preload("res://nodes/weapons/shotgun.tscn")

	add_weapon(pistol_scene.instantiate())
	add_weapon(shotgun_scene.instantiate())

	if weapons.size() > 0:
		current_weapon_index = 0
		weapons[current_weapon_index].show()
		update_hud()

func add_weapon(weapon: RangedWeapon):
	if weapons.size() >= MAX_WEAPONS:
		drop_weapon(current_weapon_index)

	weapon.hide()
	weapons.append(weapon)
	add_child(weapon)

func drop_weapon(index: int):
	if index >= 0 and index < weapons.size():
		weapons[index].queue_free()
		weapons.remove_at(index)
		if weapons.size() > 0:
			current_weapon_index = 0
			weapons[current_weapon_index].show()
			update_hud()

func switch_weapon():
	if not can_switch or weapons.size() < 2:
		return

	can_switch = false
	switch_cooldown_timer.start()

	weapons[current_weapon_index].hide()
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	weapons[current_weapon_index].show()
	update_hud()
	
	rpc("network_switch_weapon_index", current_weapon_index)

@rpc("any_peer", "call_local")
func network_switch_weapon_index(new_index: int):
	if new_index < 0 or new_index >= weapons.size():
		return

	weapons[current_weapon_index].hide()
	current_weapon_index = new_index
	weapons[current_weapon_index].show()
	update_hud()

@rpc("any_peer", "call_local")
func network_switch_weapon(weapon_name: String):
	for i in range(weapons.size()):
		if weapons[i].name == weapon_name:
			weapons[current_weapon_index].hide()
			current_weapon_index = i
			weapons[current_weapon_index].show()
			update_hud()
			return

	print("Weapon not found: ", weapon_name)

func update_hud():
	if weapons.size() > 0:
		UI.update_ammo(weapons[current_weapon_index].AMMO, weapons[current_weapon_index].MAX_AMMO)

func _process(_delta):
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		if weapons.size() > 0:
			var current_weapon = weapons[current_weapon_index]
			if Input.is_action_pressed("shoot"):
				current_weapon.shoot()
				update_hud()
			
				if current_weapon.slowness_duration > 0 && weapons[current_weapon_index].AMMO > 0:
					player.current_speed = lerp(200.0, current_weapon.slowness, 0.8)
					slow_timer.start(current_weapon.slowness_duration / 1000.0)

			if Input.is_action_just_pressed("reload"):
				current_weapon.reload()
				update_hud()

			if Input.is_action_just_pressed("switch_weapon"):
				switch_weapon()

func _on_switch_cooldown_timer_timeout():
	can_switch = true

func _on_slow_timer_timeout():
	var current_weapon = weapons[current_weapon_index]
	player.current_speed = lerp(current_weapon.slowness, 200.0, 0.8)
