@tool
extends CharacterBody2D
class_name PlayerTool
## Player root. Holds the tunable stats shown in the inspector and pushes them
## into the components at runtime.

@onready var player_controller: Node2D = $PlayerController
@onready var camera_component: Node2D = $CameraComponent
@onready var name_label: Label = $PlayerNameLabel

@export_category("Player Configuration")
@export var player_name: String = "Name":
	set(value):
		player_name = value
		if name_label:
			name_label.text = value
@export_range(0, 999, 1) var player_id: int = 0

@export_tool_button("Print Stats", "Terminal") var print_stats_button := player_debug_print_stats
@export_tool_button("Reset to Defaults", "ArrowCounterclockwise") var reset_defaults_button := player_reset_to_defaults

@export_category("Movement System")
@export_range(50, 500, 10, "suffix:px/s") var movement_normal_speed: float = 200.0:
	set(value):
		movement_normal_speed = value
		_update_components()
@export_range(25, 250, 5, "suffix:px/s") var movement_crouch_speed: float = 100.0:
	set(value):
		movement_crouch_speed = value
		_update_components()
@export_range(400, 1200, 25, "suffix:px/s") var movement_dash_speed: float = 800.0:
	set(value):
		movement_dash_speed = value
		_update_components()
@export_range(0.1, 1.0, 0.05, "suffix:s") var dash_duration: float = 0.3:
	set(value):
		dash_duration = value
		_update_components()
@export_range(1000, 10000, 100, "suffix:ms") var dash_cooldown: float = 3500.0:
	set(value):
		dash_cooldown = value
		_update_components()

@export_category("Camera System")
@export_range(50, 400, 5, "suffix:px") var camera_lookahead_distance: float = ViewRules.LOOKAHEAD:
	set(value):
		camera_lookahead_distance = value
		_update_components()
@export_range(50, 500, 10, "suffix:px") var camera_offset_disable_threshold: float = 200.0:
	set(value):
		camera_offset_disable_threshold = value
		_update_components()
@export_range(1.0, 10.0, 0.1) var camera_transition_speed: float = 5.0:
	set(value):
		camera_transition_speed = value
		_update_components()
@export_subgroup("Camera Zoom")
@export_range(0.3, 1.0, 0.05) var camera_zoom_out_factor: float = ViewRules.CTRL_ZOOM:
	set(value):
		camera_zoom_out_factor = value
		_update_components()
@export_range(0.5, 5.0, 0.1) var camera_zoom_transition_speed: float = 2.0:
	set(value):
		camera_zoom_transition_speed = value
		_update_components()

@export_category("Health System")
@export_range(10, 1000, 5, "suffix:HP") var health_max_health: float = 100.0:
	set(value):
		health_max_health = value
		_update_components()
@export_range(0.0, 0.95, 0.05) var health_physical_resist: float = 0.0:
	set(value):
		health_physical_resist = value
		_update_components()
@export_range(0.0, 1.0, 0.05) var health_resist_penetration: float = 0.0:
	set(value):
		health_resist_penetration = value
		_update_components()

func _ready():
	if not Engine.is_editor_hint():
		_update_components()

func _update_components():
	# Components are not @tool scripts, so only push values at runtime.
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	if player_controller:
		player_controller.normal_speed = movement_normal_speed
		player_controller.dash_speed = movement_dash_speed
		player_controller.crouch_speed = movement_crouch_speed
		player_controller.dash_duration = dash_duration
		player_controller.set_base_dash_cooldown(dash_cooldown)

	if camera_component:
		camera_component.lookahead_distance = camera_lookahead_distance
		camera_component.offset_disable_threshold = camera_offset_disable_threshold
		camera_component.transition_speed = camera_transition_speed
		camera_component.zoom_out_factor = camera_zoom_out_factor
		camera_component.zoom_transition_speed = camera_zoom_transition_speed

	var health_component = get_health_component()
	if health_component:
		health_component.physical_resist = health_physical_resist
		health_component.resist_penetration = health_resist_penetration
		health_component.set_base_max_health(health_max_health)

	if name_label:
		name_label.text = player_name

func player_debug_print_stats():
	print("=== PLAYER STATS ===")
	print("Name: ", player_name)
	print("Movement Speeds: Normal=", movement_normal_speed, " Dash=", movement_dash_speed, " Crouch=", movement_crouch_speed)
	print("Dash: Duration=", dash_duration, " Cooldown=", dash_cooldown)
	print("Camera: Lookahead=", camera_lookahead_distance, " Transition=", camera_transition_speed)
	print("Health: Max=", health_max_health, " Resist=", health_physical_resist, " Penetration=", health_resist_penetration)
	print("==================")

func player_reset_to_defaults():
	player_name = "Player"
	movement_normal_speed = 200.0
	movement_dash_speed = 800.0
	movement_crouch_speed = 100.0
	dash_duration = 0.3
	dash_cooldown = 3500.0
	camera_lookahead_distance = ViewRules.LOOKAHEAD
	camera_offset_disable_threshold = 200.0
	camera_transition_speed = 5.0
	camera_zoom_out_factor = ViewRules.CTRL_ZOOM
	camera_zoom_transition_speed = 2.0
	health_max_health = 100.0
	health_physical_resist = 0.0
	health_resist_penetration = 0.0
	print("Player settings reset to defaults")

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

func get_max_health() -> float:
	return health_max_health

func get_physical_resist() -> float:
	return health_physical_resist

func get_resist_penetration() -> float:
	return health_resist_penetration

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
