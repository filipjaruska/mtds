extends "res://src/scenes/scene_manager.gd"
## The tutorial (single player, started by TutorialLauncher). A row of rooms,
## one lesson each; the signs name your actual key bindings: {action} in a
## sign's text is replaced with what that input action is bound to.

func _ready() -> void:
	var token := RegEx.create_from_string("\\{(\\w+)\\}")
	for sign in $Signs.get_children():
		var text: String = sign.text
		for found in token.search_all(text):
			var action := found.get_string(1)
			if InputMap.has_action(action):
				text = text.replace(found.get_string(), "[%s]" % GameSettings.get_action_binding_text(action))
		sign.text = text
		# The signs keep their size from the scene; the look comes from the palette.
		sign.remove_theme_color_override("font_color")
		UiPalette.world_text(sign, UiPalette.L, UiPalette.TEXT)
	super._ready()
