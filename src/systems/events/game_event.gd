extends Node2D
class_name GameEvent
## Base of every in-game event (Shady Fella, the blackjack table...). The
## EventDirector creates the event's scene on every peer with the same name, so
## the event's own RPCs reach it everywhere; the host runs it and tells the
## others what happens. When it is over the host calls finish().
##
## Override:
##   begin()          host: set up (choose a place, roll cards) and sync it
##   status_text()    a few words for the strip under the clock ("2 cards left")
##   time_left()      seconds until it ends, or -1 when it has no set end

## The spec it was started from (name, icon, timing).
var spec: EventSpec
## The map it runs on.
var map: GameMap
## Host only: random numbers for this event.
var rng := RandomNumberGenerator.new()
## When it started, on this machine's clock.
var started_msec := 0

func _ready() -> void:
	started_msec = Time.get_ticks_msec()
	if multiplayer.is_server():
		rng.randomize()
		begin()

## Host: set the event up. Sync what other peers need through the event's RPCs.
func begin() -> void:
	pass

func status_text() -> String:
	return ""

func time_left() -> float:
	return -1.0

## Host: the event is over; it is removed on every peer.
func finish() -> void:
	if multiplayer.is_server():
		var director := get_parent() as EventDirector
		if director:
			director.end_event(self)
