extends GameEvent
class_name ShadyFellaEvent
## Shady Fella: a man in a long coat who wanders the map with a few cards
## (never call him "dealer"; that is the blackjack table's).
##   - Walk up to him and press interact: pick one of his cards. While you
##     choose he waits; you can still be shot. Walking away, getting hurt or
##     taking too long closes the choice. The next player may take one of the
##     cards left; each player gets one.
##   - Shoot him: one of his cards drops where he stands and he runs off.
##   - He leaves when his cards are gone or after a while.
## The host runs him (ShadyFellaRules decide); his position is synced by the
## scene's MultiplayerSynchronizer, everything else by the RPCs below.

const RULES: GameRules = preload("res://src/game_rules.tres")
const State := ShadyFellaRules.State
const DIALOG := preload("res://src/entities/npcs/shady_fella/shady_fella_dialog.gd")
const LINES_HELLO := ["Psst. Cards. Cheap.", "Looking for an edge?", "Don't tell anyone where you got these."]
const LINES_HIT := ["Not the face!", "Alright, alright!", "You'll regret that!"]
const LINES_BYE := ["Pleasure doing business.", "Gotta run.", "I was never here."]

## Every peer: what he does now and the cards he still has.
var state: State = State.ROAMING
var offer: Array[StringName] = []

@onready var fella: CharacterBody2D = $Fella
@onready var _reach: Area2D = $Fella/Reach
@onready var _prompt: Label = $Fella/Prompt
@onready var _name: Label = $Fella/Name

# Host only.
var _chooser := 0
var _chooser_since := 0
var _picked := {}
var _path := PackedVector2Array()
var _pause_until := 0
var _leave_at := 0
var _flee_from := Vector2.ZERO
var _flee_until := 0

# The local player's side.
var _local_player: Node2D = null
var _dialog: CanvasLayer = null
var _bubble: ChatBubbleView

func _ready() -> void:
	_reach.body_entered.connect(_on_body_entered)
	_reach.body_exited.connect(_on_body_exited)
	_prompt.visible = false
	UiPalette.world_text(_name, UiPalette.S, UiPalette.TEXT_DIM)
	_bubble = ChatBubbleView.create(14, 200.0, ChatBubbleView.Align.CENTER, true)
	_bubble.position = Vector2(0, -60)
	fella.add_child(_bubble)
	super._ready()

# --- Host: running him -------------------------------------------------------------

func begin() -> void:
	var start := map.random_walkable_point(rng, _fallback_spot())
	var cards := ShadyFellaRules.roll_offer(PowerupDefs.ids(), RULES.shady_offer_size, rng)
	_leave_at = Time.get_ticks_msec() + int(RULES.shady_stay_seconds * 1000.0)
	_appear.rpc(start, cards, LINES_HELLO[rng.randi_range(0, LINES_HELLO.size() - 1)])

## Maps without a walk grid (test arenas): next to the first spawn point.
func _fallback_spot() -> Vector2:
	var spawns := map.spawn_points()
	return (map._map_point(spawns[0]) + Vector2(200, 0)) if not spawns.is_empty() else Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or map == null:
		return
	var now := Time.get_ticks_msec()
	match state:
		State.ROAMING:
			if now >= _leave_at:
				_leave(LINES_BYE[0])
				return
			_wander(now, delta, RULES.shady_speed)
		State.BUSY:
			fella.velocity = Vector2.ZERO
			var chooser := _player(_chooser)
			if chooser == null or now - _chooser_since > int((RULES.shady_choose_seconds + 1.0) * 1000.0) \
					or chooser.global_position.distance_to(fella.global_position) > RULES.shady_reach * 1.5:
				_end_choice()
		State.FLEEING, State.LEAVING:
			if now >= _flee_until:
				finish()
				return
			_run(delta, RULES.shady_speed * (1.8 if state == State.FLEEING else 1.0))

## Walk a path to a random spot, rest a moment, pick another.
func _wander(now: int, delta: float, speed: float) -> void:
	if _path.is_empty():
		if now < _pause_until:
			return
		_path = map.find_path(fella.position, map.random_walkable_point(rng, fella.position))
		_pause_until = now + rng.randi_range(800, 2200)
		return
	_follow(delta, speed)

func _follow(delta: float, speed: float) -> void:
	var next := _path[0]
	var step := next - fella.position
	if step.length() <= speed * delta:
		fella.position = next
		_path.remove_at(0)
		if _path.is_empty():
			_pause_until = Time.get_ticks_msec() + rng.randi_range(800, 2200)
		return
	fella.velocity = step.normalized() * speed
	fella.move_and_slide()

## Away from whoever shot him (or just away), along the walk grid.
func _run(delta: float, speed: float) -> void:
	if _path.is_empty():
		var best := fella.position
		var best_distance := -1.0
		for i in range(6):
			var spot := map.random_walkable_point(rng, fella.position)
			var distance := spot.distance_to(_flee_from)
			if distance > best_distance:
				best_distance = distance
				best = spot
		_path = map.find_path(fella.position, best)
		if _path.is_empty():
			return
	_follow(delta, speed)

func _player(peer: int) -> Node2D:
	return map.get_node_or_null(str(peer)) as Node2D if peer > 0 else null

func _hand_has_room(peer: int) -> bool:
	var player := _player(peer)
	var cards := player.get_node_or_null("PowerupManager") if player else null
	return cards != null and cards.host_has_free_slot()

func _distance_to(peer: int) -> float:
	var player := _player(peer)
	return player.global_position.distance_to(fella.global_position) if player else INF

