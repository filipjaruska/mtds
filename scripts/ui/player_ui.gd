extends CanvasLayer

func _ready():
	EventManager.register(EventManager.Events.UI_HEALTH_UPDATED, self, "_on_health_updated")
	EventManager.register(EventManager.Events.UI_AMMO_UPDATED, self, "_on_ammo_updated")

# TODO: remove - kept for backwards compatibility 
func update_ammo(ammo: int, max_ammo: int):
	$AmmoDisplay.text = "%d / %d" % [ammo, max_ammo]
	
func update_health(hp: int, max_hp: int):
	$HealthDisplay.text = "%d / %d HP" % [hp, max_hp]

func _on_health_updated(hp: int, max_hp: int):
	update_health(hp, max_hp)

func _on_ammo_updated(ammo: int, max_ammo: int):
	update_ammo(ammo, max_ammo)

func _exit_tree():
	EventManager.unregister(EventManager.Events.UI_HEALTH_UPDATED, self, "_on_health_updated")
	EventManager.unregister(EventManager.Events.UI_AMMO_UPDATED, self, "_on_ammo_updated")
