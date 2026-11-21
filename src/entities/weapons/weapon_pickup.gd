extends Area2D
## A weapon lying on the ground. The host decides who gets it:
## the local player asks with request_pickup(), the host checks that the pickup
## is still there and the player is close enough, grants the weapon to that
## player and despawns the pickup on every peer.

const PICKUP_RANGE := 120.0

@export var weapon_def: WeaponDef

@onready var label: Label = get_node_or_null("Label")
@onready var placeholder_sprite: Sprite2D = get_node_or_null("Sprite2D")

var _view: Node2D = null
var _local_player_inside: Node = null
var _taken := false

func _ready() -> void:
	if label:
		label.visible = false
	if placeholder_sprite:
		placeholder_sprite.visible = false
	_refresh()

func setup(def: WeaponDef) -> void:
	weapon_def = def
	if is_inside_tree():
		_refresh()

func _refresh() -> void:
	if is_instance_valid(_view):
		_view.queue_free()
	_view = null
	if weapon_def == null:
		return
	if weapon_def.view_scene:
		_view = weapon_def.view_scene.instantiate()
		add_child(_view)
	if label:
		label.text = "[%s] %s" % [GameSettings.get_action_binding_text("interact"), weapon_def.get_display_name()]

func _process(_delta: float) -> void:
	if _local_player_inside and not is_instance_valid(_local_player_inside):
		_local_player_inside = null
	if _local_player_inside == null or _taken or weapon_def == null:
		return
	if not InputManager.is_interact_pressed():
		return
	var holder: WeaponHolder = _local_player_inside.get_weapon_holder()
	if holder and holder.can_pick_up():
		request_pickup.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_pickup() -> void:
	if not multiplayer.is_server() or _taken or weapon_def == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := _find_player(sender)
	if player == null or player.global_position.distance_to(global_position) > PICKUP_RANGE:
		return
	var holder: WeaponHolder = player.get_weapon_holder()
	if holder == null or not holder.can_pick_up():
		return
	_taken = true
	holder.grant_weapon.rpc_id(sender, weapon_def.id)
	despawn.rpc()

@rpc("authority", "call_local", "reliable")
func despawn() -> void:
	_taken = true
	queue_free()

func _find_player(peer_id: int) -> Node2D:
	for node in get_tree().get_nodes_in_group("Player"):
		if node.get_multiplayer_authority() == peer_id:
			return node
	return null

# Only the local player's presence matters: it is the only one that reads input here.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and body.is_multiplayer_authority():
		_local_player_inside = body
		if label:
			label.visible = true

func _on_body_exited(body: Node) -> void:
	if body == _local_player_inside:
		_local_player_inside = null
		if label:
			label.visible = false