## Host: a shot or a blade hit him. One card drops, he runs.
func on_hit(_amount: float, shooter_id: int) -> void:
	if not multiplayer.is_server() or state == State.FLEEING or state == State.LEAVING:
		return
	var dropped := ShadyFellaRules.dropped_card(offer, rng)
	if dropped != &"":
		map.spawn_card_pickup(dropped, fella.position)
	var shooter := _player(shooter_id)
	_flee_from = shooter.global_position if shooter else fella.position
	_close_choice()
	_flee_until = Time.get_ticks_msec() + int(RULES.shady_flee_seconds * 1000.0)
	_path = PackedVector2Array()
	_set_state.rpc(State.FLEEING, [] as Array[StringName], LINES_HIT[rng.randi_range(0, LINES_HIT.size() - 1)])

func _leave(line: String) -> void:
	_close_choice()
	_flee_from = fella.position
	_flee_until = Time.get_ticks_msec() + int(RULES.shady_flee_seconds * 1000.0)
	_path = PackedVector2Array()
	_set_state.rpc(State.LEAVING, offer, line)

func _close_choice() -> void:
	if _chooser != 0:
		_close_dialog.rpc_id(_chooser)
	_chooser = 0

func _end_choice() -> void:
	_close_choice()
	_set_state.rpc(State.ROAMING, offer, "")

# --- Trading (player -> host -> player) ------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_open() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var refusal := ShadyFellaRules.open_refusal(state, _chooser, peer, _picked, offer,
		_distance_to(peer), RULES.shady_reach, _hand_has_room(peer))
	if refusal != "":
		_refused.rpc_id(peer, refusal)
		return
	_chooser = peer
	_chooser_since = Time.get_ticks_msec()
	_path = PackedVector2Array()
	_set_state.rpc(State.BUSY, offer, "")
	_open_dialog.rpc_id(peer, offer)

@rpc("any_peer", "call_local", "reliable")
func request_pick(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not ShadyFellaRules.can_pick(state, _chooser, peer, offer, index, _distance_to(peer), RULES.shady_reach * 1.5, _hand_has_room(peer)):
		return
	var card: StringName = offer[index]
	var left := offer.duplicate()
	left.remove_at(index)
	_picked[peer] = true
	_player(peer).get_node("PowerupManager").grant_card.rpc_id(peer, card)
	_close_choice()
	if left.is_empty():
		offer = left
		_leave(LINES_BYE[rng.randi_range(0, LINES_BYE.size() - 1)])
	else:
		_set_state.rpc(State.ROAMING, left, "")

@rpc("any_peer", "call_local", "reliable")
func request_close() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == _chooser:
		_end_choice()

# --- Host -> everyone ----------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _appear(at: Vector2, cards: Array[StringName], line: String) -> void:
	fella.position = at
	offer = cards
	_say(line)
	var tween := create_tween()
	fella.modulate.a = 0.0
	tween.tween_property(fella, "modulate:a", 1.0, 0.4)

@rpc("authority", "call_local", "reliable")
func _set_state(new_state: State, cards: Array[StringName], line: String) -> void:
	state = new_state
	offer = cards
	_say(line)
	if state == State.FLEEING or state == State.LEAVING:
		_close_local_dialog()
		create_tween().tween_property(fella, "modulate:a", 0.0, RULES.shady_flee_seconds).set_ease(Tween.EASE_IN)
	elif _dialog:
		_dialog.show_offer(offer)

func _say(line: String) -> void:
	if line != "":
		_bubble.push(line)

# --- Host -> the player choosing --------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _open_dialog(cards: Array[StringName]) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_close_local_dialog()
	_dialog = DIALOG.new()
	_dialog.offer = cards
	_dialog.picked.connect(func(index): request_pick.rpc_id(1, index))
	_dialog.closed.connect(func(): request_close.rpc_id(1))
	add_child(_dialog)

@rpc("any_peer", "call_local", "reliable")
func _close_dialog() -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_close_local_dialog()

func _close_local_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null

@rpc("any_peer", "call_local", "reliable")
func _refused(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	match reason:
		"already picked":
			_say("One per customer.")
		"busy":
			_say("Wait your turn.")
		"hands full":
			_say("Your hands are full, pal.")

# --- The local player ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if is_instance_valid(_dialog) and _local_player:
		var away := _local_player.global_position.distance_to(fella.global_position) > RULES.shady_reach * 1.3
		if away:
			_dialog.close()
	var near := _local_player != null and is_instance_valid(_local_player)
	var can_trade := near and (state == State.ROAMING or state == State.BUSY) and not offer.is_empty()
	var focused := can_trade and Interactables.focused(fella)
	_prompt.visible = focused and not is_instance_valid(_dialog)
	if focused and not is_instance_valid(_dialog) and InputManager.is_interact_pressed():
		request_open.rpc_id(1)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and body.is_multiplayer_authority():
		_local_player = body
		Interactables.enter(fella, body)
		_prompt.text = "[%s] Trade" % GameSettings.get_action_binding_text("interact")

func _on_body_exited(body: Node) -> void:
	if body == _local_player:
		_local_player = null
		Interactables.leave(fella)

func _exit_tree() -> void:
	Interactables.leave(fella)
	_close_local_dialog()

# --- Strip under the clock -------------------------------------------------------------

func status_text() -> String:
	match state:
		State.FLEEING:
			return "running off"
		State.LEAVING:
			return "leaving"
	return "%d card%s" % [offer.size(), "" if offer.size() == 1 else "s"]

func time_left() -> float:
	if state == State.FLEEING or state == State.LEAVING:
		return 0.0
	return maxf((started_msec + RULES.shady_stay_seconds * 1000.0 - Time.get_ticks_msec()) / 1000.0, 0.0)
