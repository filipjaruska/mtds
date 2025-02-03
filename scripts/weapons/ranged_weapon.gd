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
@export var muzzle = Marker2D # muzzle position
@export var sprite = Sprite2D # weapon sprite

@onready var bullet_scene = preload("res://nodes/weapons/bullet.tscn")
@onready var muzzle_flash = preload("res://nodes/weapons/muzzle_flash.tscn") 
@export var animation_player: AnimationPlayer

var last_shot_time: float = 0.0
var is_reloading: bool = false

func _ready():
	last_shot_time = Time.get_ticks_msec()
	animation_player.play(idle_animation)

func shoot():
	if not is_reloading and Time.get_ticks_msec() - last_shot_time >= 1000 / fire_rate:
		if ammo > 0:
			animation_player.play(shooting_animation)
			_shoot_bullet()
			last_shot_time = Time.get_ticks_msec()
			ammo -= 1
			show_muzzle_flash()

func _shoot_bullet():
	for i in range(pellets):
		if bullet_scene:
			var spawn_pos = muzzle.global_position
			var deviation = (1.0 - accuracy / 100.0) * 0.5
			var shot_rotation = global_rotation + randf() * deviation - deviation / 2
			
			spawn_bullet.rpc(spawn_pos, shot_rotation, max_range, damage, armor_penetration)

@rpc("any_peer", "call_local")
func spawn_bullet(pos: Vector2, rot: float, weapon_range: float, dmg: float, pen: float):
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	bullet.global_position = pos
	bullet.global_rotation = rot
	bullet.target_position = Vector2(weapon_range, 0)
	bullet.set_visual_range(weapon_range)
	bullet.set_bullet_damage(dmg, pen)
	bullet.force_raycast_update()

func reload():
	if is_reloading:
		return
	is_reloading = true
	await get_tree().create_timer(reload_time).timeout
	ammo = max_ammo
	is_reloading = false

func show_muzzle_flash():
	var muzzle_flash_instance = muzzle_flash.instantiate()
	muzzle_flash_instance.global_position = muzzle.global_position
	muzzle_flash_instance.rotation = get_parent().get_parent().rotation
	add_child(muzzle_flash_instance)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == shooting_animation:
		animation_player.play(idle_animation)
