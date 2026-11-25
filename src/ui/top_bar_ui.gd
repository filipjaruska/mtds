extends Control
class_name TopBarUI
## The bar at the top of the screen (match only): a mini icon per player either
## side of the clock, with a thin HP bar, greyed out while dead, and your own
## icon outlined. Team matches put Red left and Blue right (ChatRules.bar_sides).
## Chat messages also appear under the sender's icon, growing away from the
## clock so they never cover it or the event strip under it. When several players on
## one side talk at once their bubbles stack into rows instead of overlapping.
## This node sits at the top-centre of the screen; only the local player's copy runs.

const SLOT_SCENE := preload("res://src/ui/library/top_bar_slot.tscn")
const SLOT := TopBarSlot.SIZE
const GAP := 6.0
## Distance from the screen centre to the nearest icon: clears the clock pill
## and the event strip under it (EventStripUI).
const START := 96.0
const TOP := 8.0
const BUBBLE_GAP := 4.0

## PlayerUI's owner: TopBar -> PlayerUI -> PlayerCamera -> CameraComponent -> Player.
@onready var player: Node2D = get_node("../../../..")

var _slots := {} # peer id -> TopBarSlot
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
		slot.queue_free()
	_slots.clear()
	for side in ["left", "right"]:
		var ids: Array = sides[side]
		for k in range(ids.size()):
			var x := START + k * (SLOT + GAP)
			var left_side: bool = side == "left"
			var slot: TopBarSlot = SLOT_SCENE.instantiate()
			slot.position = Vector2(-x - SLOT if left_side else x, TOP)
			add_child(slot)
			var color: Color = TeamRules.COLORS[GameManager.get_team(ids[k])] if team_mode else _player_color(ids[k])
			slot.setup(color, ids[k] == player.get_multiplayer_authority(), left_side, _initial(ids[k]))
			slot.index = k
			_slots[ids[k]] = slot

func _update_state() -> void:
	var nodes := {}
	for node in get_tree().get_nodes_in_group("Player"):
		nodes[node.get_multiplayer_authority()] = node
	for peer_id in _slots:
		var node: Node = nodes.get(peer_id)
		var health = node.get_node_or_null("HealthComponent") if node else null
		var fraction := 0.0
		var dead := true
		if health:
			dead = health.is_dead
			fraction = clampf(health.current_health / maxf(health.max_health, 1.0), 0.0, 1.0)
		_slots[peer_id].show_health(fraction, dead)
	_stack_bubbles()

## Visible bubbles on each side take rows, nearest the clock on top.
func _stack_bubbles() -> void:
	for side in ["left", "right"]:
		var talking: Array = _slots.values().filter(func(s): return s.side == side and s.bubble.visible)
		talking.sort_custom(func(a, b): return a.index < b.index)
		var y := TopBarSlot.BUBBLE_TOP
		for slot in talking:
			slot.anchor.position.y = y
			y += slot.bubble.size.y + BUBBLE_GAP

func _on_message(peer_id: int, text: String) -> void:
	if _slots.has(peer_id):
		_slots[peer_id].bubble.push(text)

func _initial(peer_id: int) -> String:
	var player_name := str(GameManager.get_player(peer_id).get("name", "")).strip_edges()
	return player_name.left(1).to_upper() if player_name != "" else "?"

func _player_color(peer_id: int) -> Color:
	var value = GameManager.get_player(peer_id).get("color", Color.WHITE)
	var color: Color = value if value is Color else Color.WHITE
	color.a = 1.0
	return color
