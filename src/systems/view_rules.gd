extends RefCounted
class_name ViewRules
## How much of the world a player sees, and what that means for gun ranges.
##
## Every screen renders the same virtual view (project.godot: viewport
## 1536x864, stretch "canvas_items", aspect "keep_height"), so a 4K monitor sees
## exactly as much of the map as a 1080p one; wider screens only see more
## sideways. Ctrl (crouch) zooms out to CTRL_ZOOM at half speed.
##
## Gun ranges are tied to this view (see range_band, checked by
## tests/test_view_rules.gd):
##   close     ends inside the default view        (shotgun)
##   standard  ends past the default view's edge but inside the Ctrl view
##   marksman  ends just beyond the Ctrl view, even sideways (M1903)
##   melee     arm's reach (katana), measured from the player's centre

const VIEW_SIZE := Vector2(1536, 864)
const CTRL_ZOOM := 0.7
## How far the camera shifts toward where you aim (CameraComponent).
const LOOKAHEAD := 175.0
## Marksman ranges may reach this far past the Ctrl view's sideways edge.
const MARKSMAN_MARGIN := 1.15

## How far you can see from your player while aiming along `axis`
## (&"vertical" or &"sideways") at `zoom` (1.0 default, CTRL_ZOOM crouched).
static func reach(zoom: float, axis: StringName) -> float:
	var half := VIEW_SIZE.y * 0.5 if axis == &"vertical" else VIEW_SIZE.x * 0.5
	return half / zoom + LOOKAHEAD

## Allowed max_range for a WeaponDef.range_class: [min, max] in px.
static func range_band(range_class: StringName) -> Array[float]:
	var default_edge := reach(1.0, &"vertical")
	var ctrl_edge := reach(CTRL_ZOOM, &"vertical")
	var ctrl_far := reach(CTRL_ZOOM, &"sideways")
	match range_class:
		&"close":
			return [0.0, default_edge]
		&"standard":
			return [default_edge, ctrl_edge]
		&"marksman":
			return [ctrl_far, ctrl_far * MARKSMAN_MARGIN]
		&"melee":
			return [60.0, 160.0]
	return [0.0, 0.0]
