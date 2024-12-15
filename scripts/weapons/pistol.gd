extends RangedWeapon

# Edit gun specific properties through the Godot Editor

func _ready():
	animation_player.play(idle_animation)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == shooting_animation:
		animation_player.play(idle_animation)
