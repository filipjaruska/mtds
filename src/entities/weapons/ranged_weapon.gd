extends Node2D
class_name RangedWeapon
@export var resource_path: String
@export var fire_rate: float = 1.0 # shots per second
@export var accuracy: float = 100.0 # accuracy percentage in %
@export var max_range: float = 500.0 # range in pixels
@export var damage: float = 10.0 # damage per shot
@export var armor_penetration: float = 0.0 # armor penetration
@export var max_ammo: int = 10 # maximum ammunition
@export var ammo: int = 10 # current ammunition
@export var pellets: int = 1 # number of pellets per shot
@export var reload_time: float = 2.0 # reload time in seconds
@export var slowness: float = 20.0 # slowness effect
@export var slowness_duration: float = 300.0 # duration in milliseconds
@export var shooting_animation: String # name of the shooting animation
@export var idle_animation: String # name of the idle animation
@export var muzzle: Marker2D # muzzle position
@export var sprite: Sprite2D # weapon sprite

@onready var muzzle_flash = preload("res://src/entities/weapons/muzzle_flash.tscn")
@export var animation_player: AnimationPlayer

var last_shot_time: float = 0.0
var is_reloading: bool = false
var _burst_in_progress: bool = false

func get_display_name() -> String:
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().capitalize()
	return name

func _ready():
	last_shot_time = Time.get_ticks_msec()
	animation_player.play(idle_animation)

func shoot() -> bool:
	return shoot_with_spread_penalty(0.0)

func shoot_with_spread_penalty(spread_penalty: float) -> bool:
	if _burst_in_progress or is_reloading:
		return false
	if Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate and ammo > 0:
		_fire_shot(-1.0, spread_penalty)
		return true
	return false

func burst_fire(spread_degrees: float, shots_per_second: float = 18.0) -> void:
	if _burst_in_progress or is_reloading or ammo <= 0:
		return
	_burst_fire_async(spread_degrees, shots_per_second)

func _fire_shot(spread_degrees: float, spread_penalty: float = 0.0) -> void:
	animation_player.play(shooting_animation)
	_shoot_bullet(spread_degrees, spread_penalty)
	last_shot_time = Time.get_ticks_msec()
	ammo -= 1
	show_muzzle_flash()
	
	EventManager.emit_event(EventManager.Events.WEAPON_FIRED, [self, ammo, max_ammo])
	EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [get_parent(), ammo, max_ammo, -1, -1])

func _burst_fire_async(spread_degrees: float, shots_per_second: float) -> void:
	_burst_in_progress = true
	var interval := 1.0 / maxf(shots_per_second, 1.0)
	
	while ammo > 0:
		_fire_shot(spread_degrees)
		if ammo <= 0:
			break
		await get_tree().create_timer(interval).timeout
	
	_burst_in_progress = false

func _shoot_bullet(spread_degrees: float = -1.0, spread_penalty: float = 0.0):
	var weapon_manager := _resolve_weapon_manager()
	if weapon_manager == null:
		return
	var deviation: float
	if spread_degrees >= 0.0:
		deviation = deg_to_rad(spread_degrees)
	else:
		deviation = (1.0 - accuracy / 100.0) * 0.5
	deviation *= (1.0 + spread_penalty)
	
	for i in range(pellets):
		var spawn_pos = muzzle.global_position
		var shot_rotation = global_rotation + randf_range(-deviation, deviation)
		weapon_manager.rpc("spawn_bullet", spawn_pos, shot_rotation, max_range, damage, armor_penetration, multiplayer.get_unique_id())

func _resolve_weapon_manager() -> Node2D:
	var parent_node := get_parent()
	if parent_node != null and parent_node.get("weapons") != null:
		return parent_node
	if parent_node != null and parent_node.has_node("WeaponManager"):
		return parent_node.get_node("WeaponManager")
	return parent_node

func reload():
	if is_reloading:
		return
		
	is_reloading = true
	
	# Emit reload started event
	EventManager.emit_event(EventManager.Events.WEAPON_RELOADED, [self, true, reload_time])
	
	await get_tree().create_timer(reload_time).timeout
	
	ammo = max_ammo
	is_reloading = false
	
	# Emit reload completed event
	EventManager.emit_event(EventManager.Events.WEAPON_RELOADED, [self, false, 0.0])
	EventManager.emit_event(EventManager.Events.UI_AMMO_UPDATED, [get_parent(), ammo, max_ammo, -1, -1])

func show_muzzle_flash():
	var muzzle_flash_instance = muzzle_flash.instantiate()
	muzzle_flash_instance.global_position = muzzle.global_position
	muzzle_flash_instance.global_rotation = global_rotation
	add_child(muzzle_flash_instance)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == shooting_animation:
		animation_player.play(idle_animation)
