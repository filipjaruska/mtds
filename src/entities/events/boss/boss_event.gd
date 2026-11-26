extends GameEvent
class_name BossEvent
## A boss fight (Tutankhamun...). For most of the match his lair is an ordinary
## room with a prop in it (BossLair). When this event starts the lair opens and
## he steps out:
##   - for a while he is held in his lair (he walks about in it and shoots
##     anyone he sees, also through the doorways);
##   - if he is still standing after that, he roams the map and hunts players
##     (with Held Seconds below 0 he never leaves: a guard);
##   - he fights with a weapon (a WeaponDef: its damage, fire, burn...);
##   - killed, he drops a weapon and cards.
## A new boss is a new scene (look, name, lines, numbers) with this script; see
## tutankhamun/tutankhamun.tscn. The scene needs: Body (NpcBody) with Look
## (Look/Weapon turns to aim), Name, HealthBar/Fill, and a MultiplayerSynchronizer
## on Body:position and Body/Look/Weapon:rotation.
## The host runs him (BossRules decide); everything else goes by the RPCs below.

const State := BossRules.State
## When his lair is in no room (test maps): held within this area round it.
const FALLBACK_LAIR_SIZE := Vector2(640, 640)

@export var boss_name: String = "Tutankhamun"
## The lair he wakes in (BossLair.boss).
@export var lair: StringName = &"tutankhamun"
@export_group("Numbers")
@export_range(50.0, 5000.0, 10.0, "suffix:HP") var hp_max: float = 500.0
## How fast he walks (players run at about 200).
@export_range(20.0, 400.0, 5.0, "suffix:px/s") var speed: float = 110.0
## How long he is held in his lair after he wakes. Below 0: always (a guard).
@export_range(-1.0, 600.0, 5.0, "suffix:s") var held_seconds: float = 60.0
## How far he sees (and shoots).
@export_range(100.0, 1500.0, 10.0, "suffix:px") var sight: float = 650.0
## Time between his shots.
@export_range(0.2, 5.0, 0.05, "suffix:s") var fire_seconds: float = 1.2
## Hunting: he walks up to this distance, then stands and shoots.
@export_range(50.0, 1000.0, 10.0, "suffix:px") var keep_distance: float = 320.0
@export_group("Weapon and drops")
## What he fights with (a WeaponDef id: its damage, speed, burn...).
@export var weapon: StringName = &"pharaoh_staff"
## The weapon he drops when killed (empty: none).
@export var drop_weapon: StringName = &"pharaoh_staff"
## The cards he drops when killed.
@export var drop_cards: Array[StringName] = [&"swift_feet"]
@export_group("Lines")
@export var lines_wake: Array[String] = ["Who disturbs my sleep?"]
@export var lines_free: Array[String] = ["No tomb can hold me!"]
@export var lines_die: Array[String] = ["My curse... lives on..."]

## Every peer.
var state: State = State.BOUND
var hp: float = 0.0
var free_at_msec := 0 # this machine's clock; -1: never

@onready var body: CharacterBody2D = $Body
@onready var _weapon: Node2D = $Body/Look/Weapon
@onready var _hp_fill: ColorRect = $Body/HealthBar/Fill
@onready var _name: Label = $Body/Name

var home: BossLair
## The area he is held in (his lair's room).
var held_area: Rect2

# Host only.
var _path := PackedVector2Array()
var _stuck_seconds := 0.0
var _pause_until := 0
var _next_shot := 0
var _next_look := 0
var _target := 0
var _bubble: ChatBubbleView

func _ready() -> void:
	hp = hp_max
	_name.text = boss_name
	home = _find_lair()
	if home:
		var room := map.room_of(home)
		if room:
			var used := room.used_rect()
			held_area = Rect2(room.global_position + Vector2(used.position) * MapRoom.TILE, Vector2(used.size) * MapRoom.TILE)
		else:
			held_area = Rect2(home.global_position - FALLBACK_LAIR_SIZE * 0.5, FALLBACK_LAIR_SIZE)
	UiPalette.world_text(_name, UiPalette.S, UiPalette.GOLD)
	_bubble = ChatBubbleView.create(14, 220.0, ChatBubbleView.Align.CENTER, true)
	var anchor := Node2D.new()
	anchor.position = Vector2(0, -42)
	body.add_child(anchor)
	anchor.add_child(_bubble)
	body.visible = false
	super._ready()

func _find_lair() -> BossLair:
	if map == null:
		return null
	for found in map.find_children("*", "BossLair", true, false):
		if found.boss == lair:
			return found
	return null

func _line(lines: Array[String]) -> String:
	return lines[rng.randi_range(0, lines.size() - 1)] if not lines.is_empty() else ""

# --- Host: running him -------------------------------------------------------------

