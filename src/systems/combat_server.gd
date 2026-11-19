extends Node
class_name CombatServer
## Host-authoritative shooting. The map adds one of these as "Combat" on every
## peer, so its RPCs resolve everywhere.
##
## Shooter: draws predicted tracers immediately and asks the host to resolve.
## Host:    validates the request against its own mirror of the shooter,
##          raycasts, applies damage and shows the real tracers to everyone else.
## Raycasts run in _physics_process, where the physics space may be queried.

const HITBOX_MASK := 2
## How far a shot may start from where the host sees the shooter.
const MAX_ORIGIN_DISTANCE := 150.0
## Hard cap on fire requests per player (~33/s, above the fastest burst).
const MIN_REQUEST_INTERVAL_MSEC := 30

var _pending: Array[Dictionary] = []
var _last_request_at: Dictionary = {}

## Called on the shooting player's machine for every trigger pull.
func fire(shooter: Node2D, origin: Vector2, rotations: PackedFloat32Array, def_id: StringName, max_range: float) -> void:
	_pending.append({"kind": &"predict", "shooter": shooter, "origin": origin, "rotations": rotations, "range": max_range})
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
	for rot in item.rotations:
		Tracer.spawn(get_parent(), item.origin, cast_shot(space, item.origin, rot, item.range, exclude).end)

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
	if not holder.has_weapon(def.id) or item.rotations.size() > def.pellets:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_request_at.get(shooter_id, -100000)) < MIN_REQUEST_INTERVAL_MSEC:
		return
	_last_request_at[shooter_id] = now

	var origin: Vector2 = item.origin
	if origin.distance_to(shooter.global_position) > MAX_ORIGIN_DISTANCE:
		origin = shooter.global_position
	# Damage comes from the host's view of the shooter's modifiers, not the request.
	var stats := holder.stats_for(def.id)
	var space := shooter.get_world_2d().direct_space_state
	var exclude := _exclude_for(shooter)
	var ends := PackedVector2Array()
	for rot in item.rotations:
		var hit := cast_shot(space, origin, rot, stats.max_range, exclude)
		ends.append(hit.end)
		if hit.health:
			hit.health.apply_damage(stats.damage, stats.armor_penetration, shooter_id)

	for peer in multiplayer.get_peers():
		if peer != shooter_id:
			_show_tracers.rpc_id(peer, origin, ends)
	if shooter_id != multiplayer.get_unique_id():
		_spawn_tracers(origin, ends)

@rpc("authority", "call_remote", "unreliable")
func _show_tracers(origin: Vector2, ends: PackedVector2Array) -> void:
	_spawn_tracers(origin, ends)

func _spawn_tracers(origin: Vector2, ends: PackedVector2Array) -> void:
	for end in ends:
		Tracer.spawn(get_parent(), origin, end)

## Returns {end: Vector2, health: HealthComponent or null}.
static func cast_shot(space: PhysicsDirectSpaceState2D, origin: Vector2, rotation: float, max_range: float, exclude: Array[RID]) -> Dictionary:
	var to := origin + Vector2.RIGHT.rotated(rotation) * max_range
	var query := PhysicsRayQueryParameters2D.create(origin, to, HITBOX_MASK, exclude)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"end": to, "health": null}
	var collider: Object = hit.collider
	var health: HealthComponent = null
	if collider is Area2D and collider.is_in_group("hitbox"):
		health = collider.get_parent() as HealthComponent
	return {"end": hit.position, "health": health}

func _exclude_for(shooter: Node) -> Array[RID]:
	var exclude: Array[RID] = []
	var hitbox := shooter.get_node_or_null("HealthComponent/PlayerHitbox") as Area2D
	if hitbox:
		exclude.append(hitbox.get_rid())
	return exclude

func _find_player(peer_id: int) -> Node2D:
	return get_parent().get_node_or_null(str(peer_id)) as Node2D
