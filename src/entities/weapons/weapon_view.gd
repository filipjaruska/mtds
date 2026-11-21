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
@export_group("Melee swing")
## Melee weapons: the blade sweeps through this arc instead of firing (0 = gun).
@export var swing_degrees: float = 0.0
## Radius of the slash trail around the player.
@export var slash_radius: float = 70.0
@export_group("Shell casing")
## Ejected to the side of the gun on every shot; size (0, 0) = none.
@export var casing_size: Vector2 = Vector2(5, 2)
@export var casing_color: Color = Color(0.85, 0.66, 0.25)
## Where it leaves the gun, in this node's local space (behind the muzzle).
@export var casing_port: Vector2 = Vector2(4, 0)

func _ready() -> void:
	_play_idle()

func play_fire() -> void:
	if swing_degrees > 0.0:
		_swing()
		return
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
	_eject_casing()

## Melee: the blade sweeps across the arc and back, leaving a slash trail.
func _swing() -> void:
	var half := deg_to_rad(swing_degrees) * 0.5
	var tween := create_tween()
	tween.tween_property(self, "rotation", -half, 0.04)
	tween.tween_property(self, "rotation", half, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slash_trail(half)

func _slash_trail(half: float) -> void:
	var holder := get_parent() as Node2D
	var center: Vector2 = holder.get_parent().global_position if holder and holder.get_parent() is Node2D else global_position
	var aim := holder.global_rotation if holder else global_rotation
	var trail := Line2D.new()
	trail.top_level = true
	trail.z_as_relative = false
	trail.z_index = 6
	trail.width = 9.0
	var points := PackedVector2Array()
	for i in range(13):
		var a := aim - half + 2.0 * half * i / 12.0
		points.append(center + Vector2.RIGHT.rotated(a) * slash_radius)
	trail.points = points
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.9))
	trail.gradient = fade
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.1))
	taper.add_point(Vector2(0.75, 1.0))
	taper.add_point(Vector2(1.0, 0.3))
	trail.width_curve = taper
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = additive
	add_child(trail)
	var tween := trail.create_tween().set_parallel()
	tween.tween_property(trail, "modulate:a", 0.0, 0.22).set_delay(0.06)
	tween.tween_property(trail, "width", 3.0, 0.28)
	tween.chain().tween_callback(trail.queue_free)

## A spent casing flips out to the side, skids to a stop and fades away.
func _eject_casing() -> void:
	if casing_size == Vector2.ZERO:
		return
	var casing := Polygon2D.new()
	var half := casing_size * 0.5
	casing.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	casing.color = casing_color
	casing.top_level = true
	casing.z_as_relative = false
	casing.z_index = 1
	casing.position = to_global(casing_port)
	casing.rotation = global_rotation
	add_child(casing)
	# Out to the gun's right side and a little backwards, with some randomness.
	var aim := Vector2.RIGHT.rotated(global_rotation)
	var throw := (aim.orthogonal() * -1.0 * randf_range(28.0, 42.0)) + aim * randf_range(-14.0, -4.0)
	var tween := casing.create_tween().set_parallel()
	tween.tween_property(casing, "position", casing.position + throw, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(casing, "rotation", casing.rotation + randf_range(6.0, 11.0) * (1 if randf() < 0.5 else -1), 0.45).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.5)
	tween.chain().tween_property(casing, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(casing.queue_free)

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
