extends Node2D

# Didn't know about MultiplayerSpawner node before making this component.
# I think that they are the same thing but not sure.
# It just spawns the player on pre-established locations in the main scene.

@export var playerScene: PackedScene

func _ready():
	var index: int = 0
	for i in GameManager.players:
		var currentPlayer: Node = playerScene.instantiate()
		currentPlayer.name = str(GameManager.players[i].id)
		currentPlayer.set_player_name(str(GameManager.players[i].name)) # changes the text in player lable to the player nickname
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
		index += 1
