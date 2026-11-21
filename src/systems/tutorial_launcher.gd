extends Node
class_name TutorialLauncher
## Starts the tutorial straight from the menu: no hosting or joining. It runs
## as a one-player session on an offline peer (the local game is its own host,
## so everything works exactly as in a real match) through the normal lobby,
## which stays hidden. No time limit; Esc -> Leave tutorial goes back to the menu.

const TUTORIAL_MAP := "res://src/scenes/tutorial.tscn"
const LOBBY_SCENE := "res://src/ui/menus/lobby.tscn"

static func launch(tree: SceneTree) -> void:
	var launcher := TutorialLauncher.new()
	launcher.name = "TutorialLauncher"
	tree.root.add_child.call_deferred(launcher)

func _ready() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameManager.tutorial_mode = true
	GameManager.set_game_type(GameManager.GAME_TYPE_DEATHMATCH)
	GameManager.set_card_rules(GameManager.CARD_RULES_STANDARD)
	GameManager.set_map(TUTORIAL_MAP)
	GameManager.game_settings["match_duration_seconds"] = 36000.0
	if GameManager.local_player_name.is_empty():
		GameManager.local_player_name = "Player"
	get_tree().change_scene_to_file(LOBBY_SCENE)
	# Wait for the lobby to set itself up, then go straight into the map.
	for i in range(3):
		await get_tree().process_frame
	var lobby := get_tree().get_first_node_in_group("Lobby")
	if lobby:
		lobby.start_game(TUTORIAL_MAP)
	queue_free()
