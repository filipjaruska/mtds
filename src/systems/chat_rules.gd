extends RefCounted
class_name ChatRules
## Pure helpers for in-match chat: cleaning text, the host's spam guard, the
## typewriter timing, the per-player message queue and the top bar's layout.
## Nothing here touches nodes or the network.

const RULES: GameRules = preload("res://src/game_rules.tres") # tuning numbers, edit in the inspector

static var MAX_LENGTH: int = RULES.chat_max_length
## Host spam guard: at most this many messages per window, per player.
static var RATE_COUNT: int = RULES.chat_rate_count
static var RATE_WINDOW_MSEC: int = int(RULES.chat_rate_window_seconds * 1000.0)
## Typewriter speed and how long a revealed message stays up.
static var CHARS_PER_SECOND: float = RULES.chat_chars_per_second
static var HOLD_BASE: float = RULES.chat_hold_seconds
static var HOLD_PER_CHAR: float = RULES.chat_hold_per_char
static var FADE_SECONDS: float = RULES.chat_fade_seconds
## Messages waiting behind the one being shown.
static var MAX_QUEUED: int = RULES.chat_max_queued

## Printable single-line text, whitespace collapsed, at most MAX_LENGTH
## characters; "" when nothing is left.
static func sanitize(text: String) -> String:
	var out := ""
	var last_space := true
	for i in range(text.length()):
		var code := text.unicode_at(i)
		var is_space := code == 32 or code == 9 or code == 10 or code == 13
		if is_space:
			if not last_space:
				out += " "
			last_space = true
			continue
		if code < 32 or code == 127:
			continue # other control characters
		out += char(code)
		last_space = false
	return out.strip_edges().left(MAX_LENGTH).strip_edges()

## Host: may this player send now? `recent` holds the msec of their last
## messages. Returns {allowed: bool, recent: Array} (recent trimmed, plus now if allowed).
static func rate_ok(recent: Array, now: int) -> Dictionary:
	var kept: Array = recent.filter(func(t): return now - int(t) < RATE_WINDOW_MSEC)
	if kept.size() >= RATE_COUNT:
		return {"allowed": false, "recent": kept}
	kept.append(now)
	return {"allowed": true, "recent": kept}

static func reveal_seconds(text: String) -> float:
	return text.length() / CHARS_PER_SECOND

static func hold_seconds(text: String) -> float:
	return HOLD_BASE + HOLD_PER_CHAR * text.length()

## Adds a message behind the waiting ones; when full the oldest waiting one is dropped.
static func enqueue(queue: Array, text: String) -> Array:
	var next := queue.duplicate()
	next.append(text)
	while next.size() > MAX_QUEUED:
		next.pop_front()
	return next

## Which side of the clock each player's icon goes on.
## Teams: Red left, Blue right. Deathmatch: sorted ids alternate left/right.
## Returns {left: Array[int], right: Array[int]}, each in id order.
static func bar_sides(players: Dictionary, team_mode: bool) -> Dictionary:
	var ids := players.keys()
	ids.sort()
	var left: Array[int] = []
	var right: Array[int] = []
	for i in range(ids.size()):
		var id: int = ids[i]
		var goes_left := TeamRules.team_of(players, id) == 0 if team_mode else i % 2 == 0
		if goes_left:
			left.append(id)
		else:
			right.append(id)
	return {"left": left, "right": right}
