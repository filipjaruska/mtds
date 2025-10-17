extends Node
class_name PowerupFactory

static func create_speed_boost() -> SpeedBoostCard:
	return SpeedBoostCard.new()

static func create_damage_boost() -> DamageBoostCard:
	return DamageBoostCard.new()

static func create_health_boost() -> HealthBoostCard:
	return HealthBoostCard.new()

static func create_reload_speed() -> ReloadSpeedCard:
	return ReloadSpeedCard.new()

static func create_fire_rate() -> FireRateCard:
	return FireRateCard.new()

static func create_armor() -> ArmorCard:
	return ArmorCard.new()

static func create_random_powerup() -> BasePowerupCard:
	var powerup_types = [
		create_speed_boost,
		create_damage_boost,
		create_health_boost,
		create_reload_speed,
		create_fire_rate,
		create_armor
	]
	var random_type = powerup_types[randi() % powerup_types.size()]
	return random_type.call()

static func spawn_random_powerup_pickup(position: Vector2) -> PowerupPickup:
	var card = create_random_powerup()
	return PowerupPickup.create_pickup(card, position)
