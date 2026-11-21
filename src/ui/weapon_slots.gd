extends HBoxContainer
## The two weapon slots under the ammo count: "1 PISTOL" "2 EMPTY", the one in
## your hands outlined in orange (SlotTagActive).

@onready var _slots: Array[Label] = [$WeaponSlot1, $WeaponSlot2]

func show_slots(names: Array, active: int) -> void:
	for i in range(_slots.size()):
		var weapon_name: String = names[i] if i < names.size() else ""
		_slots[i].text = "%d %s" % [i + 1, weapon_name.to_upper() if weapon_name != "" else "EMPTY"]
		_slots[i].theme_type_variation = &"SlotTagActive" if i == active and weapon_name != "" else &"SlotTag"
