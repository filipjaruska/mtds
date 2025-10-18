extends Control

func _on_exit_pressed():
	get_tree().quit()


func _on_options_pressed():
	get_tree().change_scene_to_file("uid://b6j40ehxmqs5w")


func _on_vsai_pressed():
	get_tree().change_scene_to_file("uid://ce1oauidq2qpa")


func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://src/ui/menus/game_browser.tscn") # Navigate to game browser
