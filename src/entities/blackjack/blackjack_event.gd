extends GameEvent
class_name BlackjackEvent
## The blackjack room: once a match its doors open for a while, and it is a
## no-fighting zone. Whoever is inside when the doors shut sits at the table
## for a quick blackjack game nobody makes choices in (BlackjackRules):
##   - anyone without cards is given some first: the stake;
##   - players draw to 17, then the dealer does;
##   - whoever beats the dealer keeps their cards, everyone else loses them
##     (a tie loses).
## Then the players are sent back out to spawn points, the table is taken away
## and the room stays open as a normal room for the rest of the match. A card
## area in the room that starts switched off (PowerupSpawner.enabled) switches
## on then: something to come back for.
##
## The room is the map's semi-permanent MapRoom with the gate `gate`; the table
## (BlackjackTable) stands in it. Maps without one never run the event.
## The host runs it; everyone sees the same cards turn over on the table.

const RULES: GameRules = preload("res://src/game_rules.tres")
enum Phase {OPEN, PLAYING, RESULT, DONE}
const LINE_OPEN := "Table's open. Step right up!"
const LINE_LOCK := "No more bets."
const LINE_EMPTY := "Nobody? Suit yourselves."
const LINE_HOUSE := "House wins."
const LINE_LUCKY := "Lucky table tonight."
const LINE_MIXED := "Paying the winners."
const CARD_SIZE := Vector2(30, 42)
const CARD_GAP := 14.0

## The gate (MapRoom.gate) of the room it opens.
@export var gate: StringName = &"blackjack"

## Every peer: where the game is, and when this phase ends on this machine's clock.
var phase: Phase = Phase.OPEN
var phase_ends_msec := 0
## Every peer, once dealt: the players at the table (peer ids) and their seats,
## the hands, the order the cards show up and who won.
var seated: Array[int] = []
var seats: Array[int] = []
var hands: Array = []
var dealer_hand: Array[int] = []
var steps: Array = []
var results: Array[bool] = []

var room: MapRoom
var table: BlackjackTable

# Host only: everyone locked in (also those without a seat).
var _inside: Array[int] = []

var _zone: PeaceZone
var _dealt_msec := 0
var _step_msec := 600
var _shown := 0
var _views: Array = [] # per hand (seated players, then the dealer): {root, cards, total}
var _bubble: ChatBubbleView
var _hud: CanvasLayer
var _hud_title: Label
var _hud_line: Label

func _ready() -> void:
	room = _find_room()
	var tables := room.find_children("*", "BlackjackTable", true, false) if room else []
	table = tables[0] if not tables.is_empty() else null
	if table:
		_zone = PeaceZone.new()
		_zone.name = "NoFighting"
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		var area := room_area()
		box.size = area.size
		shape.shape = box
		_zone.add_child(shape)
		add_child(_zone)
		_zone.global_position = area.get_center()
		_bubble = ChatBubbleView.create(14, 220.0, ChatBubbleView.Align.CENTER, true)
		var anchor := Node2D.new()
		anchor.position = Vector2(0, -40)
		table.dealer().add_child(anchor)
		anchor.add_child(_bubble)
	super._ready()

func _find_room() -> MapRoom:
	if map == null:
		return null
	for candidate in map.rooms:
		if candidate.gate == gate:
			return candidate
	return null

## The room's floor and walls, in global coordinates.
func room_area() -> Rect2:
	var used := room.used_rect()
	return Rect2(room.global_position + Vector2(used.position) * MapRoom.TILE, Vector2(used.size) * MapRoom.TILE)

# --- Host: running the table -----------------------------------------------------------

func begin() -> void:
	if table == null:
		push_warning("Blackjack: the map has no semi-permanent room with gate \"%s\" and a BlackjackTable in it." % gate)
		finish.call_deferred()
		return
	map.set_gate_open.rpc(gate, true)
	_set_phase.rpc(Phase.OPEN, RULES.blackjack_open_seconds, LINE_OPEN)

func _process(_delta: float) -> void:
	_show_table()
	if not multiplayer.is_server() or table == null or Time.get_ticks_msec() < phase_ends_msec:
		return
	match phase:
		Phase.OPEN:
			_lock()
		Phase.PLAYING:
			_settle()
		Phase.RESULT:
			_send_out()

## Host (tests): shut the doors now.
func lock_now() -> void:
	if multiplayer.is_server() and phase == Phase.OPEN:
		phase_ends_msec = 0

