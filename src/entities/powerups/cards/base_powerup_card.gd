extends Resource
class_name BasePowerupCard

enum PowerupType {
	SPEED_BOOST,
	DAMAGE_BOOST,
	HEALTH_BOOST,
	RELOAD_SPEED,
	FIRE_RATE,
	ARMOR
}

@export var type: PowerupType
@export var name: String = ""
@export var description: String = ""
@export var icon_texture: Texture2D
@export var rarity_color: Color = Color.WHITE

@export var base_effect_value: float = 0.0
@export var duration: float = 30.0
@export var stack_multiplier: float = 2.0
@export var max_stack_count: int = 4
@export var stack_bonus_per_card: float = 0.1

func apply_effect(_target_player: Node, _effect_value: float):
	push_error("apply_effect must be implemented in subclass: " + get_script().resource_path)

func remove_effect(_target_player: Node, _effect_value: float):
	push_error("remove_effect must be implemented in subclass: " + get_script().resource_path)

func get_stacked_effect_value(stack_count: int) -> float:
	if stack_count <= 1:
		return base_effect_value
	var bonus = (stack_count - 1) * stack_bonus_per_card
	return base_effect_value * (stack_multiplier + bonus)

func get_display_name() -> String:
	return name if name != "" else PowerupType.keys()[type].replace("_", " ").capitalize()

func get_type_description() -> String:
	return description if description != "" else _get_default_description()

func _get_default_description() -> String:
	match type:
		PowerupType.SPEED_BOOST: return "Increases movement speed"
		PowerupType.DAMAGE_BOOST: return "Increases weapon damage"
		PowerupType.HEALTH_BOOST: return "Increases maximum health"
		PowerupType.RELOAD_SPEED: return "Increases reload speed"
		PowerupType.FIRE_RATE: return "Increases weapon fire rate"
		PowerupType.ARMOR: return "Reduces incoming damage"
		_: return "Unknown effect"

func _get_player_controller(player: Node) -> Node:
	return player.get_node("PlayerController") if player else null

func _get_weapon_manager(player: Node) -> Node:
	var controller = _get_player_controller(player)
	return controller.weapon_manager if controller else null

func _get_health_component(player: Node) -> Node:
	return player.get_node("HealthComponent") if player else null
