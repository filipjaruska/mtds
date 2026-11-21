extends Node
class_name CombatServer
## Host-authoritative shooting. The map adds one of these as "Combat" on every
## peer, so its RPCs resolve everywhere.
##
## Shooter: draws predicted tracers immediately and asks the host to resolve.
## Host:    validates the request against its own mirror of the shooter,
##          raycasts, applies damage and shows the real tracers to everyone else.
## Raycasts run in _physics_process, where the physics space may be queried.

const HITBOX_LAYER := 2 # physics layer 2 "hitboxes"
const WALL_LAYER := 4 # physics layer 3 "walls" (map TileSets use this)
const SHIELD_LAYER := RiotShield.SHIELD_LAYER # physics layer 4 "shields"
## How far a shot may start from where the host sees the shooter.
const MAX_ORIGIN_DISTANCE := 150.0
## Anti-spam budget per player: trigger pulls accepted within one second.
## Dual-wielded bursts fire both hands at 18/s each, so stay well above 36.
const MAX_SHOTS_PER_SECOND := 50
## A slow frame can fire several burst shots in one request.
const MAX_SHOTS_PER_REQUEST := 4

var _pending: Array[Dictionary] = []
var _recent_shots: Dictionary = {} # peer id -> Array of msec timestamps
var _last_swing: Dictionary = {} # peer id -> msec of their last accepted melee swing

## Called on the shooting player's machine for every trigger pull.
func fire(shooter: Node2D, origin: Vector2, rotations: PackedFloat32Array, def_id: StringName, max_range: float) -> void:
	_pending.append({"kind": &"predict", "shooter": shooter, "origin": origin, "rotations": rotations, "range": max_range, "def": def_id})
	if multiplayer.is_server():
		_queue_resolve(multiplayer.get_unique_id(), origin, rotations, def_id)
	else:
		request_fire.rpc_id(1, origin, rotations, def_id)

@rpc("any_peer", "reliable")
func request_fire(origin: Vector2, rotations: PackedFloat32Array, def_id: StringName) -> void:
	if multiplayer.is_server():
		_queue_resolve(multiplayer.get_remote_sender_id(), origin, rotations, def_id)

func _queue_resolve(shooter_id: int, origin: Vector2, rotations: PackedFloat32Array, def_id: StringName) -> void:
	_pending.append({"kind": &"resolve", "shooter_id": shooter_id, "origin": origin, "rotations": rotations, "def": def_id})

func _physics_process(_delta: float) -> void:
	var batch := _pending
	_pending = []
	for item in batch:
		if item.kind == &"predict":
			_predict(item)
		else:
			_resolve(item)

func _predict(item: Dictionary) -> void:
	var shooter: Node2D = item.shooter
	if not is_instance_valid(shooter):
		return
	var space := shooter.get_world_2d().direct_space_state
	var exclude := _exclude_for(shooter)
	var holder: WeaponHolder = shooter.get_weapon_holder()
	if WeaponDefs.has(item.def) and WeaponDefs.get_def(item.def).melee:
		return # a blade has no bullet; the swing is drawn by its WeaponView
	var pierce: int = holder.stats_for(item.def).pierce if holder and WeaponDefs.has(item.def) else 0
	for rot in item.rotations:
		var hit := cast_piercing(space, item.origin, rot, item.range, exclude, pierce)
		BulletFx.spawn(get_parent(), item.origin, hit.end, hit.impact)

func _resolve(item: Dictionary) -> void:
	var shooter_id: int = item.shooter_id
	var shooter := _find_player(shooter_id)
	if shooter == null:
		return
	var holder: WeaponHolder = shooter.get_weapon_holder()
	var health: HealthComponent = shooter.get_health_component()
	var def := WeaponDefs.get_def(item.def)
	if holder == null or health == null or health.is_dead or def == null:
		return
	var shot_count := ceili(item.rotations.size() / float(def.pellets))
	if not holder.has_weapon(def.id) or item.rotations.is_empty() or shot_count > MAX_SHOTS_PER_REQUEST:
		return
	if not _within_budget(shooter_id, shot_count, Time.get_ticks_msec()):
		return

	var origin: Vector2 = item.origin
	if origin.distance_to(shooter.global_position) > MAX_ORIGIN_DISTANCE:
		origin = shooter.global_position
	# Damage comes from the host's view of the shooter's modifiers, not the request.
	var stats := holder.stats_for(def.id)
	var space := shooter.get_world_2d().direct_space_state
	var exclude := _exclude_for(shooter)
	if stats.melee:
		_resolve_swing(shooter, shooter_id, item.rotations[0], stats, space, exclude)
		return
	var ends := PackedVector2Array()
	var impacts := PackedByteArray()
	for rot in item.rotations:
		var hit := cast_piercing(space, origin, rot, stats.max_range, exclude, stats.pierce)
		ends.append(hit.end)
		impacts.append(hit.impact)
		for victim in hit.healths:
			victim.apply_damage(stats.damage, stats.armor_penetration, shooter_id)
		if hit.shield:
			hit.shield.take_hit(stats.damage)

	for peer in multiplayer.get_peers():
		if peer != shooter_id:
			_show_tracers.rpc_id(peer, origin, ends, impacts)
	if shooter_id != multiplayer.get_unique_id():
		_spawn_tracers(origin, ends, impacts)

