extends GameEvent
class_name TutankhamunEvent
## Tutankhamun awakens. For most of the match his tomb is an ordinary room
## with a sarcophagus in it (TutankhamunSarcophagus). When this event starts
## the lid slides off and he steps out:
##   - for a minute he is held in his tomb (he walks about in it and shoots
##     anyone he sees, also through the doorways);
##   - if he is still standing after that, he roams the map and hunts players;
##   - his staff throws fireballs: the hit ignores armor and sets the player
##     burning for a few seconds, so their health does not come back;
##   - killed, he drops his staff (the Pharaoh's Staff, a weapon that costs
##     health instead of ammo) and a card.
## The host runs him (TutankhamunRules decide); his position and aim are synced
## by the scene's MultiplayerSynchronizer, everything else by the RPCs below.

const RULES: GameRules = preload("res://src/game_rules.tres")
const State := TutankhamunRules.State
const STAFF := &"pharaoh_staff"
const LINES_WAKE := ["Who disturbs my sleep?", "Three thousand years... and you woke me.", "Kneel before the Pharaoh!"]
const LINES_FREE := ["No tomb can hold me!", "Egypt shall rise again!"]
const LINES_DIE := ["My curse... lives on...", "Not again..."]
## When he is in no room (test maps): held within this distance of his sarcophagus.
const FALLBACK_TOMB_SIZE := Vector2(640, 640)

## Every peer.
var state: State = State.BOUND
var hp: float = 0.0
var free_at_msec := 0 # this machine's clock

@onready var body: CharacterBody2D = $Body
@onready var _staff: Node2D = $Body/Look/Staff
@onready var _hp_fill: ColorRect = $Body/HealthBar/Fill
@onready var _name: Label = $Body/Name

var sarcophagus: TutankhamunSarcophagus
var tomb: Rect2

# Host only.
var _path := PackedVector2Array()
var _pause_until := 0
var _next_shot := 0
var _next_look := 0
var _target := 0
var _bubble: ChatBubbleView

func _ready() -> void:
	hp = RULES.tut_hp
	var found := map.find_children("*", "TutankhamunSarcophagus", true, false) if map else []
	sarcophagus = found[0] if not found.is_empty() else null
	if sarcophagus:
		var room := map.room_of(sarcophagus)
		if room:
			var used := room.used_rect()
			tomb = Rect2(room.global_position + Vector2(used.position) * MapRoom.TILE, Vector2(used.size) * MapRoom.TILE)
		else:
			tomb = Rect2(sarcophagus.global_position - FALLBACK_TOMB_SIZE * 0.5, FALLBACK_TOMB_SIZE)
	UiPalette.world_text(_name, UiPalette.S, UiPalette.GOLD)
	_bubble = ChatBubbleView.create(14, 220.0, ChatBubbleView.Align.CENTER, true)
	var anchor := Node2D.new()
	anchor.position = Vector2(0, -42)
	body.add_child(anchor)
	anchor.add_child(_bubble)
	body.visible = false
	super._ready()

# --- Host: running him -------------------------------------------------------------

func begin() -> void:
	if sarcophagus == null:
		push_warning("Tutankhamun: the map has no TutankhamunSarcophagus.")
		finish.call_deferred()
		return
	_wake.rpc(sarcophagus.wake_position(), RULES.tut_bound_seconds, LINES_WAKE[rng.randi_range(0, LINES_WAKE.size() - 1)])

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or map == null or sarcophagus == null or state == State.DEAD:
		return
	var now := Time.get_ticks_msec()
	if TutankhamunRules.next_state(state, hp, now, free_at_msec) == State.ROAMING and state == State.BOUND:
		_path = PackedVector2Array()
		_set_state.rpc(State.ROAMING, LINES_FREE[rng.randi_range(0, LINES_FREE.size() - 1)])
	if now >= _next_look:
		_next_look = now + 200
		_target = _find_target()
	var target := _player(_target)
	if target:
		_aim_at(target.global_position)
		if now >= _next_shot:
			_next_shot = now + int(RULES.tut_fire_seconds * 1000.0)
			_cast(target.global_position)
	if state == State.ROAMING and target:
		_hunt(now, delta, target.global_position)
	else:
		_wander(now, delta)

## The nearest living player he can see (not in a no-fighting zone).
func _find_target() -> int:
	var space := body.get_world_2d().direct_space_state
	var candidates: Array = []
	for player in get_tree().get_nodes_in_group("Player"):
		var health = player.get_node_or_null("HealthComponent")
		if health == null or health.is_dead or PeaceZone.covers(player):
			continue
		var query := PhysicsRayQueryParameters2D.create(body.global_position, player.global_position, CombatServer.WALL_LAYER, [body.get_rid()])
		var visible := space.intersect_ray(query).is_empty()
		candidates.append({"id": player.get_multiplayer_authority(), "position": player.global_position, "visible": visible})
	return TutankhamunRules.pick_target(body.global_position, candidates, RULES.tut_sight)

