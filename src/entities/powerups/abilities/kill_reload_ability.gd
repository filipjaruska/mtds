extends CardAbility
class_name KillReloadAbility
## A kill refills your magazines. Behaviour: CardEffects.notify_kill.

func get_kind() -> StringName:
	return &"kill_reload"