## Melee: the closest enemy in the arc takes the hit, unless a wall or riot
## shield is in between (a shield takes the hit instead).
func _resolve_swing(shooter: Node2D, shooter_id: int, aim: float, stats: Dictionary,
		space: PhysicsDirectSpaceState2D, exclude: Array[RID]) -> void:
	var now := Time.get_ticks_msec()
	var interval := WeaponRules.interval_msec(stats.fire_rate)
	if now - int(_last_swing.get(shooter_id, -interval)) < interval * 0.8:
		return # faster than the blade can swing
	_last_swing[shooter_id] = now
	var origin := shooter.global_position
	var candidates: Array = []
	for player in get_tree().get_nodes_in_group("Player"):
		var id: int = player.get_multiplayer_authority()
		var health = player.get_node_or_null("HealthComponent")
		if player == shooter or health == null or health.is_dead or GameManager.are_teammates(shooter_id, id):
			continue
		candidates.append({"id": id, "position": player.global_position, "health": health})
	var target_id := WeaponRules.melee_target(origin, aim, stats.max_range, stats.arc_degrees, candidates)
	if target_id < 0:
		return
	var target: Dictionary = candidates.filter(func(c): return c.id == target_id)[0]
	var query := PhysicsRayQueryParameters2D.create(origin, target.position, WALL_LAYER | SHIELD_LAYER, exclude)
	query.collide_with_bodies = true
	var blocked := space.intersect_ray(query)
	var dir: Vector2 = (target.position - origin).normalized()
	if blocked.is_empty():
		target.health.apply_damage(stats.damage, stats.armor_penetration, shooter_id)
		_show_slash_hit.rpc(target.position - dir * 18.0, dir, BulletFx.Impact.PLAYER)
	elif blocked.collider is RiotShield:
		blocked.collider.take_hit(stats.damage)
		_show_slash_hit.rpc(blocked.position, dir, BulletFx.Impact.SHIELD)

@rpc("authority", "call_local", "unreliable")
func _show_slash_hit(at: Vector2, dir: Vector2, impact: int) -> void:
	ImpactFx.play(get_parent(), at, dir, impact)

func _within_budget(shooter_id: int, shot_count: int, now: int) -> bool:
	var result := DamageRules.fire_budget(_recent_shots.get(shooter_id, []), shot_count, now, MAX_SHOTS_PER_SECOND)
	_recent_shots[shooter_id] = result.recent
	return result.allowed

@rpc("authority", "call_remote", "unreliable")
func _show_tracers(origin: Vector2, ends: PackedVector2Array, impacts: PackedByteArray) -> void:
	_spawn_tracers(origin, ends, impacts)

func _spawn_tracers(origin: Vector2, ends: PackedVector2Array, impacts: PackedByteArray) -> void:
	for i in range(ends.size()):
		BulletFx.spawn(get_parent(), origin, ends[i], impacts[i] if i < impacts.size() else BulletFx.Impact.NONE)

## Returns {end: Vector2, health: HealthComponent or null, shield: RiotShield or null}.
static func cast_shot(space: PhysicsDirectSpaceState2D, origin: Vector2, rotation: float, max_range: float, exclude: Array[RID]) -> Dictionary:
	var hit := cast_piercing(space, origin, rotation, max_range, exclude, 0)
	return {"end": hit.end, "health": hit.healths[0] if not hit.healths.is_empty() else null, "shield": hit.shield}

## One shot that passes through up to `pierce` players and stops at the next
## player, a wall or a riot shield.
## Returns {end: Vector2, healths: Array (players hit, nearest first),
## shield: RiotShield or null, impact: BulletFx.Impact (what stopped the shot)}.
static func cast_piercing(space: PhysicsDirectSpaceState2D, origin: Vector2, rotation: float, max_range: float, exclude: Array[RID], pierce: int) -> Dictionary:
	var to := origin + Vector2.RIGHT.rotated(rotation) * max_range
	var skip: Array[RID] = exclude.duplicate()
	var healths: Array = []
	while true:
		var query := PhysicsRayQueryParameters2D.create(origin, to, HITBOX_LAYER | WALL_LAYER | SHIELD_LAYER, skip)
		query.collide_with_areas = true
		# Walls and shields are bodies; player bodies sit on layer 1, which is not in the mask.
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {"end": to, "healths": healths, "shield": null, "impact": BulletFx.Impact.NONE}
		var collider: Object = hit.collider
		if collider is Area2D:
			var health := collider.get_parent() as HealthComponent if collider.is_in_group("hitbox") else null
			if health and not healths.has(health):
				healths.append(health)
				if healths.size() > pierce:
					return {"end": hit.position, "healths": healths, "shield": null, "impact": BulletFx.Impact.PLAYER}
			skip.append(hit.rid)
			continue
		var shield := collider as RiotShield
		return {"end": hit.position, "healths": healths, "shield": shield,
			"impact": BulletFx.Impact.SHIELD if shield else BulletFx.Impact.WALL}
	return {} # unreachable

## Shots pass through the shooter and their own riot shield and, in team
## matches, through teammates and their shields.
func _exclude_for(shooter: Node) -> Array[RID]:
	var exclude: Array[RID] = []
	var shooter_id := shooter.get_multiplayer_authority()
	for player in get_tree().get_nodes_in_group("Player"):
		var player_id: int = player.get_multiplayer_authority()
		if player != shooter and not GameManager.are_teammates(shooter_id, player_id):
			continue
		var hitbox := player.get_node_or_null("HealthComponent/PlayerHitbox") as Area2D
		if hitbox:
			exclude.append(hitbox.get_rid())
		var shield := player.get_node_or_null("PlayerController/RiotShield") as RiotShield
		if shield:
			exclude.append(shield.get_rid())
	return exclude

func _find_player(peer_id: int) -> Node2D:
	return get_parent().get_node_or_null(str(peer_id)) as Node2D
