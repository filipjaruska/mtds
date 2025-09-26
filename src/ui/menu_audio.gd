extends HSlider

@export
var bus_name: String
var bus_index: int

func _ready():
	bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		editable = false
		visible = false
		value = 0.5 # backup value
		return
	
	value_changed.connect(on_value_change)
	value = db_to_linear(
		AudioServer.get_bus_volume_db(bus_index)
	)
	
func on_value_change(a: float):
	if bus_index == -1:
		return
		
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(a)
	)
