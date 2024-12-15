extends Node2D

@onready var switch_cooldown_timer: Timer = $"../WeaponManager/SwitchCooldownTimer"
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"
@onready var UI = $"../../Camera2D/UI"
@onready var player = $"../.."
@onready var slow_timer = $SlowTimer

const MAX_WEAPONS: int = 2

var weapons: Array = []
var current_weapon_index: int = 0
var can_switch: bool = true

func _ready():
	if weapons.size() > 0:
		equip_weapon(0)

func add_weapon(weapon: RangedWeapon, equip_immediately: bool = false):
	if weapons.size() >= MAX_WEAPONS:
		drop_weapon(current_weapon_index)

	weapon.hide()
	weapons.append(weapon)
	add_child(weapon)

	if weapons.size() == 1 or equip_immediately:
		equip_weapon(weapons.size() - 1)

func drop_weapon(index: int):
	if index >= 0 and index < weapons.size():
		weapons[index].queue_free()
		weapons.remove_at(index)
		if weapons.size() > 0:
			equip_weapon(0)

func switch_weapon():
	if not can_switch or weapons.size() < 2:
		return

	can_switch = false
	switch_cooldown_timer.start()

	current_weapon().hide()
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	current_weapon().show()
	update_hud()

func equip_weapon(index: int):
	if index < 0 or index >= weapons.size():
		return

	if current_weapon_index < weapons.size():
		current_weapon().hide()
	current_weapon_index = index
	current_weapon().show()
	update_hud()

func current_weapon() -> RangedWeapon:
	return weapons[current_weapon_index]

func update_hud():
	if weapons.size() > 0:
		UI.update_ammo(current_weapon().ammo, current_weapon().max_ammo)

func _process(_delta):
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		if weapons.size() > 0:
			var weapon = current_weapon()
			if Input.is_action_pressed("shoot"):
				weapon.shoot()
				update_hud()

				if weapon.slowness_duration > 0 and weapon.ammo > 0:
					player.current_speed = lerp(200.0, weapon.slowness, 0.8)
					slow_timer.start(weapon.slowness_duration / 1000.0)
			if Input.is_action_just_pressed("reload"):
				weapon.reload()
				update_hud()

			if Input.is_action_just_pressed("switch_weapon"):
				switch_weapon()

func _on_switch_cooldown_timer_timeout():
	can_switch = true

func _on_slow_timer_timeout():
	player.current_speed = lerp(current_weapon().slowness, 200.0, 0.8)

func on_weapon_picked_up(weapon_scene: PackedScene):
	add_weapon(weapon_scene.instantiate(), true)
