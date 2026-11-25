@tool
extends Resource
class_name EventSpec
## One kind of in-game event on a map (set in the map root's Events list):
## what it is, when it may happen and how it shows in the strip under the
## clock. The event itself is a scene whose root extends GameEvent.

## The event scene (its root extends GameEvent).
@export var scene: PackedScene
## Name in the strip under the clock ("Shady Fella").
@export var display_name: String = ""
## Icon in the strip (optional).
@export var icon: Texture2D
@export_group("When")
## The first one starts this many seconds into the match, at random between
## the two.
@export_range(0.0, 1800.0, 5.0, "suffix:s") var first_after_min: float = 60.0
@export_range(0.0, 1800.0, 5.0, "suffix:s") var first_after_max: float = 120.0
## Then another one this often (the time counts from when the last one started).
@export_range(5.0, 1800.0, 5.0, "suffix:s") var every_min: float = 120.0
@export_range(5.0, 1800.0, 5.0, "suffix:s") var every_max: float = 180.0
## Chance that it happens when its time comes (otherwise it waits for the next).
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
## How many may run at once.
@export_range(1, 8) var max_active: int = 1
## How many per match. 0 = no limit.
@export_range(0, 50) var max_runs: int = 0
@export_group("Strip")
## How long one usually lasts, for the bar in the strip. 0 = until it is over
## (the strip shows the event's own status instead, like cards left).
@export_range(0.0, 600.0, 1.0, "suffix:s") var lasts_seconds: float = 0.0
