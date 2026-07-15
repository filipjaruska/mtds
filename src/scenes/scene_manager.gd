extends Node2D

@export var playerScene: PackedScene
@export var default_weapon_scene: PackedScene = preload("res://src/entities/weapons/pistol.tscn")

func _ready():
	var index: int = 0
	for i in GameManager.players:
		var player_id: int = GameManager.players[i].id
		var currentPlayer = playerScene.instantiate()
		currentPlayer.name = str(player_id)
		currentPlayer.set_multiplayer_authority(player_id)
		currentPlayer.set_player_name(str(GameManager.players[i].name))
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
		index += 1
	
	call_deferred("_equip_default_weapons")

func _equip_default_weapons() -> void:
	if default_weapon_scene == null:
		return
	
	for player_data in GameManager.get_all_players():
		var player_id: int = player_data.id
		if multiplayer.get_unique_id() != player_id:
			continue
		
		var player_node = get_node_or_null(str(player_id))
		if player_node == null:
			continue
		
		var weapon_manager = player_node.get_node("PlayerController/WeaponManager")
		weapon_manager.add_weapon(default_weapon_scene.instantiate(), true)