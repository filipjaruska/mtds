extends CanvasLayer

const SCOREBOARD_SCENE := preload("res://src/ui/menus/scoreboard.tscn")
const VALUE_PULSE_DURATION := 0.16

@onready var powerup_inventory_ui: PowerupHandUI = $PowerupHandUI
@onready var active_powerups_ui = $ActivePowerupsUI
@onready var time_label: Label = %Time
@onready var ammo_display: Label = %AmmoDisplay
@onready var health_display: Label = %HealthDisplay
@onready var weapon_slots = %WeaponSlots

var _player_node: Node = null
## "No fighting here" while the player stands in a PeaceZone.
var _peace_hint: Label
var _scoreboard: CanvasLayer = null
var _last_match_time: int = -1
var _value_tweens: Dictionary = {}

func _process(_delta: float):
	_update_match_time()
	if _player_node == null or not _player_node.is_multiplayer_authority():
		if _scoreboard:
			_scoreboard.visible = false
		return
	_ensure_scoreboard()
	_peace_hint.visible = PeaceZone.covers(_player_node)
	var powerup_manager = _player_node.get_node_or_null("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	if powerup_manager and active_powerups_ui:
		var effects = _player_node.get_node_or_null("CardEffects")
		var shield = effects.get_shield() if effects else null
		active_powerups_ui.shield_fraction = shield.hp_fraction() if shield else -1.0
		active_powerups_ui.update_active_powerups(powerup_manager.active)
	_update_scoreboard_visibility()

func _ready():
	_player_node = get_parent().get_parent().get_parent()
	_peace_hint = UiPalette.label("No fighting here", UiPalette.M, UiPalette.WARN)
	_peace_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_peace_hint.offset_top = -250
	_peace_hint.offset_bottom = -220
	_peace_hint.offset_left = -200
	_peace_hint.offset_right = 200
	_peace_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peace_hint.visible = false
	add_child(_peace_hint)
	EventManager.health_changed.connect(_on_health_updated)
	EventManager.ammo_changed.connect(_on_ammo_updated)
	EventManager.weapon_slots_changed.connect(_on_weapon_slots_updated)
	EventManager.powerup_collected.connect(_on_powerup_collected)
	EventManager.powerup_used.connect(_on_powerup_used)
	EventManager.powerup_expired.connect(_on_powerup_expired)
	EventManager.player_died.connect(_on_player_died)

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
	time_label.text = "%d:%02d" % [remaining / 60, remaining % 60]
	if _last_match_time >= 0 and remaining != _last_match_time:
		_pulse_control(time_label)
	_last_match_time = remaining

## Only what is left counts; the maximum is never shown. Melee weapons report
## -1 (nothing to count); an empty gun turns the number red.
func update_ammo(ammo: int, max_ammo: int):
	ammo_display.text = str(ammo) if max_ammo >= 0 else "—"
	_tint(ammo_display, UiPalette.BAD if max_ammo > 0 and ammo == 0 else UiPalette.TEXT)
	_pulse_control(ammo_display)

func update_ammo_dual(primary_ammo: int, _primary_max: int, offhand_ammo: int, _offhand_max: int):
	ammo_display.text = "%d | %d" % [primary_ammo, offhand_ammo]
	_tint(ammo_display, UiPalette.TEXT)
	_pulse_control(ammo_display)

func update_health(hp: int, max_hp: int):
	health_display.text = str(hp)
	var fraction := float(hp) / maxf(max_hp, 1.0)
	_tint(health_display, UiPalette.TEXT if fraction > 0.5 else (UiPalette.WARN if fraction > 0.25 else UiPalette.BAD))
	_pulse_control(health_display)

func _tint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)

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

func _on_weapon_slots_updated(player_node: Node, slot_names: Array, active: int) -> void:
	if player_node != _player_node or not player_node.is_multiplayer_authority():
		return
	weapon_slots.show_slots(slot_names, active)

func _on_powerup_collected(player_node: Node, _powerup_card: PowerupDef, _slot: int):
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())

func _on_powerup_used(player_node: Node, _powerup_card: PowerupDef, slot: int):
	if player_node != _player_node:
		return
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		# Play first: the card must still be in the hand when its copy takes off.
		powerup_inventory_ui.play_card(slot)
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())

	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active)

func _on_powerup_expired(player_node: Node, _powerup_card: PowerupDef) -> void:
	if not player_node.is_multiplayer_authority():
		return
	var powerup_manager = player_node.get_node_or_null("PowerupManager")
	if powerup_manager and active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active)

func _on_player_died(player_node: Node) -> void:
	if not player_node.is_multiplayer_authority():
		return
	var powerup_manager = player_node.get_node_or_null("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	if powerup_manager and active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active)

func update_powerup_displays(player_node: Node):
	var powerup_manager = player_node.get_node("PowerupManager")
	if not powerup_manager:
		return
	if powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.get_inventory_display_data())
	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active)

func _exit_tree():
	if _scoreboard and is_instance_valid(_scoreboard):
		_scoreboard.queue_free()
		_scoreboard = null
	if EventManager.health_changed.is_connected(_on_health_updated): EventManager.health_changed.disconnect(_on_health_updated)
	if EventManager.ammo_changed.is_connected(_on_ammo_updated): EventManager.ammo_changed.disconnect(_on_ammo_updated)
	if EventManager.weapon_slots_changed.is_connected(_on_weapon_slots_updated): EventManager.weapon_slots_changed.disconnect(_on_weapon_slots_updated)
	if EventManager.powerup_collected.is_connected(_on_powerup_collected): EventManager.powerup_collected.disconnect(_on_powerup_collected)
	if EventManager.powerup_used.is_connected(_on_powerup_used): EventManager.powerup_used.disconnect(_on_powerup_used)
	if EventManager.powerup_expired.is_connected(_on_powerup_expired): EventManager.powerup_expired.disconnect(_on_powerup_expired)
	if EventManager.player_died.is_connected(_on_player_died): EventManager.player_died.disconnect(_on_player_died)
