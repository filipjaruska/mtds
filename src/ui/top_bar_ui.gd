extends Control
class_name TopBarUI
## The bar at the top of the screen (match only): a mini icon per player either
## side of the clock, with a thin HP bar, greyed out while dead, and your own
## icon outlined. Team matches put Red left and Blue right (ChatRules.bar_sides).
## Chat messages also appear under the sender's icon, growing away from the
## clock so they never cover it or the poker board. When several players on
## one side talk at once their bubbles stack into rows instead of overlapping.
## This node sits at the top-centre of the screen; only the local player's copy runs.

const ICON := preload("res://src/assets/icon.svg")
const SLOT := 34.0
const GAP := 6.0
## Distance from the screen centre to the nearest icon: clears the clock pill
## and the poker board under it.
const START := 96.0
const TOP := 8.0
const HP_HEIGHT := 3.0
const BUBBLE_TOP := SLOT + HP_HEIGHT + 6.0
const BUBBLE_GAP := 4.0

## PlayerUI's owner: TopBar -> PlayerUI -> PlayerCamera -> CameraComponent -> Player.
@onready var player: Node2D = get_node("../../../..")

var _slots := {} # peer id -> {root, frame, hp, hp_bg, anchor, bubble, side, index}
var _layout_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ChatManager.message_received.connect(_on_message)

func _exit_tree() -> void:
	if ChatManager.message_received.is_connected(_on_message):
		ChatManager.message_received.disconnect(_on_message)

func _process(_delta: float) -> void:
	var active: bool = player.is_multiplayer_authority() and GameManager.is_state(GameManager.GameState.PLAYING)
	visible = active
	if not active:
		return
	var team_mode := GameManager.is_team_mode()
	var sides := ChatRules.bar_sides(GameManager.players, team_mode)
	var key := "%s|%s" % [sides, team_mode]
	if key != _layout_key:
		_layout_key = key
		_rebuild(sides, team_mode)
	_update_state()

func _rebuild(sides: Dictionary, team_mode: bool) -> void:
	for slot in _slots.values():
		slot.root.queue_free()
	_slots.clear()
	for side in ["left", "right"]:
		var ids: Array = sides[side]
		for k in range(ids.size()):
			var x := START + k * (SLOT + GAP)
			var left_side: bool = side == "left"
			var slot := _make_slot(ids[k], Vector2(-x - SLOT if left_side else x, TOP), left_side, team_mode)
			slot["side"] = side
			slot["index"] = k
			_slots[ids[k]] = slot

func _make_slot(peer_id: int, at: Vector2, left_side: bool, team_mode: bool) -> Dictionary:
	var root := Control.new()
	root.position = at
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var color: Color = TeamRules.COLORS[GameManager.get_team(peer_id)] if team_mode else _player_color(peer_id)
	var frame := Panel.new()
	frame.size = Vector2(SLOT, SLOT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.85)
	style.set_corner_radius_all(7)
	style.set_border_width_all(2)
	var mine := peer_id == player.get_multiplayer_authority()
	style.border_color = Color.WHITE if mine else Color(color, 0.55)
	frame.add_theme_stylebox_override("panel", style)
	root.add_child(frame)

	var icon := TextureRect.new()
	icon.texture = ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 4)
	icon.size = Vector2(SLOT - 8, SLOT - 8)
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(0, SLOT + 2)
	hp_bg.size = Vector2(SLOT, HP_HEIGHT)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)
	var hp := ColorRect.new()
	hp.color = Color(0.35, 0.9, 0.4)
	hp.position = hp_bg.position
	hp.size = hp_bg.size
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp)

	# Messages hang under the icon and grow away from the clock.
	var anchor := Control.new()
	anchor.position = Vector2(SLOT if left_side else 0.0, BUBBLE_TOP)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	var bubble := ChatBubbleView.new(11, 160.0, ChatBubbleView.Align.RIGHT_EDGE if left_side else ChatBubbleView.Align.LEFT_EDGE, false)
	anchor.add_child(bubble)

	return {"root": root, "frame": frame, "hp": hp, "hp_bg": hp_bg, "anchor": anchor, "bubble": bubble}

func _update_state() -> void:
	var nodes := {}
	for node in get_tree().get_nodes_in_group("Player"):
		nodes[node.get_multiplayer_authority()] = node
	for peer_id in _slots:
		var slot: Dictionary = _slots[peer_id]
		var node: Node = nodes.get(peer_id)
		var health = node.get_node_or_null("HealthComponent") if node else null
		var fraction := 0.0
		var dead := true
		if health:
			dead = health.is_dead
			fraction = clampf(health.current_health / maxf(health.max_health, 1.0), 0.0, 1.0)
		slot.hp.size.x = slot.hp_bg.size.x * fraction
		slot.hp.color = Color(0.35, 0.9, 0.4) if fraction > 0.5 else (Color(1.0, 0.75, 0.25) if fraction > 0.25 else Color(1.0, 0.3, 0.25))
		slot.frame.modulate = Color(0.45, 0.45, 0.45, 0.55) if dead else Color.WHITE
	_stack_bubbles()

## Visible bubbles on each side take rows, nearest the clock on top.
func _stack_bubbles() -> void:
	for side in ["left", "right"]:
		var talking: Array = _slots.values().filter(func(s): return s.side == side and s.bubble.visible)
		talking.sort_custom(func(a, b): return a.index < b.index)
		var y := BUBBLE_TOP
		for slot in talking:
			slot.anchor.position.y = y
			y += slot.bubble.size.y + BUBBLE_GAP

func _on_message(peer_id: int, text: String) -> void:
	if _slots.has(peer_id):
		_slots[peer_id].bubble.push(text)

func _player_color(peer_id: int) -> Color:
	var value = GameManager.get_player(peer_id).get("color", Color.WHITE)
	var color: Color = value if value is Color else Color.WHITE
	color.a = 1.0
	return color
