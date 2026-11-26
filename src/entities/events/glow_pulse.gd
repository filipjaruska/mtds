extends CanvasItem
## Makes a sprite glow on and off (Shady Fella's cigarette ember).

@export var bright: Color = Color(1.5, 1.35, 1.2)
@export_range(0.1, 5.0, 0.05, "suffix:s") var seconds: float = 0.9

func _ready() -> void:
	var glow := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	glow.tween_property(self, "self_modulate", bright, seconds)
	glow.tween_property(self, "self_modulate", Color.WHITE, seconds)
