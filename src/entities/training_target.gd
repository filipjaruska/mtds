extends StaticBody2D
class_name TrainingTarget
## A practice target for the tutorial and the debug arena. Solid like a wall
## (shots and players stop at it); every hit shows the damage dealt, and when
## its HP runs out it pops and comes back. Like everything else the host
## decides the hits (CombatServer calls take_hit) and every peer sees them.
## Its look is training_target.tscn ("Rings" is what flashes and pops); place
## it on a map by instancing that scene. HP and respawn time: game_rules.tres.

const RADIUS := 22.0
const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector
var MAX_HP: float = RULES.target_hp
var RESPAWN_SECONDS: float = RULES.target_respawn_seconds

var hp := MAX_HP
@onready var _rings: Node2D = $Rings

func _ready() -> void:
	collision_layer = CombatServer.WALL_LAYER
	collision_mask = 0
	add_to_group("training_target")

## Host only: a shot or swing hit this target.
func take_hit(amount: float) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_show_hit.rpc(amount, hp)
	if hp <= 0.0:
		await get_tree().create_timer(RESPAWN_SECONDS).timeout
		if is_inside_tree():
			_respawn.rpc()

@rpc("authority", "call_local", "reliable")
func _show_hit(amount: float, hp_left: float) -> void:
	hp = hp_left
	var flash := create_tween()
	_rings.modulate = Color(2.0, 2.0, 2.0)
	flash.tween_property(_rings, "modulate", Color.WHITE, 0.15)
	_float_number(amount)
	if hp_left <= 0.0:
		collision_layer = 0
		var pop := create_tween().set_parallel()
		pop.tween_property(_rings, "scale", Vector2(1.5, 1.5), 0.15)
		pop.tween_property(_rings, "modulate:a", 0.0, 0.15)

@rpc("authority", "call_local", "reliable")
func _respawn() -> void:
	hp = MAX_HP
	collision_layer = CombatServer.WALL_LAYER
	_rings.scale = Vector2(0.3, 0.3)
	_rings.modulate = Color.WHITE
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(_rings, "scale", Vector2.ONE, 0.25)

func _float_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	UiPalette.world_text(label, 18, UiPalette.WARN)
	label.size = Vector2(60, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30 + randf_range(-10, 10), -RADIUS - 28)
	label.z_index = 10
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
