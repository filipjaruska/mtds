extends RayCast2D

var _bullet_damage: float
var _bullet_armor_penetration: float
var _visual_range: float

func set_bullet_damage(damage: float, penetration: float) -> void:
	_bullet_damage = damage
	_bullet_armor_penetration = penetration

func set_visual_range(weapon_range: float) -> void:
	_visual_range = weapon_range
	$Line2D.points[1] = Vector2(weapon_range, 0)

func _ready() -> void:
	enabled = true
	collide_with_areas = true
	collide_with_bodies = false
	
	await get_tree().process_frame
	force_raycast_update()
	check_collision()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()

func check_collision() -> void:
	if is_colliding():
		var collision_point = get_collision_point()
		var distance_to_hit = global_position.distance_to(collision_point)
		
		if distance_to_hit <= target_position.length():
			$Line2D.points[1] = to_local(collision_point)
			var collider = get_collider()
			if collider is Area2D and collider.is_in_group("hitbox"):
				var health_component = collider.get_parent()
				if health_component and health_component.has_method("damage"):
					health_component.damage(_bullet_damage, _bullet_armor_penetration)