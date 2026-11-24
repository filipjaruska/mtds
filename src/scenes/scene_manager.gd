@tool
extends Node2D
class_name GameMap
## Root of a playable map: spawns the players and owns map-level network
## objects such as dropped weapon pickups.
##
## Making a map: duplicate res://src/scenes/map_template.tscn into
## res://src/scenes/maps/ (every scene there is listed in the lobby). A map needs
##   - spawn points (SpawnPoint nodes) named 0, 1, 2 ... one per player;
##     in team matches Red spawns on even numbers and Blue on odd ones
##   - walls painted with a tile set whose physics layer is on layer 3
##     "walls", so shots and players stop at them
##   - weapon spots (WeaponSpawner) and card areas (PowerupSpawner), optional
## The scene tree shows a warning on this node while something is missing.

const RULES: GameRules = preload("res://src/game_rules.tres")

const WEAPON_PICKUP_SCENE := preload("res://src/entities/weapons/weapon_pickup.tscn")
## How far from the dropping player a drop may land (guards against bogus requests).
const MAX_DROP_DISTANCE := 200.0

@export var playerScene: PackedScene
## Spawn points this map must have. 0 = the max players in game_rules.tres.
@export_range(0, 8) var spawn_points_needed: int = 0

var _dropped_pickup_count: int = 0

func _ready():
	if Engine.is_editor_hint():
		# Re-check the map whenever something in it changes.
		get_tree().node_added.connect(_on_editor_tree_changed)
		get_tree().node_removed.connect(_on_editor_tree_changed)
		get_tree().node_renamed.connect(_on_editor_tree_changed)
		return
	var combat := CombatServer.new()
	combat.name = "Combat"
	add_child(combat)

	var team_mode := GameManager.is_team_mode()
	for player_id in GameManager.players:
		var data: Dictionary = GameManager.players[player_id]
		var currentPlayer = playerScene.instantiate()
		currentPlayer.name = str(player_id)
		currentPlayer.set_multiplayer_authority(player_id)
		currentPlayer.set_player_name(str(data.name))
		# Team matches show team colours instead of each player's own colour.
		var color: Color = TeamRules.COLORS[GameManager.get_team(player_id)] if team_mode else _player_color_from_data(data)
		currentPlayer.set_player_color(color)
		add_child(currentPlayer)
		var index := TeamRules.spawn_index(GameManager.players, player_id, team_mode)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position

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

# --- Editor checks ----------------------------------------------------------------

func _on_editor_tree_changed(node: Node) -> void:
	if is_ancestor_of(node):
		update_configuration_warnings.call_deferred()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if playerScene == null:
		warnings.append("Player Scene is empty: set it to res://src/entities/player/player.tscn.")
	# In the editor GameRules' script is not running; read the value as plain data.
	var max_players = RULES.get("max_players")
	var needed := spawn_points_needed if spawn_points_needed > 0 else (int(max_players) if max_players != null else 8)
	var names := {}
	for node in find_children("*", "", true, false):
		if node.is_in_group("PlayerSpawnLocation") or node is SpawnPoint:
			names[String(node.name)] = true
	var missing: Array[String] = []
	for i in range(needed):
		if not names.has(str(i)):
			missing.append(str(i))
	if not missing.is_empty():
		warnings.append("Needs %d spawn points named 0 to %d (SpawnPoint nodes). Missing: %s." % [needed, needed - 1, ", ".join(missing)])
	if not _has_walls():
		warnings.append("No walls: paint walls with a tile set whose physics layer is on layer 3 \"walls\" (like src/assets/maps/catacombs/tiles.tres), or shots and players pass through.")
	return warnings

## Some painted tile is solid on the "walls" physics layer.
func _has_walls() -> bool:
	for layer: TileMapLayer in find_children("*", "TileMapLayer", true, false):
		var tiles := layer.tile_set
		if tiles == null:
			continue
		for i in range(tiles.get_physics_layers_count()):
			if not tiles.get_physics_layer_collision_layer(i) & CombatServer.WALL_LAYER:
				continue
			for cell in layer.get_used_cells():
				var data := layer.get_cell_tile_data(cell)
				if data and data.get_collision_polygons_count(i) > 0:
					return true
	return false
