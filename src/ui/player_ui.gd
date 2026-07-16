extends CanvasLayer

const SCOREBOARD_SCENE := preload("res://src/ui/menus/scoreboard.tscn")
const VALUE_PULSE_DURATION := 0.16

@onready var powerup_inventory_ui = $PowerupInventoryUI
@onready var active_powerups_ui = $ActivePowerupsUI
@onready var featured_card_label: Label = $FeaturedCard
@onready var time_label: Label = $Time
@onready var ammo_display: Label = $AmmoDisplay
@onready var health_display: Label = $HealthDisplay

var _player_node: Node = null
var _scoreboard: CanvasLayer = null
var _last_match_time: int = -1
var _featured_visible := false
var _value_tweens: Dictionary = {}
var _featured_tween: Tween = null

func _process(_delta: float):
	_update_match_time()
	_update_featured_card_label()
	if _player_node == null or not _player_node.is_multiplayer_authority():
		if _scoreboard:
			_scoreboard.visible = false
		return
	_ensure_scoreboard()
	var powerup_manager = _player_node.get_node_or_null("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	_update_scoreboard_visibility()

func _ready():
	_player_node = get_parent().get_parent().get_parent()
	EventManager.register(EventManager.Events.UI_HEALTH_UPDATED, _on_health_updated)
	EventManager.register(EventManager.Events.UI_AMMO_UPDATED, _on_ammo_updated)
	EventManager.register(EventManager.Events.POWERUP_COLLECTED, _on_powerup_collected)
	EventManager.register(EventManager.Events.POWERUP_USED, _on_powerup_used)
	EventManager.register(EventManager.Events.POWERUP_EXPIRED, _on_powerup_expired)
	EventManager.register(EventManager.Events.PLAYER_DIED, _on_player_died)
	if featured_card_label:
		featured_card_label.modulate.a = 0.0
		featured_card_label.visible = false
	_update_featured_card_label()

func _ensure_scoreboard() -> void:
	if _scoreboard != null and is_instance_valid(_scoreboard):
		return
	_scoreboard = SCOREBOARD_SCENE.instantiate()
	get_tree().root.add_child(_scoreboard)
	_scoreboard.visible = false

func _update_scoreboard_visibility() -> void:
	if _scoreboard == null:
		return
	var should_show := InputManager.is_scoreboard_held()
	_scoreboard.visible = should_show
	if should_show:
		_scoreboard.update_results(GameManager.get_sorted_match_results())

func _update_match_time() -> void:
	var remaining := int(GameManager.get_match_time_remaining())
	time_label.text = "%d" % remaining
	if _last_match_time >= 0 and remaining != _last_match_time:
		_pulse_control(time_label)
	_last_match_time = remaining

func update_ammo(ammo: int, max_ammo: int):
	ammo_display.text = "%d / %d" % [ammo, max_ammo]
	_pulse_control(ammo_display)

func update_ammo_dual(primary_ammo: int, primary_max: int, offhand_ammo: int, offhand_max: int):
	ammo_display.text = "%d / %d | %d / %d" % [primary_ammo, primary_max, offhand_ammo, offhand_max]
	_pulse_control(ammo_display)

func update_health(hp: int, max_hp: int):
	health_display.text = "%d / %d HP" % [hp, max_hp]
	_pulse_control(health_display)

func _pulse_control(control: Control) -> void:
	if _value_tweens.has(control):
		var existing: Tween = _value_tweens[control]
		if existing and existing.is_valid():
			existing.kill()
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "scale", Vector2(1.04, 1.04), VALUE_PULSE_DURATION * 0.4)
	tween.tween_property(control, "scale", Vector2.ONE, VALUE_PULSE_DURATION * 0.6)
	_value_tweens[control] = tween

func _on_health_updated(player_node: Node, hp: int, max_hp: int):
	if not player_node.is_multiplayer_authority():
		return
	update_health(hp, max_hp)

func _on_ammo_updated(player_node: Node, ammo: int, max_ammo: int, offhand_ammo: int = -1, offhand_max: int = -1):
	if not player_node.is_multiplayer_authority():
		return
	if offhand_ammo >= 0 and offhand_max >= 0:
		update_ammo_dual(ammo, max_ammo, offhand_ammo, offhand_max)
	else:
		update_ammo(ammo, max_ammo)

func _on_powerup_collected(player_node: Node, _powerup_card: BasePowerupCard, _slot: int):
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())

func _on_powerup_used(player_node: Node, _powerup_card: BasePowerupCard, slot: int):
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
		powerup_inventory_ui.highlight_slot(slot)

	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func _on_powerup_expired(player_node: Node, _powerup_card: BasePowerupCard) -> void:
	if not player_node.is_multiplayer_authority():
		return
	var powerup_manager = player_node.get_node_or_null("PowerupManager")
	if powerup_manager and active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func _on_player_died(player_node: Node) -> void:
	if not player_node.is_multiplayer_authority():
		return
	var powerup_manager = player_node.get_node_or_null("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	if powerup_manager and active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func update_powerup_displays(player_node: Node):
	var powerup_manager = player_node.get_node("PowerupManager")
	if not powerup_manager:
		return
	if powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func _update_featured_card_label() -> void:
	if not featured_card_label:
		return
	var featured_name: String = GameManager.get_poker_featured_card_display_name()
	var should_show_label: bool = GameManager.is_poker_mode() and not featured_name.is_empty()
	if should_show_label:
		featured_card_label.text = "4x %s" % featured_name
	_set_featured_visible(should_show_label)

func _set_featured_visible(should_show: bool) -> void:
	if _featured_visible == should_show:
		return
	_featured_visible = should_show
	if _featured_tween and _featured_tween.is_valid():
		_featured_tween.kill()
	if should_show:
		featured_card_label.visible = true
		featured_card_label.modulate.a = 0.0
		_featured_tween = create_tween()
		_featured_tween.tween_property(featured_card_label, "modulate:a", 1.0, 0.2)
	else:
		_featured_tween = create_tween()
		_featured_tween.tween_property(featured_card_label, "modulate:a", 0.0, 0.15)
		_featured_tween.tween_callback(func():
			if not _featured_visible:
				featured_card_label.visible = false
		)

func _exit_tree():
	if _scoreboard and is_instance_valid(_scoreboard):
		_scoreboard.queue_free()
		_scoreboard = null
	EventManager.unregister(EventManager.Events.UI_HEALTH_UPDATED, _on_health_updated)
	EventManager.unregister(EventManager.Events.UI_AMMO_UPDATED, _on_ammo_updated)
	EventManager.unregister(EventManager.Events.POWERUP_COLLECTED, _on_powerup_collected)
	EventManager.unregister(EventManager.Events.POWERUP_USED, _on_powerup_used)
	EventManager.unregister(EventManager.Events.POWERUP_EXPIRED, _on_powerup_expired)
	EventManager.unregister(EventManager.Events.PLAYER_DIED, _on_player_died)
