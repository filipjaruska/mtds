extends PanelContainer
class_name PodiumCard
## One of the top three on the results screen. Taller for a better place, so
## the row reads as a podium (cards sit on a shared baseline).

const HEIGHTS := {1: 270.0, 2: 240.0, 3: 215.0}

## row: a "player" row from ResultsFormat.rows().
func show_player(row: Dictionary, place: int, color: Color, is_me: bool) -> void:
	theme_type_variation = &"PodiumCardFirst" if place == 1 else &"PodiumCard"
	custom_minimum_size.y = HEIGHTS.get(place, 215.0)
	$VBox/Place.text = ResultsFormat.ordinal(place)
	$VBox/Place.add_theme_color_override("font_color", UiPalette.ACCENT if place == 1 else UiPalette.TEXT_DIM)
	$VBox/Icon.modulate = color
	$VBox/Name.text = row.name + ("  (you)" if is_me else "")
	$VBox/Damage.text = str(row.damage)
	$VBox/Line.text = "%d %s  ·  %d %s" % [row.kills, "kill" if row.kills == 1 else "kills", row.deaths, "death" if row.deaths == 1 else "deaths"]
