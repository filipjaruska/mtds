extends Node2D

@export var playerScene: PackedScene

func _ready():
	var index = 0
	for i in GameManager.players:
		var currentPlayer = playerScene.instantiate()
		currentPlayer.name = str(GameManager.players[i].id)
		currentPlayer.set_player_name(str(GameManager.players[i].name))
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnLocation"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
		index += 1
