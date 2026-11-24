extends RefCounted
class_name ImpactFx
## Plays the effect scene for where a bullet stopped (see BulletFx.Impact) or a
## weapon broke. The scenes are in src/entities/weapons/fx/; edit them there.

const WALL := preload("res://src/entities/weapons/fx/wall_impact.tscn")
const PLAYER := preload("res://src/entities/weapons/fx/player_impact.tscn")
const SHIELD := preload("res://src/entities/weapons/fx/shield_impact.tscn")
const SHATTER := preload("res://src/entities/weapons/fx/weapon_shatter.tscn")

## `dir` is the direction the bullet was travelling.
static func play(parent: Node, at: Vector2, dir: Vector2, impact: int) -> void:
	match impact:
		BulletFx.Impact.WALL:
			_spawn(WALL, parent, at, dir)
		BulletFx.Impact.PLAYER:
			_spawn(PLAYER, parent, at, dir)
		BulletFx.Impact.SHIELD:
			_spawn(SHIELD, parent, at, dir)

## A weapon breaking: a flash and steel shards flying away along `dir`.
static func shatter(parent: Node, at: Vector2, dir: Vector2) -> void:
	_spawn(SHATTER, parent, at, dir)

## Placed before it enters the tree: particles start from wherever they are then.
static func _spawn(scene: PackedScene, parent: Node, at: Vector2, dir: Vector2) -> void:
	var effect: Node2D = scene.instantiate()
	effect.top_level = true
	effect.position = at
	effect.rotation = dir.angle()
	parent.add_child(effect)
