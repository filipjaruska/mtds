extends Node2D
class_name EventDirector
## Runs a map's in-game events (GameMap.events). The map adds it as "Events"
## on every peer. The host decides when each event starts, by the event specs'
## timing and chance, and starts it on every peer as Events/Event_<n>; every
## peer knows what comes next (for the strip under the clock).
##
## Debug builds: F9 on the host starts the next event right away.

var specs: Array[EventSpec] = []
## Every peer: the events running now.
var active: Array[GameEvent] = []
## Every peer: the next event to come (index into specs, -1: none), when it
## starts on this machine's clock, and how long the wait was when announced.
var next_index := -1
var next_at_msec := 0
var next_wait := 0.0

# Host only.
var _next_start: Array[float] = [] # match seconds when each spec is due
var _runs: Array[int] = []
var _count := 0
var _rng := RandomNumberGenerator.new()
var _announced := [-1, -1.0]

func _ready() -> void:
	if not multiplayer.is_server():
		return
	_rng.randomize()
	for spec in specs:
		_next_start.append(_rng.randf_range(spec.first_after_min, maxf(spec.first_after_min, spec.first_after_max)))
		_runs.append(0)

func _elapsed() -> float:
	return GameManager.get_match_duration() - GameManager.match_time_remaining

func _process(_delta: float) -> void:
	if not multiplayer.is_server() or specs.is_empty():
		return
	if not GameManager.is_state(GameManager.GameState.PLAYING) or GameManager.tutorial_mode:
		return
	var now := _elapsed()
	for i in range(specs.size()):
		if now >= _next_start[i] and _can_run(i):
			if _rng.randf() < specs[i].chance:
				start_now(i)
			_next_start[i] = now + _wait(specs[i])
	_announce_next(now)

func _can_run(index: int) -> bool:
	var spec := specs[index]
	if spec.max_runs > 0 and _runs[index] >= spec.max_runs:
		return false
	return active.filter(func(e): return e.spec == spec).size() < spec.max_active

func _wait(spec: EventSpec) -> float:
	return _rng.randf_range(spec.every_min, maxf(spec.every_min, spec.every_max))

## Host: tell everyone which event comes next and when (when that changes).
func _announce_next(now: float) -> void:
	var best := -1
	var best_at := INF
	for i in range(specs.size()):
		if specs[i].max_runs > 0 and _runs[i] >= specs[i].max_runs:
			continue
		if _next_start[i] < best_at:
			best_at = _next_start[i]
			best = i
	var seconds := maxf(best_at - now, 0.0) if best >= 0 else 0.0
	if best != _announced[0] or absf((now + seconds) - _announced[1]) > 0.5:
		_announced = [best, now + seconds]
		_sync_next.rpc(best, seconds)

@rpc("authority", "call_local", "reliable")
func _sync_next(index: int, seconds: float) -> void:
	next_index = index
	next_wait = seconds
	next_at_msec = Time.get_ticks_msec() + int(seconds * 1000.0)

## Host: start event `index` now (also for tests and the debug key).
func start_now(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= specs.size():
		return
	_count += 1
	_runs[index] += 1
	_start.rpc(index, _count)

@rpc("authority", "call_local", "reliable")
func _start(index: int, number: int) -> void:
	if index < 0 or index >= specs.size() or specs[index].scene == null:
		return
	var event: GameEvent = specs[index].scene.instantiate()
	event.name = "Event_%d" % number
	event.spec = specs[index]
	event.map = get_parent() as GameMap
	active.append(event)
	add_child(event)
	EventManager.game_event_started.emit(event)

## Host: remove a finished event everywhere.
func end_event(event: GameEvent) -> void:
	if multiplayer.is_server() and is_instance_valid(event):
		_end.rpc(event.name)

@rpc("authority", "call_local", "reliable")
func _end(event_name: String) -> void:
	var event := get_node_or_null(event_name) as GameEvent
	if event == null:
		return
	active.erase(event)
	EventManager.game_event_ended.emit(event)
	event.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and multiplayer.is_server() and event is InputEventKey \
			and event.pressed and not event.echo and event.keycode == KEY_F9:
		var index := next_index if next_index >= 0 else 0
		if _can_run(index):
			start_now(index)
