extends Control
class_name PowerupHandUI
## The player's powerup cards as a fanned hand at the bottom centre.
## This node sits at the bottom-centre of the screen; HandLayout gives every
## slot its place. Each update is compared with the previous inventory
## (HandLayout.diff) to decide what to animate:
##   collected  card rises into its slot
##   merged     (shuffle) a copy flies from the source slot onto the pile, which thunks
##   played     a copy lifts, grows and fades upwards (Poker shows the hand, e.g. "FLUSH x3")
##   cleared    (death) the card drops away
## Holding details spreads the fan into a flat row with descriptions; holding
## shuffle makes the cards jiggle, lifts the picked card and lights up matches.

const SLOT_COUNT := 4
const MOVE_DURATION := 0.18
const GAMEPAD_HOTKEYS := ["←", "↑", "→", "↓"]

var _views: Array[CardView] = []
var _targets: Array[StringName] = []
var _inventory: Array = [] # [{def, count}] as last shown
var _selected := -1
var _played_slot := -1
var _expanded := false
var _shuffle_held := false
var _time := 0.0
@onready var _hint: Label = $Hint # styled by the CardHint theme variation

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SLOT_COUNT):
		var view := CardView.create()
		view.name = "Card%d" % (i + 1)
		add_child(view)
		_views.append(view)
		_targets.append(&"")
		_inventory.append({"def": &"", "count": 0})
		_place(i, &"normal", false)
	move_child(_hint, -1) # above the cards

func _process(delta: float) -> void:
	_time += delta
	_expanded = InputManager.is_powerup_details_held()
	_shuffle_held = GameManager.is_shuffle_mode() and InputManager.is_powerup_shuffle_held() and not _expanded
	var selected_def: StringName = _inventory[_selected].def if _selected >= 0 else &""
	for i in range(SLOT_COUNT):
		var view := _views[i]
		var state: StringName = &"normal"
		if _expanded:
			state = &"spread"
		elif i == _selected:
			state = &"lifted"
		_place(i, state, true)
		view.set_details_visible(_expanded)
		view.set_hotkey(_hotkey_text(i))
		var matches: bool = selected_def != &"" and i != _selected and _inventory[i].def == selected_def
		view.set_highlight(1.0 if matches else 0.0)
		view.tick(_time, 1.0 if _shuffle_held and i != _selected else 0.0)
	# Details mode explains itself; shuffle mode gets a hint.
	_hint.visible = _shuffle_held
	_hint.text = "Merge"

## `inventory` is PowerupManager.get_inventory_display_data():
## one {card: PowerupDef or null, count, selected, hole, hand} per slot.
func update_inventory(inventory: Array) -> void:
	var next: Array = []
	_selected = -1
	for i in range(SLOT_COUNT):
		var entry: Dictionary = inventory[i] if i < inventory.size() else {}
		var card: PowerupDef = entry.get("card", null)
		next.append({"def": card.id if card else &"", "count": int(entry.get("count", 0))})
		if entry.get("selected", false):
			_selected = i
	var changes := HandLayout.diff(_inventory, next, _played_slot)
	_played_slot = -1
	var old_textures: Array = []
	for view in _views:
		old_textures.append(view.art_texture())
	for i in range(SLOT_COUNT):
		var entry: Dictionary = inventory[i] if i < inventory.size() else {}
		_views[i].set_card(entry.get("card", null), int(entry.get("count", 0)), int(entry.get("hole", -1)), entry.get("hand", {}))
	_inventory = next
	for change in changes:
		match change.kind:
			&"collected":
				_views[change.slot].animate_collect()
			&"merged":
				_fly_ghost(old_textures[change.from], change.from, change.slot)
				_views[change.slot].animate_merge_in(0.2)
			&"cleared":
				_views[change.slot].animate_clear(old_textures[change.slot])

## The player used the card in `slot`. Call before update_inventory() so the
## card is still in the hand when its copy takes off.
func play_card(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or _views[slot].is_empty():
		return
	_played_slot = slot
	var view := _views[slot]
	var ghost := _ghost(view.art_texture(), view)
	var rise := ghost.position + Vector2(0, -150)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "position", rise, 0.5)
	tween.tween_property(ghost, "rotation", 0.0, 0.25)
	tween.tween_property(ghost, "scale", Vector2(1.7, 1.7), 0.5)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ghost.queue_free)
	if not view.hand.is_empty():
		var label := "%s x%d" % [String(view.hand.name).to_upper(), view.strength()]
		_burst_text(label, rise + Vector2(HandLayout.CARD_SIZE.x * 0.5, HandLayout.CARD_SIZE.y * 0.4), CardView.strength_color(view.strength()))
	elif view.count > 1:
		_burst_text("x%d" % view.count, rise + Vector2(HandLayout.CARD_SIZE.x * 0.5, HandLayout.CARD_SIZE.y * 0.4), UiPalette.ACCENT)

## Kept for callers of the old inventory UI.
func highlight_slot(slot: int, _duration: float = 0.4) -> void:
	play_card(slot)

# --- Helpers ---------------------------------------------------------------------

func _place(index: int, state: StringName, animate: bool) -> void:
	var view := _views[index]
	if animate and _targets[index] == state:
		return
	_targets[index] = state
	var t := HandLayout.slot_transform(index, SLOT_COUNT, state)
	var top_left: Vector2 = t.position - view.pivot_offset
	view.z_index = 1 if state == &"lifted" else 0
	if not animate:
		view.position = top_left
		view.rotation = t.rotation
		view.scale = Vector2.ONE * t.scale
		return
	var tween := view.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position", top_left, MOVE_DURATION)
	tween.tween_property(view, "rotation", t.rotation, MOVE_DURATION)
	tween.tween_property(view, "scale", Vector2.ONE * t.scale, MOVE_DURATION)

## A loose copy of a card, placed exactly over `over`, for flying animations.
func _ghost(texture: Texture2D, over: Control) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # before size, see CardView._texture
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.size = HandLayout.CARD_SIZE
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.pivot_offset = over.pivot_offset
	ghost.position = over.position
	ghost.rotation = over.rotation
	ghost.scale = over.scale
	ghost.z_index = 2
	add_child(ghost)
	return ghost

func _fly_ghost(texture: Texture2D, from_slot: int, to_slot: int) -> void:
	if texture == null:
		return
	var ghost := _ghost(texture, _views[from_slot])
	var target := _views[to_slot]
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Arc over the hand: up first, then down onto the pile.
	var mid := (ghost.position + target.position) * 0.5 + Vector2(0, -60)
	tween.tween_property(ghost, "position", mid, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "rotation", target.rotation, 0.2)
	tween.chain().tween_property(ghost, "position", target.position + Vector2(-7, -7), 0.1)
	tween.chain().tween_callback(ghost.queue_free)

func _burst_text(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BurstText"
	label.add_theme_color_override("font_color", color)
	label.size = Vector2(260, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.position = at - label.size * 0.5
	label.scale = Vector2(0.4, 0.4)
	label.z_index = 3
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)

func _hotkey_text(slot: int) -> String:
	if InputManager.current_device == InputManager.InputDevice.GAMEPAD:
		return GAMEPAD_HOTKEYS[slot]
	return str(slot + 1)
