extends RefCounted
class_name UiPalette
## The one place UI colours, sizes and fonts live ("tactical" look: solid dark
## slate surfaces, crisp borders, small corners, one orange accent).
##
## Scenes get the look from the project theme (main_theme.tres, built from this
## file by tools/build_theme.gd; re-run it after changing anything here). UI
## built in code uses the constants and helpers below directly. Nothing should
## be see-through except BACKDROP behind modal menus.

# --- Surfaces (all opaque) ---------------------------------------------------------
const BG := Color("0e1014") # screen background
const SURFACE := Color("15171c") # panels
const SURFACE_RAISED := Color("1c1f26") # buttons, inputs, list rows
const SURFACE_HOVER := Color("232733")
const BORDER := Color("2a2e37")
const BORDER_STRONG := Color("3a3f4b")
const BACKDROP := Color(0.03, 0.035, 0.045, 0.82) # only behind modal menus

# --- Text ---------------------------------------------------------------------------
const TEXT := Color("e8e9ec")
const TEXT_DIM := Color("9aa0ab")
const TEXT_MUTED := Color("6b717c")

# --- Accent and states ------------------------------------------------------------
const ACCENT := Color("f7941e")
const ACCENT_HOVER := Color("ffa940")
const ACCENT_PRESSED := Color("d97c0c")
const ACCENT_TEXT := Color("111317") # text on orange
const GOOD := Color("4cc36b")
const WARN := Color("f2b33d")
const BAD := Color("e5484d")
const INFO := Color("5aa9f2")

# --- Sizes ----------------------------------------------------------------------------
const RADIUS := 4
const BORDER_W := 1
const XS := 12
const S := 14
const M := 16
const L := 20
const XL := 28
const XXL := 40

# --- Fonts ------------------------------------------------------------------------------
## Body text. Headings, numbers and the HUD use HEADING_FONT.
const BODY_FONT := preload("res://src/assets/fonts/Inter (tmp).ttf")
const HEADING_FONT := preload("res://src/assets/fonts/ChakraPetch-SemiBold (tmp).ttf")
const HEADING_FONT_BOLD := preload("res://src/assets/fonts/ChakraPetch-Bold (tmp).ttf")

