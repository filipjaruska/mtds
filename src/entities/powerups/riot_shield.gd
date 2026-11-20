extends StaticBody2D
class_name RiotShield
## Steel Skin's shield. Lives under PlayerController, so it turns with the
## (already replicated) aim. Shots stop on it (physics layer 4 "shields";
## players do not collide with it). HP is decided by the host; every peer
## shows the same HP and the shatter.

const SHIELD_LAYER := 8 # physics layer 4 "shields"
const THICKNESS := 10.0

var max_hp := 150.0
var hp := 150.0

var _body: Polygon2D
var _edge: Line2D
var _color := Color.WHITE

## Built in code; `name` must be the same on every peer for the RPCs.
static func create(width: float, distance: float, shield_hp: float, color: Color) -> RiotShield:
	var shield := RiotShield.new()
	shield.name = "RiotShield"
	shield.position = Vector2(distance, 0.0)
	shield.max_hp = shield_hp
	shield.hp = shield_hp
	shield._color = color
	shield.collision_layer = SHIELD_LAYER
	shield.collision_mask = 0
	shield.add_to_group("riot_shield")

	var half := Vector2(THICKNESS, width) * 0.5
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	shield.add_child(collision)

	# Slightly curved slab facing away from the player.
	var points := PackedVector2Array()
	for i in range(9):
		var t := i / 8.0
		var y := lerpf(-half.y, half.y, t)
		points.append(Vector2(half.x - 4.0 * pow(2.0 * t - 1.0, 2.0), y))
	for i in range(8, -1, -1):
		var t := i / 8.0
		var y := lerpf(-half.y, half.y, t)
		points.append(Vector2(-half.x - 4.0 * pow(2.0 * t - 1.0, 2.0), y))
	shield._body = Polygon2D.new()
	shield._body.polygon = points
	shield._body.color = Color(color.darkened(0.2), 0.75)
	shield.add_child(shield._body)

	shield._edge = Line2D.new()
	shield._edge.width = 3.0
	shield._edge.default_color = color.lightened(0.4)
	for i in range(9):
		shield._edge.add_point(points[i])
	shield.add_child(shield._edge)
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
	_body.color.a = lerpf(0.3, 0.75, hp_fraction())
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
