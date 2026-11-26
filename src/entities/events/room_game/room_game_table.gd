@tool
extends Node2D
class_name RoomGameTable
## The table of a room game (the blackjack table...) and the NPC who runs it.
## Put it in the game's room: a semi-permanent MapRoom whose gate the event
## opens (RoomGameEvent.gate). The event seats the players at the Seats
## markers, lays each player's things (cards...) at the seat's Spot marker and
## the host's at HostSpot, and talks through the Host. When the game is over
## the table is taken away and the room stays open as a normal room.
##
## Needs: Seats (a Marker2D per seat, each with a Spot child), Host (the NPC's
## look) and HostSpot.

func seats() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in get_node("Seats").get_children():
		if child is Node2D:
			out.append(child)
	return out

## Where seat `index`'s things lie, in global coordinates.
func seat_spot(index: int) -> Vector2:
	var seat: Node2D = seats()[index]
	var spot := seat.get_node_or_null("Spot") as Node2D
	return spot.global_position if spot else seat.global_position.lerp(global_position, 0.5)

func host_spot() -> Vector2:
	return ($HostSpot as Node2D).global_position

func host() -> Node2D:
	return $Host

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not has_node("Seats") or get_node("Seats").get_child_count() == 0:
		warnings.append("Needs a Seats node with a Marker2D per seat (each with a Spot child).")
	if not has_node("HostSpot") or not has_node("Host"):
		warnings.append("Needs the Host and HostSpot nodes.")
	var room := get_parent()
	while room and not room is MapRoom:
		room = room.get_parent()
	if room == null or not room.gated:
		warnings.append("Put it in a semi-permanent room (a MapRoom with Gated on and the gate its event opens).")
	return warnings