## A solid box. kind: &"panel" (SURFACE + border), &"raised" (SURFACE_RAISED +
## border), &"hover", &"accent" (orange), &"pill" (raised, round ends), &"inset"
## (BG + border, for tracks and wells), &"backdrop" (modal dim, no border).
static func panel(kind: StringName = &"panel", margin: float = 8.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(BORDER_W)
	box.border_color = BORDER
	box.set_content_margin_all(margin)
	match kind:
		&"panel":
			box.bg_color = SURFACE
		&"raised":
			box.bg_color = SURFACE_RAISED
		&"hover":
			box.bg_color = SURFACE_HOVER
			box.border_color = BORDER_STRONG
		&"accent":
			box.bg_color = ACCENT
			box.border_color = ACCENT
		&"pill":
			box.bg_color = SURFACE_RAISED
			box.set_corner_radius_all(64)
		&"inset":
			box.bg_color = BG
		&"backdrop":
			box.bg_color = BACKDROP
			box.set_border_width_all(0)
			box.set_corner_radius_all(0)
	return box

## A label in the house style. Headings use the heading font in capitals.
static func label(text: String, size: int = S, color: Color = TEXT, heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heading:
		l.add_theme_font_override("font", HEADING_FONT)
		l.uppercase = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Readable text in the world (signs, prompts, names): heading font + dark outline.
static func world_text(l: Label, size: int = S, color: Color = TEXT) -> void:
	l.add_theme_font_override("font", HEADING_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", BG)

# --- The project theme ------------------------------------------------------------------

## Builds the project theme. tools/build_theme.gd saves it as main_theme.tres.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = S

	# Panels
	t.set_stylebox("panel", "Panel", panel(&"panel", 0))
	t.set_stylebox("panel", "PanelContainer", panel(&"panel", 0))
	t.set_type_variation("ScreenPanel", "PanelContainer")
	var screen := panel(&"panel", 0)
	screen.bg_color = BG
	screen.set_border_width_all(0)
	t.set_stylebox("panel", "ScreenPanel", screen)
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", panel(&"inset", 0))

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", S)
	_label_variation(t, "TitleLabel", HEADING_FONT_BOLD, XL, TEXT)
	_label_variation(t, "HeaderLabel", HEADING_FONT, L, TEXT)
	_label_variation(t, "EyebrowLabel", HEADING_FONT, XS, ACCENT)
	_label_variation(t, "CaptionLabel", HEADING_FONT, XS, TEXT_MUTED)
	_label_variation(t, "HudValueLabel", HEADING_FONT_BOLD, L, TEXT)
	_label_variation(t, "MutedLabel", BODY_FONT, S, TEXT_DIM)
	t.set_type_variation("PromptTag", "Label")
	t.set_font("font", "PromptTag", HEADING_FONT)
	t.set_font_size("font_size", "PromptTag", S)
	t.set_color("font_color", "PromptTag", TEXT)
	var tag := panel(&"panel", 0)
	tag.border_color = ACCENT
	tag.content_margin_left = 8
	tag.content_margin_right = 8
	tag.content_margin_top = 3
	tag.content_margin_bottom = 3
	t.set_stylebox("normal", "PromptTag", tag)

	# Buttons
	_button(t, "Button", panel(&"raised", 10), panel(&"hover", 10), _pressed(), TEXT, TEXT)
	t.set_font("font", "Button", HEADING_FONT)
	t.set_font_size("font_size", "Button", M)
	t.set_type_variation("AccentButton", "Button")
	var accent := panel(&"accent", 10)
	var accent_hover := panel(&"accent", 10)
	accent_hover.bg_color = ACCENT_HOVER
	accent_hover.border_color = ACCENT_HOVER
	var accent_pressed := panel(&"accent", 10)
	accent_pressed.bg_color = ACCENT_PRESSED
	accent_pressed.border_color = ACCENT_PRESSED
	_button(t, "AccentButton", accent, accent_hover, accent_pressed, ACCENT_TEXT, ACCENT_TEXT)

	# Nav bar tabs: flat; the active one (disabled, so it can't be re-clicked) is underlined.
	t.set_type_variation("NavTab", "Button")
	var flat := StyleBoxFlat.new()
	flat.bg_color = SURFACE
	flat.set_content_margin_all(10)
	var flat_hover := flat.duplicate()
	flat_hover.bg_color = SURFACE_HOVER
	_button(t, "NavTab", flat, flat_hover, flat_hover, TEXT_DIM, TEXT)
	t.set_color("font_disabled_color", "NavTab", TEXT_MUTED)
	t.set_type_variation("NavTabActive", "NavTab")
	var active := flat.duplicate()
	active.border_width_bottom = 3
	active.border_color = ACCENT
	t.set_stylebox("disabled", "NavTabActive", active)
	t.set_color("font_disabled_color", "NavTabActive", TEXT)
	t.set_type_variation("NavPlay", "AccentButton")
	t.set_stylebox("disabled", "NavPlay", accent)
	t.set_color("font_disabled_color", "NavPlay", ACCENT_TEXT)
	for nav in ["NavTab", "NavTabActive", "NavPlay"]:
		t.set_font_size("font_size", nav, M)

	# Inputs and lists
	var field := panel(&"inset", 8)
	var field_focus := panel(&"inset", 8)
	field_focus.border_color = ACCENT
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, field_focus)
		t.set_stylebox("read_only", type, field)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_placeholder_color", type, TEXT_MUTED)
		t.set_color("font_uneditable_color", type, TEXT_DIM)
		t.set_color("caret_color", type, ACCENT)
		t.set_color("selection_color", type, Color(ACCENT, 0.35))
	t.set_font_size("font_size", "LineEdit", S)

	t.set_stylebox("panel", "ItemList", panel(&"inset", 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var row_selected := panel(&"raised", 4)
	row_selected.border_color = ACCENT
	row_selected.border_width_left = 3
	t.set_stylebox("selected", "ItemList", row_selected)
	t.set_stylebox("selected_focus", "ItemList", row_selected)
	t.set_stylebox("hovered", "ItemList", panel(&"hover", 4))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_color("guide_color", "ItemList", BORDER)
	t.set_constant("v_separation", "ItemList", 6)

	t.set_stylebox("panel", "PopupMenu", panel(&"raised", 6))
	t.set_stylebox("hover", "PopupMenu", panel(&"hover", 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_color("font_disabled_color", "PopupMenu", TEXT_MUTED)
	t.set_stylebox("panel", "PopupPanel", panel(&"raised", 6))

	# Tabs
	var tab := flat.duplicate()
	tab.bg_color = SURFACE
	var tab_selected := flat.duplicate()
	tab_selected.bg_color = SURFACE
	tab_selected.border_width_bottom = 3
	tab_selected.border_color = ACCENT
	for type in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_unselected", type, tab)
		t.set_stylebox("tab_hovered", type, flat_hover)
		t.set_stylebox("tab_selected", type, tab_selected)
		t.set_stylebox("tab_disabled", type, tab)
		t.set_color("font_unselected_color", type, TEXT_DIM)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_color("font_selected_color", type, TEXT)
		t.set_font("font", type, HEADING_FONT)
		t.set_font_size("font_size", type, M)
	t.set_stylebox("panel", "TabContainer", panel(&"panel", 0))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())

	# Bars, sliders, checks, scrollbars, tooltips
	t.set_stylebox("background", "ProgressBar", panel(&"inset", 0))
	var fill := panel(&"accent", 0)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_type_variation("HealthBar", "ProgressBar")
	var health := panel(&"accent", 0)
	health.bg_color = GOOD
	health.border_color = GOOD
	t.set_stylebox("fill", "HealthBar", health)

	var slider_track := panel(&"inset", 0)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_track)
	var grab := panel(&"accent", 0)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)

	for type in ["CheckButton", "CheckBox"]:
		var none := StyleBoxEmpty.new()
		none.set_content_margin_all(4)
		_button(t, type, none, none, none, TEXT, TEXT)
		t.set_font("font", type, BODY_FONT)
		t.set_font_size("font_size", type, S)

	var grabber := panel(&"raised", 0)
	grabber.bg_color = BORDER_STRONG
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, panel(&"inset", 2))
		t.set_stylebox("grabber", type, grabber)
		var grab_hi := grabber.duplicate()
		grab_hi.bg_color = TEXT_MUTED
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_hi)

	t.set_stylebox("panel", "TooltipPanel", panel(&"raised", 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", S)
	t.set_color("font_color", "LinkButton", ACCENT)
	t.set_color("font_hover_color", "LinkButton", ACCENT_HOVER)
	return t

static func _label_variation(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)

static func _button(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, text: Color, text_hover: Color) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	var disabled := normal.duplicate()
	if disabled is StyleBoxFlat and type != "AccentButton":
		disabled.bg_color = SURFACE
	t.set_stylebox("disabled", type, disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = ACCENT
	focus.set_corner_radius_all(RADIUS)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text_hover)
	t.set_color("font_pressed_color", type, text_hover)
	t.set_color("font_hover_pressed_color", type, text_hover)
	t.set_color("font_focus_color", type, text_hover)
	t.set_color("font_disabled_color", type, TEXT_MUTED)

static func _pressed() -> StyleBoxFlat:
	var box := panel(&"hover", 10)
	box.bg_color = SURFACE
	box.border_color = ACCENT
	return box