## The doors shut on whoever is inside; anyone without cards gets a stake, they
## take their seats and the cards are dealt.
func _lock() -> void:
	map.set_gate_open.rpc(gate, false)
	_inside = players_inside()
	if _inside.is_empty():
		_close_down(LINE_EMPTY)
		return
	var places := table.seats()
	var at_table := _inside.slice(0, places.size())
	var chosen := BlackjackRules.spread_seats(at_table.size(), places.size())
	var cards := PowerupDefs.ids()
	for i in range(at_table.size()):
		var player := _player(at_table[i])
		var hand = player.get_node("PowerupManager")
		if hand.hand_ids.is_empty():
			for k in range(RULES.blackjack_starting_cards):
				hand.grant_card.rpc_id(at_table[i], cards[rng.randi_range(0, cards.size() - 1)])
		player.get_player_controller().teleport.rpc_id(at_table[i], places[chosen[i]].global_position)
	var game := BlackjackRules.play(at_table.size(), RULES.blackjack_player_stand_on, RULES.blackjack_dealer_stand_on, rng)
	_say_all.rpc(LINE_LOCK)
	_deal.rpc(at_table, chosen, game.players, game.dealer, game.steps, game.wins, RULES.blackjack_deal_step_seconds)

## Alive players standing in the room, by peer id.
func players_inside() -> Array[int]:
	var area := room_area()
	var out: Array[int] = []
	for id in GameManager.players:
		var player := _player(id)
		if player and not player.get_health_component().is_dead and area.has_point(player.global_position):
			out.append(id)
	out.sort()
	return out

## The last card is down: losers hand their cards over.
func _settle() -> void:
	for i in range(seated.size()):
		var player := _player(seated[i])
		if player and not results[i]:
			player.get_node("PowerupManager").take_all_cards.rpc_id(seated[i])
	var won := results.count(true)
	var line := LINE_HOUSE if won == 0 else (LINE_LUCKY if won == results.size() else LINE_MIXED)
	_set_phase.rpc(Phase.RESULT, RULES.blackjack_result_seconds, line)

## Everyone at the table goes back out, each to a different spawn point.
func _send_out() -> void:
	var used: Array[Vector2] = []
	for id in _inside:
		var player := _player(id)
		if player == null:
			continue
		var spot := map.random_spawn_position(id)
		for attempt in range(6):
			if not used.has(spot):
				break
			spot = map.random_spawn_position(id)
		used.append(spot)
		player.get_player_controller().teleport.rpc_id(id, spot)
	_close_down("")

## The table goes, the room opens for good, the event is over.
func _close_down(line: String) -> void:
	_set_phase.rpc(Phase.DONE, 0.0, line)
	_clear_table.rpc()
	map.set_gate_open.rpc(gate, true)
	finish()

func _player(peer: int) -> Node2D:
	return map.get_node_or_null(str(peer)) as Node2D

# --- Host -> everyone ------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_phase(new_phase: Phase, seconds: float, line: String) -> void:
	phase = new_phase
	phase_ends_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_say(line)
	if phase == Phase.RESULT:
		_show_results()

@rpc("authority", "call_local", "reliable")
func _say_all(line: String) -> void:
	_say(line)

@rpc("authority", "call_local", "reliable")
func _deal(players: Array[int], seat_numbers: Array[int], player_hands: Array, dealer: Array[int], deal_steps: Array, wins: Array[bool], step_seconds: float) -> void:
	seated = players
	seats = seat_numbers
	hands = player_hands
	dealer_hand = dealer
	steps = deal_steps
	results = wins
	_step_msec = int(step_seconds * 1000.0)
	_dealt_msec = Time.get_ticks_msec()
	_shown = 0
	phase = Phase.PLAYING
	# One more step after the last card, so the dealer's total can be read.
	phase_ends_msec = _dealt_msec + _step_msec * (steps.size() + 2)
	_build_views()
	if seated.has(multiplayer.get_unique_id()):
		_open_hud()

@rpc("authority", "call_local", "reliable")
func _clear_table() -> void:
	if is_instance_valid(table):
		table.queue_free()
	table = null
	if is_instance_valid(_zone):
		_zone.queue_free()
	for view in _views:
		view.root.queue_free()
	_views.clear()
	if is_instance_valid(_hud):
		_hud.queue_free()
	# Something to come back for: the room's card area starts.
	for spawner in map.find_children("*", "PowerupSpawner", true, false):
		if not spawner.enabled and map.room_of(spawner) == room:
			spawner.set_enabled(true)

func _say(line: String) -> void:
	if line != "" and is_instance_valid(_bubble):
		_bubble.push(line)

# --- The table, on every screen -----------------------------------------------------------

