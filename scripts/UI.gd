extends Control

func update_ammo(ammo: int, max_ammo: int):
    $Ammo.text = "%d / %d" % [ammo, max_ammo]
