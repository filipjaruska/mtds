extends Node2D

var current_weapon: RangedWeapon
var can_switch: bool = true

@onready var switch_cooldown_timer = $"../WeaponManager/SwitchCooldownTimer"
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"
@onready var UI = $"../../Camera2D/UI"

func _ready():
	var pistol_scene: PackedScene = preload("res://nodes/weapons/pistol.tscn")
	var shotgun_scene: PackedScene = preload("res://nodes/weapons/shotgun.tscn")

	var pistol = pistol_scene.instantiate()
	pistol.name = "Pistol"
	add_child(pistol)
	current_weapon = pistol

	var shotgun = shotgun_scene.instantiate()
	shotgun.name = "Shotgun"
	add_child(shotgun)
	shotgun.hide()
	
	update_hud()

func switch_weapon():
	if not can_switch:
		return

	can_switch = false
	switch_cooldown_timer.start()

	if current_weapon.name == "Pistol":
		rpc("network_switch_weapon", "Shotgun")
	elif current_weapon.name == "Shotgun":
		rpc("network_switch_weapon", "Pistol")

@rpc("any_peer", "call_local")
func network_switch_weapon(weapon_name: String):
	if current_weapon.name == weapon_name:
		return
	
	current_weapon.hide()
	current_weapon = get_node(weapon_name)
	current_weapon.show()
	print("Switched to: ", current_weapon.name)

func update_hud():
	UI.update_ammo(current_weapon.AMMO, current_weapon.MAX_AMMO)

func _process(_delta):
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		if Input.is_action_just_pressed("shoot"):
			current_weapon.shoot()
			update_hud()

		if Input.is_action_just_pressed("reload"):
			current_weapon.reload()
			update_hud()

		if Input.is_action_just_pressed("switch_weapon"):
			switch_weapon()
			update_hud()

func _on_switch_cooldown_timer_timeout():
	can_switch = true