## A hand's place on the table: its cards and its total.
func _build_views() -> void:
	for view in _views:
		view.root.queue_free()
	_views.clear()
	for i in range(seated.size()):
		_views.append(_hand_view(table.card_spot(seats[i])))
	_views.append(_hand_view(table.dealer_card_spot()))

func _hand_view(spot: Vector2) -> Dictionary:
	var root := Node2D.new()
	root.z_index = 2
	add_child(root)
	root.global_position = spot
	var total := Label.new()
	total.size = Vector2(120, 20)
	total.position = Vector2(-60, CARD_SIZE.y * 0.5 + 2)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPalette.world_text(total, UiPalette.XS, UiPalette.TEXT)
	root.add_child(total)
	return {"root": root, "cards": [], "total": total}

## Turns over the cards that are due by now.
func _show_table() -> void:
	if steps.is_empty() or _views.is_empty() or table == null:
		return
	var due := steps.size()
	if phase == Phase.PLAYING:
		due = mini(int((Time.get_ticks_msec() - _dealt_msec) / float(maxi(_step_msec, 1))) + 1, steps.size())
	if due == _shown and _shown > 0:
		return
	_shown = due
	for i in range(_views.size()):
		var dealer := i == seated.size()
		var hand: Array = dealer_hand if dealer else hands[i]
		var faces := BlackjackRules.showing(hand, BlackjackRules.DEALER if dealer else i, steps, _shown)
		_lay_cards(_views[i], faces)
		var total: Label = _views[i].total
		var value := BlackjackRules.hand_value(faces)
		if faces.is_empty():
			total.text = ""
		elif value > BlackjackRules.LIMIT:
			total.text = "BUST"
			total.add_theme_color_override("font_color", UiPalette.BAD)
		else:
			total.text = str(value)
	_update_hud()

func _lay_cards(view: Dictionary, faces: Array[int]) -> void:
	var cards: Array = view.cards
	var root: Node2D = view.root
	while cards.size() < faces.size():
		var card := PlayingCardView.new(CARD_SIZE)
		root.add_child(card)
		# Slides in from the dealer.
		card.position = root.to_local(table.dealer().global_position) - CARD_SIZE * 0.5
		cards.append(card)
	for k in range(cards.size()):
		var card: PlayingCardView = cards[k]
		var target := Vector2((k - (cards.size() - 1) * 0.5) * CARD_GAP, 0) - CARD_SIZE * 0.5
		if not card.position.is_equal_approx(target):
			create_tween().tween_property(card, "position", target, 0.18).set_ease(Tween.EASE_OUT)
		if card.card != faces[k]:
			card.flip_to(faces[k], 0.12)

func _show_results() -> void:
	_show_table()
	for i in range(mini(seated.size(), _views.size())):
		var total: Label = _views[i].total
		total.text += "  KEEPS" if results[i] else "  LOSES"
		total.add_theme_color_override("font_color", UiPalette.GOOD if results[i] else UiPalette.BAD)
	_update_hud()

# --- Your own result, on your screen ----------------------------------------------------

func _open_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 40
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.theme = load(UiPalette.THEME_PATH)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	_hud_title = UiPalette.label("Blackjack", UiPalette.M, UiPalette.GOLD)
	_hud_title.uppercase = true
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_title)
	_hud_line = UiPalette.label("", UiPalette.S, UiPalette.TEXT)
	_hud_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_line)

func _update_hud() -> void:
	if not is_instance_valid(_hud):
		return
	var mine := seated.find(multiplayer.get_unique_id())
	if mine < 0:
		return
	var you := BlackjackRules.showing(hands[mine], mine, steps, _shown)
	var dealer := BlackjackRules.showing(dealer_hand, BlackjackRules.DEALER, steps, _shown)
	var line := "You %s  ·  Dealer %s" % [_total_text(you), _total_text(dealer)]
	if phase == Phase.RESULT:
		_hud_title.text = "You keep your cards" if results[mine] else "You lose your cards"
		_hud_title.add_theme_color_override("font_color", UiPalette.GOOD if results[mine] else UiPalette.BAD)
	_hud_line.text = line

static func _total_text(faces: Array[int]) -> String:
	if faces.is_empty():
		return "-"
	var value := BlackjackRules.hand_value(faces)
	return "bust" if value > BlackjackRules.LIMIT else str(value)

func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()

# --- Strip under the clock -------------------------------------------------------------

func status_text() -> String:
	match phase:
		Phase.OPEN:
			return "" # the strip shows the time until the doors shut
		Phase.PLAYING:
			return "dealing"
		Phase.RESULT:
			return "paying out"
	return "closed"

func time_left() -> float:
	if phase != Phase.OPEN:
		return -1.0
	return maxf((phase_ends_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
