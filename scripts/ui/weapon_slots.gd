extends Control

@onready var slot_1 = $Slot1
@onready var slot_2 = $Slot2

func update_slot(index: int, weapon_name: String):
    var display_name = weapon_name if weapon_name != "" else "Empty"
    match index:
        0:
            if slot_1:
                slot_1.text = "1. " + display_name
        1:
            if slot_2:
                slot_2.text = "2. " + display_name
        _:
            pass