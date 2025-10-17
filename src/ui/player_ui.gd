extends CanvasLayer

@onready var powerup_inventory_ui = $PowerupInventoryUI
@onready var active_powerups_ui = $ActivePowerupsUI

func _ready():
	EventManager.register(EventManager.Events.UI_HEALTH_UPDATED, self, "_on_health_updated")
	EventManager.register(EventManager.Events.UI_AMMO_UPDATED, self, "_on_ammo_updated")
	EventManager.register(EventManager.Events.POWERUP_COLLECTED, self, "_on_powerup_collected")
	EventManager.register(EventManager.Events.POWERUP_USED, self, "_on_powerup_used")

func update_ammo(ammo: int, max_ammo: int):
	$AmmoDisplay.text = "%d / %d" % [ammo, max_ammo]
	
func update_health(hp: int, max_hp: int):
	$HealthDisplay.text = "%d / %d HP" % [hp, max_hp]

func _on_health_updated(hp: int, max_hp: int):
	update_health(hp, max_hp)

func _on_ammo_updated(ammo: int, max_ammo: int):
	update_ammo(ammo, max_ammo)

func _on_powerup_collected(player_node: Node, _powerup_card: BasePowerupCard, _slot: int):
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.powerup_inventory)

func _on_powerup_used(player_node: Node, _powerup_card: BasePowerupCard, slot: int):
	var powerup_manager = player_node.get_node("PowerupManager")
	if powerup_manager and powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.powerup_inventory)
		powerup_inventory_ui.highlight_slot(slot)
	
	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func update_powerup_displays(player_node: Node):
	var powerup_manager = player_node.get_node("PowerupManager")
	if not powerup_manager:
		return
	
	if powerup_inventory_ui:
		powerup_inventory_ui.update_inventory(powerup_manager.powerup_inventory)
	
	if active_powerups_ui:
		active_powerups_ui.update_active_powerups(powerup_manager.active_powerups)

func _exit_tree():
	EventManager.unregister(EventManager.Events.UI_HEALTH_UPDATED, self, "_on_health_updated")
	EventManager.unregister(EventManager.Events.UI_AMMO_UPDATED, self, "_on_ammo_updated")
	EventManager.unregister(EventManager.Events.POWERUP_COLLECTED, self, "_on_powerup_collected")
	EventManager.unregister(EventManager.Events.POWERUP_USED, self, "_on_powerup_used")
