extends Control

func _on_exit_pressed():
	get_tree().quit()


func _on_options_pressed():
	get_tree().change_scene_to_file("res://nodes/menu/options.tscn")


func _on_button_pressed():
	get_tree().change_scene_to_file("res://nodes/menu/start_game.tscn")
