extends Control
class_name CardView
## One slot of the hand: the card image, a pile of copies behind it when cards
## are stacked, a hotkey badge, an xN chip, the name and (details mode) the
## description. A merged pile glows: faintly at x2, pulsing at x3 and up.
## Layout in card_view.tscn (the preview card
## there is only for the editor). The slot's own position/rotation/scale are
## driven by PowerupHandUI; this node only animates its inner `_body` (idle
## sway, jiggle, punch), so the two never fight over the same property.

const CARD_BACK := preload("res://src/assets/cards/card_back (tmp).png")
const SCENE := "res://src/ui/library/card_view.tscn"

var def: PowerupDef = null
var count := 0

@onready var _body: Control = $Body
@onready var _pile: Control = $Body/Pile
@onready var _glow: Panel = $Body/Glow
@onready var _art: TextureRect = $Body/Art
@onready var _outline: Panel = $Body/Outline
@onready var _name: Label = $Body/Name
@onready var _hotkey: Label = $Body/Hotkey
@onready var _chip: Label = $Body/Chip
@onready var _details: Label = $Details
var _highlight := 0.0 # 0..1, glow on cards matching the one picked to merge
var _phase := randf() * TAU

static func create() -> CardView:
	return load(SCENE).instantiate()

func _ready() -> void:
	_refresh()

# --- Content ---------------------------------------------------------------------

func set_card(new_def: PowerupDef, new_count: int) -> void:
	if new_def == def and new_count == count:
		return
	def = new_def
	count = new_count
	_refresh()

func set_hotkey(text: String) -> void:
	_hotkey.text = text

func set_details_visible(show_details: bool) -> void:
	_details.visible = show_details and def != null

## Glow cards that match the one picked to merge.
func set_highlight(amount: float) -> void:
	_highlight = amount

func is_empty() -> bool:
	return def == null

func _refresh() -> void:
	var has_card := def != null
	_outline.visible = not has_card
	_art.visible = has_card
	_name.visible = has_card
	_chip.visible = has_card and count > 1
	_glow.visible = has_card and count >= 2
	_hotkey.modulate.a = 1.0 if has_card else 0.35
	for child in _pile.get_children():
		child.queue_free()
	if not has_card:
		_details.visible = false
		return
	var texture: Texture2D = def.card_texture if def.card_texture else CARD_BACK
	_art.texture = texture
	_name.text = def.get_display_name()
	_chip.text = "x%d" % count
	_details.text = def.get_type_description()
	for layer in HandLayout.pile_offsets(count):
		var copy := _texture(_pile, texture)
		copy.pivot_offset = pivot_offset
		copy.position = layer.offset
		copy.rotation = layer.rotation
		copy.modulate = Color(layer.shade, layer.shade, layer.shade)
		_pile.move_child(copy, 0) # deeper copies behind nearer ones

# --- Animation -------------------------------------------------------------------

## Called every frame by the hand. `jiggle` is 0..1 (merge key held).
func tick(time: float, jiggle: float) -> void:
	if def == null:
		_body.position = Vector2.ZERO
		_body.rotation = 0.0
		return
	var sway := sin(time * 1.6 + _phase)
	_body.position.y = sway * 2.0
	_body.rotation = sin(time * 22.0 + _phase) * 0.05 * jiggle
	if _glow.visible:
		# x2: faint and steady, x3-x4: bright and pulsing.
		var base := 0.25 if count < 3 else 0.6
		var pulse := 0.0 if count < 3 else 0.3 * sin(time * (3.0 + count) + _phase)
		_glow.modulate.a = base + pulse
	var lit := _highlight * (0.6 + 0.4 * sin(time * 8.0))
	_art.modulate = Color(1.0 + 0.35 * lit, 1.0 + 0.3 * lit, 1.0 + 0.1 * lit)

## A new card: rises from below and rotates into place.
func animate_collect() -> void:
	_body.position = Vector2(0, 180)
	_body.rotation = 0.5
	_body.scale = Vector2(0.6, 0.6)
	_body.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position", Vector2.ZERO, 0.4)
	tween.tween_property(_body, "rotation", 0.0, 0.4)
	tween.tween_property(_body, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_body, "modulate:a", 1.0, 0.15)

## Cards landed on this pile: a "thunk" and the count chip pops.
func animate_merge_in(delay: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(_body, "scale", Vector2(1.18, 0.9), 0.07)
	tween.tween_property(_body, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_chip.scale = Vector2.ONE
	var pop := create_tween()
	pop.tween_interval(delay)
	pop.tween_property(_chip, "scale", Vector2(1.8, 1.8), 0.08)
	pop.tween_property(_chip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

## The hand was emptied (death): the card drops out of view.
func animate_clear(old_texture: Texture2D) -> void:
	if old_texture == null:
		return
	var ghost := _texture(self, old_texture)
	ghost.pivot_offset = pivot_offset
	var tween := create_tween().set_parallel()
	tween.tween_property(ghost, "position:y", 140.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "rotation", 0.6, 0.35)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(ghost.queue_free)

## Global rect of the card art, for ghosts that fly elsewhere.
func art_texture() -> Texture2D:
	return _art.texture if def != null else null

# --- Building blocks ---------------------------------------------------------------

func _texture(parent: Node, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	# expand_mode first: otherwise the size is clamped to the texture's size.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = HandLayout.CARD_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect
