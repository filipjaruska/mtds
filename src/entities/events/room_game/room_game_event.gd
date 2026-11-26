extends GameEvent
class_name RoomGameEvent
## A room game (PvE): once a match a semi-permanent room opens for a while and
## is a no-fighting zone. Whoever is inside when the doors shut plays a quick
## game at the table, with no choices to make:
##   - anyone without cards is given some first: the stake;
##   - the game decides, per player: lose all cards, keep them, or win more;
##   - then the players are sent back out to spawn points, the table is taken
##     away and the room stays open as a normal room. A card area in the room
##     that starts switched off (PowerupSpawner.enabled) switches on then:
##     something to come back for.
## The room is the map's MapRoom with the gate `gate`; the table (RoomGameTable)
## stands in it. Maps without one never run the event.
##
## This script does the room; a game extends it (BlackjackEvent) and fills in:
##   play_game(players)        host: plays the whole game; returns what every
##                             peer needs to show it, with "results" (one per
##                             player: LOSE_ALL, KEEP or cards won) and
##                             "seconds" (how long it takes to watch)
##   _game_started(game)       every peer: set up the table's show
##   _game_tick()              every peer, every frame while it plays
##   _game_over()              every peer: show the results on the table
##   hud_line(seat)            the line under the title on a player's screen
##   _game_cleared()           every peer: the table is taken away

enum Phase {OPEN, PLAYING, RESULT, DONE}
## A result: the player loses every card. 0 keeps them; above 0 wins that many.
const LOSE_ALL := -1
const KEEP := 0

## Name on the players' screens ("Blackjack").
@export var game_name: String = "Blackjack"
## The gate (MapRoom.gate) of the room it opens.
@export var gate: StringName = &"blackjack"
@export_group("Numbers")
## How long the room stays open before its doors shut and the game starts.
@export_range(5.0, 120.0, 1.0, "suffix:s") var open_seconds: float = 30.0
## How long the result shows before the players are sent back out.
@export_range(1.0, 15.0, 0.5, "suffix:s") var result_seconds: float = 4.0
## Cards given to a player at the table who holds none: their stake.
@export_range(0, 4) var starting_cards: int = 2
@export_group("Lines")
@export var line_open: String = "Table's open. Step right up!"
@export var line_lock: String = "No more bets."
@export var line_empty: String = "Nobody? Suit yourselves."
@export var line_all_lose: String = "House wins."
@export var line_all_win: String = "Lucky table tonight."
@export var line_mixed: String = "Paying the winners."
## In the strip under the clock while the game plays.
@export var status_playing: String = "dealing"

## Every peer: where the game is, and when this phase ends on this machine's clock.
var phase: Phase = Phase.OPEN
var phase_ends_msec := 0
## Every peer, once the game starts: the players at the table (peer ids), their
## seats and their results.
var seated: Array[int] = []
var seats: Array[int] = []
var results: Array[int] = []

var room: MapRoom
var table: RoomGameTable

# Host only: everyone locked in (also those without a seat).
var _inside: Array[int] = []

var _zone: PeaceZone
var _bubble: ChatBubbleView
var _hud: CanvasLayer
var _hud_title: Label
var _hud_line: Label

func _ready() -> void:
	room = _find_room()
	var tables := room.find_children("*", "RoomGameTable", true, false) if room else []
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
		table.host().add_child(anchor)
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

# --- For the game (override) -------------------------------------------------------------

func play_game(_players: int) -> Dictionary:
	return {"results": [], "seconds": 0.0}

func _game_started(_game: Dictionary) -> void:
	pass

func _game_tick() -> void:
	pass

func _game_over() -> void:
	pass

func hud_line(_seat: int) -> String:
	return ""

func _game_cleared() -> void:
	pass

