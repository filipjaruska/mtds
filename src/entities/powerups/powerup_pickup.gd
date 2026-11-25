extends Node2D
class_name PowerupPickup
## A powerup card lying on the map. Like weapon pickups, the host decides who
## gets it: the first valid request wins, later ones are ignored.
## Its look is powerup_pickup.tscn: the card (Sprite2D), a rarity-coloured
## copy behind it (GlowEffect) and the pickup prompt (Label).

const PICKUP_RANGE := 80.0

@export var powerup_def: PowerupDef

const SCENE := "res://src/entities/powerups/powerup_pickup.tscn"

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_effect: Sprite2D = $GlowEffect

var _local_player_inside: Node = null
var _taken := false

const CARD_SCALE := 0.35

func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)
	_apply_visuals()
	# The card floats and tilts a little; the glow behind it breathes.
	if sprite:
		var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", -6.0, 0.9)
		bob.parallel().tween_property(sprite, "rotation", 0.06, 0.9)
		bob.tween_property(sprite, "position:y", 2.0, 0.9)
		bob.parallel().tween_property(sprite, "rotation", -0.06, 0.9)
	if glow_effect:
		var tween := create_tween().set_loops()
		tween.tween_property(glow_effect, "modulate:a", 0.25, 1.0)
		tween.tween_property(glow_effect, "modulate:a", 0.7, 1.0)

func _apply_visuals() -> void:
	if powerup_def == null:
		return
	var texture: Texture2D = powerup_def.card_texture
	if texture == null:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(160, 224)
		texture = placeholder
	if sprite:
		sprite.texture = texture
		sprite.scale = Vector2.ONE * CARD_SCALE
	if glow_effect:
		# A slightly larger, rarity-tinted copy behind the card.
		glow_effect.texture = texture
		glow_effect.scale = Vector2.ONE * CARD_SCALE * 1.18
		glow_effect.modulate = Color(powerup_def.rarity_color, 0.5)
		glow_effect.self_modulate = Color(2.0, 2.0, 2.0)
	if label:
		label.text = _prompt()

func _process(_delta: float) -> void:
	if _local_player_inside and not is_instance_valid(_local_player_inside):
		_local_player_inside = null
	if _local_player_inside == null or _taken or not InputManager.is_interact_pressed():
		return
	var powerup_manager: PowerupManager = _local_player_inside.get_node_or_null("PowerupManager")
	if powerup_manager == null:
		return
	if powerup_manager.has_free_slot():
		_request_pickup.rpc_id(1)
	else:
		_show_inventory_full_feedback()

@rpc("any_peer", "call_local", "reliable")
func _request_pickup() -> void:
	if not multiplayer.is_server() or _taken or powerup_def == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := _find_player(sender)
	if player == null or player.global_position.distance_to(global_position) > PICKUP_RANGE:
		return
	_taken = true
	_grant.rpc_id(sender)
	despawn.rpc()

## Host -> collecting player.
@rpc("any_peer", "call_local", "reliable")
func _grant() -> void:
	if multiplayer.get_remote_sender_id() != 1 or powerup_def == null:
		return
	var player := _find_player(multiplayer.get_unique_id())
	var powerup_manager: PowerupManager = player.get_node_or_null("PowerupManager") if player else null
	if powerup_manager:
		powerup_manager.add_to_inventory(powerup_def.id)

@rpc("authority", "call_local", "reliable")
func despawn() -> void:
	_taken = true
	queue_free()

func _find_player(peer_id: int) -> Node2D:
	for node in get_tree().get_nodes_in_group("Player"):
		if node.get_multiplayer_authority() == peer_id:
			return node
	return null

func _show_inventory_full_feedback() -> void:
	if not label:
		return
	label.text = "Inventory full"
	label.modulate = UiPalette.BAD
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 1.0)
	tween.tween_callback(func():
		if label and powerup_def:
			label.text = _prompt()
	)

func _prompt() -> String:
	return "[%s] %s" % [GameSettings.get_action_binding_text("interact"), powerup_def.get_display_name()]

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player") or not body.is_multiplayer_authority() or _taken:
		return
	_local_player_inside = body
	if label:
		label.visible = true
	create_tween().tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)

func _on_body_exited(body: Node) -> void:
	if body != _local_player_inside:
		return
	_local_player_inside = null
	if label:
		label.visible = false
	create_tween().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

## A card pickup at `spawn_position` (from powerup_pickup.tscn).
static func create_pickup(def: PowerupDef, spawn_position: Vector2) -> PowerupPickup:
	var pickup: PowerupPickup = load(SCENE).instantiate()
	pickup.position = spawn_position
	pickup.powerup_def = def
	return pickup