func _aim_at(point: Vector2) -> void:
	_staff.rotation = (point - body.global_position).angle()

func _cast(point: Vector2) -> void:
	var combat: CombatServer = map.get_node_or_null("Combat")
	if combat == null:
		return
	var aim := (point - body.global_position).angle() + deg_to_rad(rng.randf_range(-3.0, 3.0))
	var origin := body.global_position + Vector2.RIGHT.rotated(aim) * 44.0
	combat.npc_fire(origin, PackedFloat32Array([aim]), STAFF, [body.get_rid()])

## Walk to a random spot (inside his tomb while he is held there), rest, repeat.
func _wander(now: int, delta: float) -> void:
	if _path.is_empty():
		if now < _pause_until:
			return
		_path = map.find_path(body.position, _wander_spot())
		_pause_until = now + rng.randi_range(600, 1800)
		return
	_follow(delta)

func _wander_spot() -> Vector2:
	if state == State.BOUND:
		for attempt in range(30):
			var spot := map.random_walkable_point(rng, body.position)
			if tomb.grow(-MapRoom.TILE).has_point(spot):
				return spot
		return body.position
	return map.random_walkable_point(rng, body.position)

## Roaming with someone in sight: close in, then stand and shoot.
func _hunt(now: int, delta: float, target: Vector2) -> void:
	if not TutankhamunRules.should_close_in(body.position, target, RULES.tut_keep_distance):
		_path = PackedVector2Array()
		return
	if _path.is_empty() or now >= _pause_until:
		_path = map.find_path(body.position, target)
		_pause_until = now + 500
	if not _path.is_empty():
		_follow(delta)

func _follow(delta: float) -> void:
	var next := _path[0]
	var step := next - body.position
	if step.length() <= RULES.tut_speed * delta:
		body.position = next
		_path.remove_at(0)
		return
	body.velocity = step.normalized() * RULES.tut_speed
	body.move_and_slide()
	if state == State.BOUND and not tomb.has_point(body.global_position):
		body.global_position = body.global_position.clamp(tomb.position + Vector2.ONE * 40.0, tomb.end - Vector2.ONE * 40.0)
		_path = PackedVector2Array()

func _player(peer: int) -> Node2D:
	return map.get_node_or_null(str(peer)) as Node2D if peer > 0 else null

## Host: a shot or a blade hit him.
func on_hit(amount: float, _shooter_id: int) -> void:
	if not multiplayer.is_server() or state == State.DEAD:
		return
	hp = maxf(hp - amount, 0.0)
	if hp > 0.0:
		_sync_hp.rpc(hp)
		return
	var at := body.position
	map.spawn_weapon_pickup(STAFF, at + Vector2(-56, 0))
	map.spawn_card_pickup(RULES.tut_drop_card, at + Vector2(56, 0))
	_set_state.rpc(State.DEAD, LINES_DIE[rng.randi_range(0, LINES_DIE.size() - 1)])
	get_tree().create_timer(2.5).timeout.connect(finish)

# --- Host -> everyone ----------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _wake(at: Vector2, bound_seconds: float, line: String) -> void:
	free_at_msec = Time.get_ticks_msec() + int(bound_seconds * 1000.0)
	state = State.BOUND
	body.global_position = at
	body.visible = true
	body.collision_layer = CombatServer.NPC_LAYER
	body.modulate.a = 0.0
	create_tween().tween_property(body, "modulate:a", 1.0, 0.8)
	if sarcophagus:
		sarcophagus.open()
	_say(line)
	_show_hp()

@rpc("authority", "call_local", "reliable")
func _set_state(new_state: State, line: String) -> void:
	state = new_state
	_say(line)
	if state == State.DEAD:
		hp = 0.0
		_show_hp()
		body.collision_layer = 0
		create_tween().tween_property(body, "modulate:a", 0.0, 2.0).set_delay(0.4)

@rpc("authority", "call_local", "unreliable_ordered")
func _sync_hp(value: float) -> void:
	hp = value
	_show_hp()
	var flash := create_tween()
	body.self_modulate = Color(1.8, 1.2, 1.2)
	flash.tween_property(body, "self_modulate", Color.WHITE, 0.15)

func _show_hp() -> void:
	var back := _hp_fill.get_parent() as Control
	_hp_fill.size.x = back.size.x * clampf(hp / RULES.tut_hp, 0.0, 1.0)

func _say(line: String) -> void:
	if line != "":
		_bubble.push(line)

# --- Strip under the clock -------------------------------------------------------------

func status_text() -> String:
	match state:
		State.BOUND:
			return "" # the strip shows how long he is held in his tomb
		State.ROAMING:
			return "roaming, %d HP" % ceili(hp)
	return "defeated"

func time_left() -> float:
	if state != State.BOUND:
		return -1.0
	return maxf((free_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
