@tool
extends Resource
class_name RoomChoice
## One room a MapSlot may use, and how likely it is.

## A room or block scene (its root is a MapRoom).
@export var scene: PackedScene
## Relative chance against the slot's other choices (2 = twice as likely as 1).
@export_range(0.0, 10.0, 0.1) var weight: float = 1.0
## How many times this room may appear in one map, across all slots. 0 = any.
@export_range(0, 20) var max_per_map: int = 0
