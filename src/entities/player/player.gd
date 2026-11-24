extends CharacterBody2D
class_name Player
## The player root. Speeds, dash, health and camera feel are tuned in
## res://src/game_rules.tres (Player and Camera groups); the components read
## them from there.

@onready var player_controller: Node2D = $PlayerController
@onready var camera_component: Node2D = $CameraComponent
@onready var name_label: Label = $PlayerNameLabel

var player_name: String = "Player":
	set(value):
		player_name = value
		if name_label:
			name_label.text = value

func _ready() -> void:
	name_label.text = player_name

func get_weapon_holder() -> WeaponHolder:
	if player_controller:
		return player_controller.weapon_holder
	return null

func get_camera_component():
	return camera_component

func get_player_controller():
	return player_controller

func get_health_component():
	return get_node_or_null("HealthComponent")

func set_player_name(player_name_value: String):
	player_name = player_name_value

func get_player_name() -> String:
	return player_name

func set_player_color(color: Color) -> void:
	var tint := color
	tint.a = 1.0
	var sprite := get_node_or_null("PlayerSprite") as Sprite2D
	if sprite:
		sprite.modulate = tint

func get_player_color() -> Color:
	var sprite := get_node_or_null("PlayerSprite") as Sprite2D
	if sprite:
		return sprite.modulate
	return Color.WHITE
