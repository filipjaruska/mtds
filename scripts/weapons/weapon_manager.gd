extends Node2D

var current_weapon: RangedWeapon
var can_switch: bool = true

@onready var switch_cooldown_timer = $"../WeaponManager/SwitchCooldownTimer"
@onready var multiplayer_sync = $"../../MultiplayerSynchronizer"

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

func switch_weapon():
	if not can_switch:
		return

	can_switch = false
	switch_cooldown_timer.start()

	print("Current Weapon: ", current_weapon.name)
	if current_weapon.name == "Pistol":
		current_weapon.hide()
		current_weapon = get_node("Shotgun")
	elif current_weapon.name == "Shotgun":
		current_weapon.hide()
		current_weapon = get_node("Pistol")
	current_weapon.show()
	print("Switched to: ", current_weapon.name)

func _process(delta):
	if multiplayer_sync.get_multiplayer_authority() == multiplayer.get_unique_id():
		if Input.is_action_just_pressed("shoot"):
			current_weapon.shoot()

		if Input.is_action_just_pressed("reload"):
			current_weapon.reload()

		if Input.is_action_just_pressed("switch_weapon"):
			switch_weapon()

func _on_switch_cooldown_timer_timeout():
	can_switch = true
