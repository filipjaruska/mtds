extends CanvasLayer

func update_ammo(ammo: int, max_ammo: int):
	$Ammo.text = "%d / %d" % [ammo, max_ammo]

func update_health(hp: int, max_hp: int):
	$Health.text = "%d / %d HP" % [hp, max_hp]
