extends Node2D
class_name WeaponView
## The visual side of a weapon: sprite, animations and muzzle flash. It holds no
## stats and makes no decisions; WeaponHolder tells it when to play effects.
## Stats live in a WeaponDef (res://src/entities/weapons/defs/).

const MUZZLE_FLASH_SCENE := preload("res://src/entities/weapons/muzzle_flash.tscn")

@export var muzzle: Marker2D
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var shooting_animation: String = "Shooting"
@export var idle_animation: String = "Idle"

func _ready() -> void:
	_play_idle()

func play_fire() -> void:
	if animation_player and not shooting_animation.is_empty():
		animation_player.stop()
		animation_player.play(shooting_animation)
	if muzzle:
		# Place the flash before adding it: the particles start emitting as soon
		# as it enters the tree, from wherever it is at that moment. It is
		# top_level, so its position/rotation are global once added.
		var flash: Node2D = MUZZLE_FLASH_SCENE.instantiate()
		flash.position = muzzle.global_position
		flash.rotation = global_rotation
		add_child(flash)

func muzzle_position() -> Vector2:
	return muzzle.global_position if muzzle else global_position

## Local offset of the art inside the scene; used to center dual-wielded guns.
func sprite_offset() -> Vector2:
	return sprite.position if sprite else Vector2.ZERO

func _play_idle() -> void:
	if animation_player and not idle_animation.is_empty():
		animation_player.play(idle_animation)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == shooting_animation:
		_play_idle()
