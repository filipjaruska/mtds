extends RefCounted
class_name Interactables
## Only one thing at a time takes the interact key: the nearest of the things
## the local player stands at (weapon and card pickups, Shady Fella...).
## Each of them calls enter() / leave() as the local player comes and goes,
## shows its prompt only while focused(), and reacts to the interact key only
## then. Local to each game; nothing here is networked.

static var _near: Array[Node2D] = []
static var _player: Node2D = null
static var _focus: Node2D = null
static var _frame := -1

## The local player is now close enough to use `thing`.
static func enter(thing: Node2D, player: Node2D) -> void:
	if not _near.has(thing):
		_near.append(thing)
	_player = player
	_frame = -1

static func leave(thing: Node2D) -> void:
	_near.erase(thing)
	_frame = -1

## True for the one nearest thing (worked out once per frame).
static func focused(thing: Node2D) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_near = _near.filter(func(n): return is_instance_valid(n) and n.is_inside_tree())
		_focus = null
		if is_instance_valid(_player):
			var best := INF
			for candidate in _near:
				var distance := candidate.global_position.distance_squared_to(_player.global_position)
				if distance < best:
					best = distance
					_focus = candidate
	return thing == _focus
