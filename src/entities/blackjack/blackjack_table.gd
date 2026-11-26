@tool
extends Node2D
class_name BlackjackTable
## The blackjack table and its dealer. Put it in the map's blackjack room: a
## semi-permanent MapRoom whose gate the event opens (BlackjackEvent.gate,
## "blackjack"). The event seats the players at the Seats markers, lays each
## hand at the seat's Cards marker and the dealer's at DealerCards, and talks
## through the dealer. When the game is over the table is taken away and the
## room stays open as a normal room.
##
## The look is placeholder art: a table image and the dealer stacked from icons.

func seats() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in get_node("Seats").get_children():
		if child is Node2D:
			out.append(child)
	return out

## Where seat `index`'s cards lie, in global coordinates.
func card_spot(index: int) -> Vector2:
	var seat: Node2D = seats()[index]
	var spot := seat.get_node_or_null("Cards") as Node2D
	return spot.global_position if spot else seat.global_position.lerp(global_position, 0.5)

func dealer_card_spot() -> Vector2:
	return ($DealerCards as Node2D).global_position

func dealer() -> Node2D:
	return $Dealer

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not has_node("Seats") or get_node("Seats").get_child_count() == 0:
		warnings.append("Needs a Seats node with a Marker2D per seat.")
	if not has_node("DealerCards") or not has_node("Dealer"):
		warnings.append("Needs the Dealer and DealerCards nodes.")
	var room := get_parent()
	while room and not room is MapRoom:
		room = room.get_parent()
	if room == null or not room.gated:
		warnings.append("Put it in a semi-permanent room (a MapRoom with Gated on and the gate the event opens, \"blackjack\").")
	return warnings
