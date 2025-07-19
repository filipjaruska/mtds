@tool
extends CharacterBody2D
class_name PlayerTool

@onready var player_controller: Node2D = $PlayerController
@onready var camera_component: Node2D = $CameraComponent
@onready var name_label: Label = $PlayerNameLabel

var player_name: String = "Player":
	set(value):
		player_name = value
		if name_label:
			name_label.text = value
		_update_components()

var player_id: int = 0

var movement_normal_speed: float = 200.0:
	set(value):
		movement_normal_speed = value
		_update_components()

var movement_dash_speed: float = 800.0:
	set(value):
		movement_dash_speed = value
		_update_components()

var movement_crouch_speed: float = 100.0:
	set(value):
		movement_crouch_speed = value
		_update_components()

var dash_duration: float = 0.3:
	set(value):
		dash_duration = value
		_update_components()

var dash_cooldown: float = 3500.0:
	set(value):
		dash_cooldown = value
		_update_components()

var camera_lookahead_distance: float = 175.0:
	set(value):
		camera_lookahead_distance = value
		_update_components()

var camera_offset_disable_threshold: float = 200.0:
	set(value):
		camera_offset_disable_threshold = value
		_update_components()

var camera_transition_speed: float = 5.0:
	set(value):
		camera_transition_speed = value
		_update_components()

var camera_zoom_out_factor: float = 0.7:
	set(value):
		camera_zoom_out_factor = value
		_update_components()

var camera_zoom_transition_speed: float = 2.0:
	set(value):
		camera_zoom_transition_speed = value
		_update_components()

var health_max_health: float = 100.0:
	set(value):
		health_max_health = value
		_update_components()

var health_physical_resist: float = 0.0:
	set(value):
		health_physical_resist = value
		_update_components()

var health_resist_penetration: float = 0.0:
	set(value):
		health_resist_penetration = value
		_update_components()

var enable_camera_customization: bool = true:
	set(value):
		enable_camera_customization = value
		notify_property_list_changed()

var enable_health_customization: bool = true:
	set(value):
		enable_health_customization = value
		notify_property_list_changed()

var show_debug_info: bool = false:
	set(value):
		show_debug_info = value
		notify_property_list_changed()

func _ready():
	if not Engine.is_editor_hint():
		_update_components()

func _update_components():
	if not is_inside_tree():
		return
		
	if player_controller:
		player_controller.normal_speed = movement_normal_speed
		player_controller.dash_speed = movement_dash_speed
		player_controller.crouch_speed = movement_crouch_speed
		player_controller.dash_duration = dash_duration
		player_controller.dash_cooldown = dash_cooldown
	
	if camera_component:
		camera_component.lookahead_distance = camera_lookahead_distance
		camera_component.offset_disable_threshold = camera_offset_disable_threshold
		camera_component.transition_speed = camera_transition_speed
		camera_component.zoom_out_factor = camera_zoom_out_factor
		camera_component.zoom_transition_speed = camera_zoom_transition_speed
	
	var health_component = get_health_component()
	if health_component:
		health_component.MAX_HEALTH = health_max_health
		health_component.physical_resist = health_physical_resist
		health_component.resist_penetration = health_resist_penetration
		if health_component.current_health > health_max_health:
			health_component.current_health = health_max_health
		var health_bar = get_node_or_null("HealthBar")
		if health_bar:
			health_bar.max_value = health_max_health
			health_bar.value = health_component.current_health
	
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
	camera_lookahead_distance = 175.0
	camera_offset_disable_threshold = 200.0
	camera_transition_speed = 5.0
	camera_zoom_out_factor = 0.7
	camera_zoom_transition_speed = 2.0
	health_max_health = 100.0
	health_physical_resist = 0.0
	health_resist_penetration = 0.0
	print("Player settings reset to defaults")

func _get_property_list() -> Array:
	var properties: Array = []
	
	properties.append({
		"name": "Player Configuration",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY,
		"hint_string": "player"
	})
	
	properties.append({
		"name": "player_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	properties.append({
		"name": "player_id",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,999,1"
	})
	
	if show_debug_info:
		properties.append({
			"name": "player_debug_print_stats",
			"type": TYPE_CALLABLE,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Print Stats,Terminal"
		})
		
		properties.append({
			"name": "player_reset_to_defaults",
			"type": TYPE_CALLABLE,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Reset to Defaults,ArrowCounterclockwise"
		})
	
	properties.append({
		"name": "Movement System",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY,
		"hint_string": "movement"
	})
	
	properties.append({
		"name": "movement_normal_speed",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "50,500,10,suffix:px/s"
	})
	
	properties.append({
		"name": "movement_crouch_speed",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "25,250,5,suffix:px/s"
	})
	
	properties.append({
		"name": "movement_dash_speed",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "400,1200,25,suffix:px/s"
	})
	
	properties.append({
		"name": "dash_duration",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,1.0,0.05,suffix:s"
	})
	
	properties.append({
		"name": "dash_cooldown",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1000,10000,100,suffix:ms"
	})
	
	if enable_camera_customization:
		properties.append({
			"name": "Camera System",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
			"hint_string": "camera"
		})
		
		properties.append({
			"name": "camera_lookahead_distance",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "50,400,5,suffix:px"
		})
		
		properties.append({
			"name": "camera_offset_disable_threshold",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "50,500,10,suffix:px"
		})
		
		properties.append({
			"name": "camera_transition_speed",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,10.0,0.1"
		})
		
		properties.append({
			"name": "Camera Zoom",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP,
			"hint_string": "camera"
		})
		
		properties.append({
			"name": "camera_zoom_out_factor",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.3,1.0,0.05"
		})
		
		properties.append({
			"name": "camera_zoom_transition_speed",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.5,5.0,0.1"
		})
	
	if enable_health_customization:
		properties.append({
			"name": "Health System",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
			"hint_string": "health"
		})
		
		properties.append({
			"name": "health_max_health",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "10,1000,5,suffix:HP"
		})
		
		properties.append({
			"name": "health_physical_resist",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,0.95,0.05,suffix:%"
		})
		
		properties.append({
			"name": "health_resist_penetration",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.05"
		})
	
	properties.append({
		"name": "Configuration Options",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY,
		"hint_string": "config"
	})
	
	properties.append({
		"name": "enable_camera_customization",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	properties.append({
		"name": "enable_health_customization",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	properties.append({
		"name": "show_debug_info",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	return properties

func get_weapon_manager():
	if player_controller:
		return player_controller.weapon_manager
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
	if name_label:
		name_label.text = player_name_value

func get_player_name() -> String:
	return player_name