## Which of `seats` seats (indices) `players` players take: spread round the table.
static func spread_seats(players: int, seat_count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(mini(players, seat_count)):
		out.append(clampi(roundi((i + 0.5) * seat_count / float(players) - 0.5), 0, seat_count - 1))
	return out

## A result in a few words, for the table ("KEEPS", "LOSES", "+2").
static func result_text(result: int) -> String:
	if result == LOSE_ALL:
		return "LOSES"
	return "KEEPS" if result == KEEP else "+%d" % result

# --- Host: running the room ------------------------------------------------------------

func begin() -> void:
	if table == null:
		push_warning("%s: the map has no semi-permanent room with gate \"%s\" and a RoomGameTable in it." % [game_name, gate])
		finish.call_deferred()
		return
	map.set_gate_open.rpc(gate, true)
	_set_phase.rpc(Phase.OPEN, open_seconds, line_open)

func _process(_delta: float) -> void:
	if phase == Phase.PLAYING or phase == Phase.RESULT:
		_game_tick()
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
## take their seats and the game is played.
func _lock() -> void:
	map.set_gate_open.rpc(gate, false)
	_inside = players_inside()
	if _inside.is_empty():
		_close_down(line_empty)
		return
	var places := table.seats()
	var at_table := _inside.slice(0, places.size())
	var chosen := spread_seats(at_table.size(), places.size())
	for i in range(at_table.size()):
		var player := _player(at_table[i])
		var hand = player.get_node("PowerupManager")
		if hand.hand_ids.is_empty():
			for k in range(starting_cards):
				hand.grant_card.rpc_id(at_table[i], PowerupDefs.random_id())
		player.get_player_controller().teleport.rpc_id(at_table[i], places[chosen[i]].global_position)
	var game := play_game(at_table.size())
	_say_all.rpc(line_lock)
	_start_game.rpc(at_table, chosen, game)

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

## The game is over: cards are lost or won.
func _settle() -> void:
	for i in range(seated.size()):
		var player := _player(seated[i])
		if player == null:
			continue
		var hand = player.get_node("PowerupManager")
		if results[i] == LOSE_ALL:
			hand.take_all_cards.rpc_id(seated[i])
		for k in range(maxi(results[i], 0)):
			hand.grant_card.rpc_id(seated[i], PowerupDefs.random_id())
	var losers := results.count(LOSE_ALL)
	var line := line_all_lose if losers == results.size() else (line_all_win if losers == 0 else line_mixed)
	_set_phase.rpc(Phase.RESULT, result_seconds, line)

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
		_game_over()
		_update_hud()

@rpc("authority", "call_local", "reliable")
func _say_all(line: String) -> void:
	_say(line)

@rpc("authority", "call_local", "reliable")
func _start_game(players: Array[int], seat_numbers: Array[int], game: Dictionary) -> void:
	seated = players
	seats = seat_numbers
	results.assign(game.get("results", []))
	phase = Phase.PLAYING
	phase_ends_msec = Time.get_ticks_msec() + int(float(game.get("seconds", 0.0)) * 1000.0)
	_game_started(game)
	if seated.has(multiplayer.get_unique_id()):
		_open_hud()

@rpc("authority", "call_local", "reliable")
func _clear_table() -> void:
	_game_cleared()
	if is_instance_valid(table):
		table.queue_free()
	table = null
	if is_instance_valid(_zone):
		_zone.queue_free()
	if is_instance_valid(_hud):
		_hud.queue_free()
	# Something to come back for: the room's card area starts.
	for spawner in map.find_children("*", "PowerupSpawner", true, false):
		if not spawner.enabled and map.room_of(spawner) == room:
			spawner.set_enabled(true)

func _say(line: String) -> void:
	if line != "" and is_instance_valid(_bubble):
		_bubble.push(line)

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
	_hud_title = UiPalette.label(game_name, UiPalette.M, UiPalette.GOLD)
	_hud_title.uppercase = true
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_title)
	_hud_line = UiPalette.label("", UiPalette.S, UiPalette.TEXT)
	_hud_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hud_line)

## The game calls this when what it shows changes.
func _update_hud() -> void:
	if not is_instance_valid(_hud):
		return
	var mine := seated.find(multiplayer.get_unique_id())
	if mine < 0:
		return
	_hud_line.text = hud_line(mine)
	if phase == Phase.RESULT:
		var result := results[mine]
		if result == LOSE_ALL:
			_hud_title.text = "You lose your cards"
		elif result == KEEP:
			_hud_title.text = "You keep your cards"
		else:
			_hud_title.text = "You win %d card%s" % [result, "" if result == 1 else "s"]
		_hud_title.add_theme_color_override("font_color", UiPalette.BAD if result == LOSE_ALL else UiPalette.GOOD)

func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()

# --- Strip under the clock -------------------------------------------------------------

func status_text() -> String:
	match phase:
		Phase.OPEN:
			return "" # the strip shows the time until the doors shut
		Phase.PLAYING:
			return status_playing
		Phase.RESULT:
			return "paying out"
	return "closed"

func time_left() -> float:
	if phase != Phase.OPEN:
		return -1.0
	return maxf((phase_ends_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
