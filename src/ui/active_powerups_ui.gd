extends Control
class_name ActivePowerupsUI

const ROW_MIN_SIZE := Vector2(180, 36)

@onready var effects_container = $ScrollContainer/VBoxContainer

var active_effect_displays: Array[Control] = []

func _ready():
	effects_container.add_theme_constant_override("separation", 8)
	set_process(true)

func _process(_delta: float):
	_update_effect_timers()

func update_active_powerups(active_powerups: Array[ActivePowerup]):
	for display in active_effect_displays:
		if is_instance_valid(display):
			display.queue_free()
	active_effect_displays.clear()
	
	for powerup in active_powerups:
		var display = _create_effect_display(powerup)
		effects_container.add_child(display)
		active_effect_displays.append(display)

func _create_effect_display(powerup: ActivePowerup) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = ROW_MIN_SIZE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var stack_label := Label.new()
	stack_label.name = "StackLabel"
	hbox.add_child(stack_label)
	
	var timer_label := Label.new()
	timer_label.name = "TimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(timer_label)
	
	var card = powerup.powerup_card
	
	if card.icon_texture:
		icon.texture = card.icon_texture
	
	name_label.text = card.get_display_name()
	timer_label.text = _format_remaining_time(powerup.get_remaining_seconds())
	
	if powerup.stack_count > 1:
		stack_label.text = "x%d" % powerup.stack_count
		stack_label.visible = true
	else:
		stack_label.visible = false
	
	icon.modulate = card.rarity_color
	timer_label.modulate = card.rarity_color
	
	hbox.set_meta("powerup", powerup)
	return hbox

func _format_remaining_time(seconds: float) -> String:
	return "%.1fs" % maxf(seconds, 0.0)

func _update_effect_timers():
	for display in active_effect_displays:
		if not is_instance_valid(display):
			continue
		
		var powerup = display.get_meta("powerup")
		if not is_instance_valid(powerup):
			continue
		
		var timer_label: Label = display.get_node("TimerLabel")
		var percentage: float = powerup.get_remaining_time_percentage()
		
		timer_label.text = _format_remaining_time(powerup.get_remaining_seconds())
		
		var card = powerup.powerup_card
		if percentage < 0.25:
			timer_label.modulate = Color.RED
		elif percentage < 0.5:
			timer_label.modulate = Color.ORANGE
		else:
			timer_label.modulate = card.rarity_color

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
