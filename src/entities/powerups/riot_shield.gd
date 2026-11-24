extends StaticBody2D
class_name RiotShield
## Steel Skin's shield. Lives under PlayerController, so it turns with the
## (already replicated) aim. Shots stop on it (physics layer 4 "shields";
## players do not collide with it). HP is decided by the host; every peer
## shows the same HP and the shatter.

const SHIELD_LAYER := 8 # physics layer 4 "shields"
const SCENE_PATH := "res://src/entities/powerups/riot_shield.tscn"
## Width of the shield as drawn in the scene; wider shields stretch it.
const SCENE_WIDTH := 72.0

var max_hp := 150.0
var hp := 150.0

@onready var _visual: Node2D = $Visual
@onready var _body: CanvasItem = $Visual/Body

## Its look is riot_shield.tscn (Visual is tinted with the card's colour).
## `name` must be the same on every peer for the RPCs.
static func create(width: float, distance: float, shield_hp: float, color: Color) -> RiotShield:
	var shield: RiotShield = load(SCENE_PATH).instantiate()
	shield.name = "RiotShield"
	shield.position = Vector2(distance, 0.0)
	shield.max_hp = shield_hp
	shield.hp = shield_hp
	shield.collision_layer = SHIELD_LAYER
	shield.collision_mask = 0
	shield.add_to_group("riot_shield")
	var collision: CollisionShape2D = shield.get_node("Collision")
	var shape: RectangleShape2D = collision.shape.duplicate()
	shape.size.y = width
	collision.shape = shape
	var visual: Node2D = shield.get_node("Visual")
	visual.scale.y = width / SCENE_WIDTH
	visual.modulate = color
	return shield

func _ready() -> void:
	# Pop in.
	scale = Vector2(0.2, 0.2)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(self, "scale", Vector2.ONE, 0.25)

func hp_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0

## Host only: called by CombatServer when a shot stops on this shield.
func take_hit(amount: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_sync_hp.rpc(hp)
	if hp <= 0.0:
		_shatter.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_hp(value: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	hp = value
	# Fade and flash as it takes damage.
	_body.self_modulate.a = lerpf(0.4, 1.0, hp_fraction())
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(2.0, 2.0, 2.0), 0.04)
	flash.tween_property(self, "modulate", Color.WHITE, 0.12)

@rpc("any_peer", "call_local", "reliable")
func _shatter() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	hp = 0.0
	collision_layer = 0
	remove_from_group("riot_shield")
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.6, 1.3), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
