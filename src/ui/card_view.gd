extends Control
class_name CardView
## One slot of the hand: the card image, a pile of copies behind it when cards
## are stacked, a hotkey badge, an xN chip, the name and (details mode) the
## description. Under Poker it also shows the card's playing card (sticking out
## on the left, the side that stays visible in the fan), the poker hand it makes
## with the board right now ("x2 Trips", above the name) and a gold halo that
## grows with the hand's strength. Built in code. The slot's own position/rotation/scale are
## driven by PowerupHandUI; this node only animates its inner `_body` (idle
## sway, jiggle, punch), so the two never fight over the same property.

const CARD_BACK := preload("res://src/assets/cards/card_back (tmp).png")
const NAME_BAND := 25.0 # height of the PNG's name band at drawn size
const FEATURED_GOLD := Color(1.0, 0.82, 0.3)

var def: PowerupDef = null
var count := 0
var hole := -1 # playing card under Poker, -1 otherwise
var hand: Dictionary = {} # PokerRules.evaluate() result, {} outside Poker

var _body: Control
var _pile: Control
var _glow: Panel
var _art: TextureRect
var _outline: Panel
var _name: Label
var _hotkey: Label
var _chip: Label
var _details: Label
var _badge: PlayingCardView
var _hand_label: Label
var _highlight := 0.0 # 0..1, matching-card glow in shuffle mode
var _phase := randf() * TAU

func _init() -> void:
	var size_px := HandLayout.CARD_SIZE
	size = size_px
	custom_minimum_size = size_px
	pivot_offset = Vector2(size_px.x * 0.5, size_px.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_body = _control(self)
	_body.pivot_offset = pivot_offset

	# Empty slot: a plain outline where a card can go.
	_outline = Panel.new()
	_outline.size = size_px
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_box := StyleBoxFlat.new()
	slot_box.draw_center = false
	slot_box.set_border_width_all(2)
	slot_box.border_color = UiPalette.BORDER_STRONG
	slot_box.set_corner_radius_all(8)
	_outline.add_theme_stylebox_override("panel", slot_box)
	_body.add_child(_outline)

	_pile = _control(_body)

	# Poker: a gold halo behind the card, stronger for better hands.
	_glow = Panel.new()
	_glow.size = size_px
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := StyleBoxFlat.new()
	halo.bg_color = FEATURED_GOLD
	halo.set_corner_radius_all(14)
	halo.set_expand_margin_all(5.0)
	halo.shadow_color = Color(FEATURED_GOLD, 0.6)
	halo.shadow_size = 12
	_glow.add_theme_stylebox_override("panel", halo)
	_glow.visible = false
	_body.add_child(_glow)

	_art = _texture(_body, null)

	_name = _label(_body, 11)
	_name.position = Vector2(4, size_px.y - NAME_BAND)
	_name.size = Vector2(size_px.x - 8, NAME_BAND)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true

	_hotkey = _label(_body, 13)
	_hotkey.position = Vector2(-6, -8)
	_hotkey.size = Vector2(22, 22)
	_hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotkey.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var key_box := UiPalette.panel(&"raised", 0)
	key_box.border_color = UiPalette.BORDER_STRONG
	_hotkey.add_theme_stylebox_override("normal", key_box)

	_chip = _label(_body, 15)
	_chip.position = Vector2(size_px.x - 30, -10)
	_chip.size = Vector2(36, 22)
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.pivot_offset = _chip.size * 0.5
	_chip.add_theme_color_override("font_color", UiPalette.ACCENT)

	# Details text sits above the card: the hand is at the bottom of the screen.
	_details = _label(self, 10)
	_details.position = Vector2(-10, -118)
	_details.size = Vector2(size_px.x + 20, 110) # bottom-aligned, so text grows upwards
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_color_override("font_color", UiPalette.TEXT)
	_details.visible = false

	_badge = PlayingCardView.new(Vector2(24, 33))
	_badge.position = Vector2(-12, 14)
	_badge.rotation = -0.14
	_body.add_child(_badge)

	_hand_label = _label(_body, 11)
	_hand_label.position = Vector2(5, size_px.y - NAME_BAND - 17)
	_hand_label.size = Vector2(size_px.x - 8, 16)
	_hand_label.clip_text = true

	_refresh()

# --- Content ---------------------------------------------------------------------

func set_card(new_def: PowerupDef, new_count: int, new_hole: int = -1, new_hand: Dictionary = {}) -> void:
	if new_def == def and new_count == count and new_hole == hole and new_hand.get("rank", -1) == hand.get("rank", -1):
		return
	var hand_improved: bool = new_def == def and new_hole == hole and new_hand.get("stacks", 0) > hand.get("stacks", 0)
	def = new_def
	count = new_count
	hole = new_hole
	hand = new_hand
	_refresh()
	if hand_improved:
		animate_merge_in(0.0) # a board card made this hand better

## Poker stacks this card would be played with now (0 outside Poker).
func strength() -> int:
	return int(hand.get("stacks", 0))

func set_hotkey(text: String) -> void:
	_hotkey.text = text

func set_details_visible(show_details: bool) -> void:
	_details.visible = show_details and def != null

## Shuffle mode: glow cards that match the selected one.
func set_highlight(amount: float) -> void:
	_highlight = amount

func is_empty() -> bool:
	return def == null

func _refresh() -> void:
	var has_card := def != null
	_outline.visible = not has_card
	_art.visible = has_card
	_name.visible = has_card
	_chip.visible = has_card and count > 1 and hole < 0
	_glow.visible = has_card and strength() >= 2
	_badge.visible = has_card and hole >= 0
	_hand_label.visible = has_card and not hand.is_empty()
	_hotkey.modulate.a = 1.0 if has_card else 0.35
	for child in _pile.get_children():
		child.queue_free()
	if not has_card:
		_details.visible = false
		return
	var texture: Texture2D = def.card_texture if def.card_texture else CARD_BACK
	_art.texture = texture
	_name.text = def.get_display_name()
	if hole >= 0:
		_badge.show_card(hole)
	if not hand.is_empty():
		_hand_label.text = "x%d %s" % [strength(), hand.short]
		_hand_label.add_theme_color_override("font_color", strength_color(strength()))
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

## Called every frame by the hand. `jiggle` is 0..1 (shuffle mode held).
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
		var base := 0.25 if strength() < 3 else 0.6
		var pulse := 0.0 if strength() < 3 else 0.3 * sin(time * (3.0 + strength()) + _phase)
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

## Colour for a poker hand's stacks: grey, white, gold, hot orange.
static func strength_color(stacks: int) -> Color:
	match stacks:
		1:
			return UiPalette.TEXT_DIM
		2:
			return UiPalette.TEXT
		3:
			return FEATURED_GOLD
	return Color(1.0, 0.55, 0.2)

# --- Building blocks ---------------------------------------------------------------

func _control(parent: Node) -> Control:
	var c := Control.new()
	c.size = HandLayout.CARD_SIZE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

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

func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_override("font", UiPalette.HEADING_FONT)
	label.add_theme_color_override("font_outline_color", UiPalette.OUTLINE)
	parent.add_child(label)
	return label
