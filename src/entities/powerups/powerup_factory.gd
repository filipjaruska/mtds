extends Node
class_name PowerupFactory

const BurstCardScript := preload("res://src/entities/powerups/cards/burst_card.gd")
const DualWieldCardScript := preload("res://src/entities/powerups/cards/dual_wield_card.gd")
const FasterDashCardScript := preload("res://src/entities/powerups/cards/faster_dash_card.gd")

static func create_faster_dash() -> BasePowerupCard:
	return FasterDashCardScript.new()

static func create_damage_boost() -> DamageBoostCard:
	return DamageBoostCard.new()

static func create_health_boost() -> HealthBoostCard:
	return HealthBoostCard.new()

static func create_reload_speed() -> ReloadSpeedCard:
	return ReloadSpeedCard.new()

static func create_burst() -> BasePowerupCard:
	return BurstCardScript.new()

static func create_armor() -> ArmorCard:
	return ArmorCard.new()

static func create_dual_wield() -> BasePowerupCard:
	return DualWieldCardScript.new()

static func create_random_powerup() -> BasePowerupCard:
	var powerup_types = [
		create_faster_dash,
		create_damage_boost,
		create_health_boost,
		create_reload_speed,
		create_burst,
		create_armor,
		create_dual_wield
	]
	var random_type = powerup_types[randi() % powerup_types.size()]
	return random_type.call()

static func spawn_random_powerup_pickup(position: Vector2) -> PowerupPickup:
	var card = create_random_powerup()
	return PowerupPickup.create_pickup(card, position)
