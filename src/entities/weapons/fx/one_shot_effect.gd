extends Node2D
class_name OneShotEffect
## A short effect scene (bullet impacts, a weapon breaking) that plays once
## where it is placed and then removes itself. Edit the scenes in this folder
## to change how they look; this script only times them:
##   - particle children (CPUParticles2D / GPUParticles2D) burst once
##   - a child named "Flash" grows and fades out
##   - a child named "Decal" (a bullet hole) stays, then fades out
## The effect is turned to face along the shot: +x is the direction the
## bullet was travelling.

## How long the Flash takes to grow and fade.
@export var flash_seconds: float = 0.12
## How much bigger the Flash gets while fading.
@export var flash_growth: float = 1.8
## How long a Decal stays before fading (1 s fade).
@export var decal_seconds: float = 5.0

func _ready() -> void:
	var done := 0.0
	for child in get_children():
		if child is CPUParticles2D or child is GPUParticles2D:
			child.emitting = true
			done = maxf(done, child.lifetime)
	var flash := get_node_or_null("Flash") as CanvasItem
	if flash:
		var tween := flash.create_tween().set_parallel()
		tween.tween_property(flash, "scale", Vector2.ONE * flash_growth, flash_seconds)
		tween.tween_property(flash, "modulate:a", 0.0, flash_seconds)
		done = maxf(done, flash_seconds)
	var decal := get_node_or_null("Decal") as CanvasItem
	if decal:
		decal.rotation = randf() * TAU # no two holes look the same
		var tween := decal.create_tween()
		tween.tween_interval(decal_seconds)
		tween.tween_property(decal, "modulate:a", 0.0, 1.0)
		done = maxf(done, decal_seconds + 1.0)
	get_tree().create_timer(done + 0.1).timeout.connect(queue_free)
