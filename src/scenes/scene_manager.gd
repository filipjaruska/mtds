extends Node2D

# Didn't know about MultiplayerSpawner node before making this component.
# I think that they are the same thing but not sure.
# It just spawns the player on pre-established locations in the main scene.

@export var playerScene: PackedScene

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