func begin() -> void:
	if home == null:
		push_warning("%s: the map has no BossLair for \"%s\"." % [boss_name, lair])
		finish.call_deferred()
		return
	_wake.rpc(home.wake_position(), held_seconds, _line(lines_wake))

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or map == null or home == null or state == State.DEAD:
		return
	var now := Time.get_ticks_msec()
	if state == State.BOUND and BossRules.next_state(state, hp, now, free_at_msec) == State.ROAMING:
		_path = PackedVector2Array()
		_set_state.rpc(State.ROAMING, _line(lines_free))
	if now >= _next_look:
		_next_look = now + 200
		_target = _find_target()
	var target := _player(_target)
	if target:
		_aim_at(target.global_position)
		if now >= _next_shot:
			_next_shot = now + int(fire_seconds * 1000.0)
			_fire(target.global_position)
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
		var seen := space.intersect_ray(query).is_empty()
		candidates.append({"id": player.get_multiplayer_authority(), "position": player.global_position, "visible": seen})
	return BossRules.pick_target(body.global_position, candidates, sight)

func _aim_at(point: Vector2) -> void:
	_weapon.rotation = (point - body.global_position).angle()

func _fire(point: Vector2) -> void:
	var combat: CombatServer = map.get_node_or_null("Combat")
	if combat == null:
		return
	var aim := (point - body.global_position).angle() + deg_to_rad(rng.randf_range(-3.0, 3.0))
	var origin := body.global_position + Vector2.RIGHT.rotated(aim) * 44.0
	combat.npc_fire(origin, PackedFloat32Array([aim]), weapon, [body.get_rid()])

## Walk to a random spot (inside his lair while he is held there), rest, repeat.
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
			if held_area.grow(-MapRoom.TILE).has_point(spot):
				return spot
		return body.position
	return map.random_walkable_point(rng, body.position)

## Roaming with someone in sight: close in, then stand and shoot.
func _hunt(now: int, delta: float, target: Vector2) -> void:
	if not BossRules.should_close_in(body.position, target, keep_distance):
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
	if step.length() <= speed * delta:
		body.position = next
		_path.remove_at(0)
		return
	body.velocity = step.normalized() * speed
	body.move_and_slide()
	# Pushed against something the walk grid does not know: try another way.
	_stuck_seconds = _stuck_seconds + delta if body.get_real_velocity().length() < speed * 0.2 else 0.0
	if _stuck_seconds > 0.6:
		_stuck_seconds = 0.0
		_path = PackedVector2Array()
	if state == State.BOUND and not held_area.has_point(body.global_position):
		body.global_position = body.global_position.clamp(held_area.position + Vector2.ONE * 40.0, held_area.end - Vector2.ONE * 40.0)
		_path = PackedVector2Array()

func _player(peer: int) -> Node2D:
	return map.get_node_or_null(str(peer)) as Node2D if peer > 0 else null

## Host: whether shots hit him (NpcBody asks).
func is_hittable() -> bool:
	return state != State.DEAD

## Host: a shot or a blade hit him.
func on_hit(amount: float, _shooter_id: int) -> void:
	if not multiplayer.is_server() or state == State.DEAD:
		return
	hp = maxf(hp - amount, 0.0)
	if hp > 0.0:
		_sync_hp.rpc(hp)
		return
	var at := body.position
	var drops: Array = ([drop_weapon] if drop_weapon != &"" else []) + Array(drop_cards)
	for i in range(drops.size()):
		var spot := at + Vector2((i - (drops.size() - 1) * 0.5) * 112.0, 0)
		if i == 0 and drop_weapon != &"":
			map.spawn_weapon_pickup(drop_weapon, spot)
		else:
			map.spawn_card_pickup(drops[i], spot)
	_set_state.rpc(State.DEAD, _line(lines_die))
	get_tree().create_timer(2.5).timeout.connect(finish)

# --- Host -> everyone ----------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _wake(at: Vector2, held: float, line: String) -> void:
	free_at_msec = Time.get_ticks_msec() + int(held * 1000.0) if held >= 0.0 else -1
	state = State.BOUND
	body.global_position = at
	body.visible = true
	body.collision_layer = CombatServer.NPC_LAYER
	body.modulate.a = 0.0
	create_tween().tween_property(body, "modulate:a", 1.0, 0.8)
	if home:
		home.open()
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
	body.self_modulate = Color(1.8, 1.2, 1.2)
	create_tween().tween_property(body, "self_modulate", Color.WHITE, 0.15)

func _show_hp() -> void:
	var back := _hp_fill.get_parent() as Control
	_hp_fill.size.x = back.size.x * clampf(hp / hp_max, 0.0, 1.0)

func _say(line: String) -> void:
	if line != "":
		_bubble.push(line)

# --- Strip under the clock -------------------------------------------------------------

func status_text() -> String:
	match state:
		State.BOUND:
			return "" if free_at_msec >= 0 else "%d HP" % ceili(hp) # how long he is held, or his health
		State.ROAMING:
			return "roaming, %d HP" % ceili(hp)
	return "defeated"

func time_left() -> float:
	if state != State.BOUND or free_at_msec < 0:
		return -1.0
	return maxf((free_at_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
