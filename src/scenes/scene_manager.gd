extends Node2D
## Root of a playable map: spawns the players and owns map-level network
## objects such as dropped weapon pickups.

const WEAPON_PICKUP_SCENE := preload("res://src/entities/weapons/weapon_pickup.tscn")
## How far from the dropping player a drop may land (guards against bogus requests).
const MAX_DROP_DISTANCE := 200.0

@export var playerScene: PackedScene

var _dropped_pickup_count: int = 0

func _ready():
	var combat := CombatServer.new()
	combat.name = "Combat"
	add_child(combat)

	var index: int = 0
	for i in GameManager.players:
		var player_id: int = GameManager.players[i].id
		var currentPlayer = playerScene.instantiate()
		currentPlayer.name = str(player_id)
		currentPlayer.set_multiplayer_authority(player_id)
		currentPlayer.set_player_name(str(GameManager.players[i].name))
		currentPlayer.set_player_color(_player_color_from_data(GameManager.players[i]))
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
		index += 1

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int) -> void:
	var player_node := get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()

func _player_color_from_data(player_data: Dictionary) -> Color:
	var color_value: Variant = player_data.get("color", Color.WHITE)
	if color_value is Color:
		var tint: Color = color_value
		tint.a = 1.0
		return tint
	if typeof(color_value) == TYPE_STRING:
		var tint := Color.html(str(color_value))
		tint.a = 1.0
		return tint
	return Color.WHITE

## Owner -> host: put a weapon the sender is carrying on the ground.
## Must be sent before the owner syncs its new loadout, so the host's mirror of
## the sender's loadout still contains the weapon when this arrives.
@rpc("any_peer", "call_local", "reliable")
func request_weapon_drop(def_id: StringName, pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var player := get_node_or_null(str(multiplayer.get_remote_sender_id()))
	if player == null or not WeaponDefs.has(def_id):
		return
	var holder: WeaponHolder = player.get_weapon_holder()
	if holder == null or not holder.has_weapon(def_id):
		return
	if pos.distance_to(player.global_position) > MAX_DROP_DISTANCE:
		pos = player.global_position
	_dropped_pickup_count += 1
	_spawn_weapon_pickup.rpc(def_id, pos, "DroppedWeapon_%d" % _dropped_pickup_count)

## Pickups get the same name on every peer so their RPCs resolve everywhere,
## and live under the map so they disappear with it.
@rpc("authority", "call_local", "reliable")
func _spawn_weapon_pickup(def_id: StringName, pos: Vector2, node_name: String) -> void:
	var def := WeaponDefs.get_def(def_id)
	if def == null or has_node(node_name):
		return
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	pickup.name = node_name
	pickup.position = pos
	pickup.setup(def)
	add_child(pickup)
