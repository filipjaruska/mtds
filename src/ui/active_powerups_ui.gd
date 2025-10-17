extends Control
class_name ActivePowerupsUI

@onready var effects_container = $ScrollContainer/VBoxContainer

var active_effect_displays: Array[Control] = []

func _ready():
	set_process(true)

func _process(delta):
	_update_effect_timers(delta)

func update_active_powerups(active_powerups: Array[ActivePowerup]):
	for display in active_effect_displays:
		display.queue_free()
	active_effect_displays.clear()
	
	for powerup in active_powerups:
		var display = _create_effect_display(powerup)
		effects_container.add_child(display)
		active_effect_displays.append(display)

func _create_effect_display(powerup: ActivePowerup) -> Control:
	var display = Control.new()
	var hbox = HBoxContainer.new()
	display.add_child(hbox)
	hbox.name = "HBoxContainer"
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	vbox.add_child(name_label)
	
	var stack_label = Label.new()
	stack_label.name = "StackLabel"
	vbox.add_child(stack_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	hbox.add_child(progress_bar)
	
	var card = powerup.powerup_card
	
	if card.icon_texture:
		icon.texture = card.icon_texture
	
	name_label.text = card.get_display_name()
	
	if powerup.stack_count > 1:
		stack_label.text = "x" + str(powerup.stack_count)
		stack_label.visible = true
	else:
		stack_label.visible = false
	
	progress_bar.max_value = 100
	progress_bar.value = powerup.get_remaining_time_percentage() * 100
	
	icon.modulate = card.rarity_color
	progress_bar.modulate = card.rarity_color
	
	display.set_meta("powerup", powerup)
	return display

func _update_effect_timers(_delta: float):
	for display in active_effect_displays:
		if not is_instance_valid(display):
			continue
		
		var powerup = display.get_meta("powerup")
		if not is_instance_valid(powerup):
			continue
		
		var progress_bar = display.get_node("HBoxContainer/ProgressBar")
		progress_bar.value = powerup.get_remaining_time_percentage() * 100
		
		if powerup.get_remaining_time_percentage() < 0.25:
			progress_bar.modulate = Color.RED
		elif powerup.get_remaining_time_percentage() < 0.5:
			progress_bar.modulate = Color.ORANGE

func add_powerup_effect(powerup: ActivePowerup):
	var display = _create_effect_display(powerup)
	effects_container.add_child(display)
	active_effect_displays.append(display)

func remove_powerup_effect(powerup: ActivePowerup):
	for i in range(active_effect_displays.size() - 1, -1, -1):
		var display = active_effect_displays[i]
		if display.get_meta("powerup") == powerup:
			display.queue_free()
			active_effect_displays.remove_at(i)
			break
