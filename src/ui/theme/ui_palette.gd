extends RefCounted
class_name UiPalette
## The one place UI colours, sizes and fonts live ("tactical" look: solid slate
## surfaces, crisp borders, a cut top-right corner, white text, one orange accent,
## Chakra Petch everywhere).
##
## Scenes get the look from the theme (main_theme.tres, built from this file by
## tools/build_theme.gd; re-run it after changing anything here). Every UI scene
## root has the theme assigned too, so the editor shows exactly what the game
## does. UI built in code uses the constants and helpers below directly. Nothing
## is see-through except BACKDROP behind modal menus.

# --- Surfaces (all opaque) ---------------------------------------------------------
const BG := Color("1b1e24") # screen background
const SURFACE := Color("252931") # panels
const SURFACE_RAISED := Color("2e333c") # buttons, inputs, list rows
const SURFACE_HOVER := Color("3a404b")
const BORDER := Color("464d5a")
const BORDER_STRONG := Color("5d6575")
const WELL := Color("1d2026") # tracks behind bars, input wells
const BACKDROP := Color(0.07, 0.08, 0.1, 0.85) # only behind modal menus
const OUTLINE := Color("0c0d10") # outline around text drawn over the map

# --- Text (all at least 6:1 on SURFACE) ------------------------------------------------
const TEXT := Color("ffffff")
const TEXT_DIM := Color("d0d4db")
const TEXT_MUTED := Color("a9afba")

# --- Accent and states ------------------------------------------------------------
const ACCENT := Color("f7941e")
const ACCENT_HOVER := Color("ffa940")
const ACCENT_PRESSED := Color("d97c0c")
const ACCENT_TEXT := Color("111317") # text on orange
const GOOD := Color("4cc36b")
const WARN := Color("f2b33d")
const BAD := Color("e5484d")
const INFO := Color("5aa9f2")
const GOLD := Color(1.0, 0.82, 0.3) # poker hands: the halo behind strong cards

# --- Sizes ----------------------------------------------------------------------------
const CUT := 8 # the cut top-right corner of panels and buttons
const BORDER_W := 1
const XS := 12
const S := 14
const M := 16
const L := 20
const XL := 30
const XXL := 40
const HUD_VALUE := 40 # health and ammo numbers

# --- Fonts ------------------------------------------------------------------------------
const BODY_FONT := preload("res://src/assets/fonts/ChakraPetch-Medium (tmp).ttf")
const HEADING_FONT := preload("res://src/assets/fonts/ChakraPetch-SemiBold (tmp).ttf")
const HEADING_FONT_BOLD := preload("res://src/assets/fonts/ChakraPetch-Bold (tmp).ttf")

## The house corner: square, with the top-right cut off at 45 degrees.
static func cut_corner(box: StyleBoxFlat, cut: int = CUT) -> StyleBoxFlat:
	box.set_corner_radius_all(0)
	box.corner_radius_top_right = cut
	box.corner_detail = 1 # one segment per corner: a straight cut instead of a curve
	return box

## A solid box. kind: &"panel" (SURFACE + border), &"raised" (SURFACE_RAISED +
## border), &"hover", &"accent" (orange), &"pill" (raised, round ends), &"inset"
## (BG + border, for tracks and wells), &"backdrop" (modal dim, no border).
static func panel(kind: StringName = &"panel", margin: float = 8.0) -> StyleBoxFlat:
	var box := cut_corner(StyleBoxFlat.new())
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
			box.corner_detail = 8
		&"inset":
			box.bg_color = WELL
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
	l.add_theme_color_override("font_outline_color", OUTLINE)

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
	# Flat fills that follow the palette (instead of ColorRects with fixed colours)
	for fill in [["ScreenBackground", BG], ["NavBarBackground", SURFACE], ["Divider", BORDER]]:
		t.set_type_variation(fill[0], "Panel")
		var flat_fill := StyleBoxFlat.new()
		flat_fill.bg_color = fill[1]
		t.set_stylebox("panel", fill[0], flat_fill)
	# HUD boxes over the map
	t.set_type_variation("HudPanel", "PanelContainer")
	var hud := panel(&"panel", 0)
	hud.content_margin_left = 14
	hud.content_margin_right = 14
	hud.content_margin_top = 8
	hud.content_margin_bottom = 10
	t.set_stylebox("panel", "HudPanel", hud)
	t.set_type_variation("HudClock", "PanelContainer")
	var clock := panel(&"panel", 0)
	clock.border_width_top = 2
	clock.border_color = BORDER
	clock.content_margin_left = 16
	clock.content_margin_right = 16
	clock.content_margin_top = 2
	clock.content_margin_bottom = 2
	t.set_stylebox("panel", "HudClock", clock)
	# Scoreboard rows: alternating, yours marked with an orange edge
	for row in [["ScoreRow", SURFACE_RAISED], ["ScoreRowAlt", SURFACE]]:
		t.set_type_variation(row[0], "PanelContainer")
		var box := StyleBoxFlat.new()
		box.bg_color = row[1]
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		t.set_stylebox("panel", row[0], box)
	t.set_type_variation("ScoreHeader", "PanelContainer")
	var header := StyleBoxEmpty.new()
	header.content_margin_left = 14
	header.content_margin_right = 14
	header.content_margin_bottom = 2
	t.set_stylebox("panel", "ScoreHeader", header)
	# Podium cards on the results screen; the winner's is edged in orange
	for card in [["PodiumCard", BORDER_STRONG], ["PodiumCardFirst", ACCENT]]:
		t.set_type_variation(card[0], "PanelContainer")
		var box := panel(&"raised", 0)
		box.border_width_top = 3
		box.border_color = card[1]
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 14
		box.content_margin_bottom = 16
		t.set_stylebox("panel", card[0], box)
	t.set_type_variation("ScoreRowMe", "PanelContainer")
	var me := StyleBoxFlat.new()
	me.bg_color = SURFACE_HOVER
	me.border_width_left = 3
	me.border_color = ACCENT
	me.content_margin_left = 11
	me.content_margin_right = 14
	me.content_margin_top = 7
	me.content_margin_bottom = 7
	t.set_stylebox("panel", "ScoreRowMe", me)

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", S)
	_label_variation(t, "TitleLabel", HEADING_FONT_BOLD, XL, TEXT)
	_label_variation(t, "HeaderLabel", HEADING_FONT, L, TEXT)
	_label_variation(t, "EyebrowLabel", HEADING_FONT, XS, ACCENT)
	_label_variation(t, "CaptionLabel", HEADING_FONT, XS, TEXT_DIM)
	_label_variation(t, "HudValueLabel", HEADING_FONT_BOLD, HUD_VALUE, TEXT)
	_label_variation(t, "HudClockLabel", HEADING_FONT_BOLD, 28, TEXT)
	_label_variation(t, "HeroLabel", HEADING_FONT_BOLD, 64, TEXT)
	_label_variation(t, "StatLabel", HEADING_FONT, M, TEXT)
	t.set_type_variation("SlotTag", "Label")
	t.set_font("font", "SlotTag", HEADING_FONT)
	t.set_font_size("font_size", "SlotTag", 13)
	t.set_color("font_color", "SlotTag", TEXT_MUTED)
	var slot := panel(&"panel", 0)
	slot.bg_color = SURFACE
	slot.content_margin_left = 8
	slot.content_margin_right = 8
	slot.content_margin_top = 2
	slot.content_margin_bottom = 2
	t.set_stylebox("normal", "SlotTag", slot)
	t.set_type_variation("SlotTagActive", "SlotTag")
	t.set_color("font_color", "SlotTagActive", TEXT)
	var slot_on := slot.duplicate()
	slot_on.border_color = ACCENT
	t.set_stylebox("normal", "SlotTagActive", slot_on)
	_label_variation(t, "NameTag", HEADING_FONT, S, TEXT)
	t.set_constant("outline_size", "NameTag", 6)
	t.set_color("font_outline_color", "NameTag", OUTLINE)
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

	# In-match pieces (each a scene: card_view, chat_bubble_view, top_bar_slot,
	# active_powerup_row, pause_menu, lobby_player_row)
	_label_variation(t, "CardText", HEADING_FONT, 11, TEXT) # outlined: drawn over the map
	t.set_constant("outline_size", "CardText", 5)
	t.set_color("font_outline_color", "CardText", OUTLINE)
	for v in [["CardChip", 15, ACCENT], ["CardDetails", 10, TEXT], ["CardHint", 12, ACCENT]]:
		t.set_type_variation(v[0], "CardText")
		t.set_font_size("font_size", v[0], v[1])
		t.set_color("font_color", v[0], v[2])
	_label_variation(t, "CardHotkey", HEADING_FONT, 13, TEXT)
	var key := panel(&"raised", 0)
	key.border_color = BORDER_STRONG
	t.set_stylebox("normal", "CardHotkey", key)
	t.set_type_variation("CardSlot", "Panel")
	var slot_outline := StyleBoxFlat.new()
	slot_outline.draw_center = false
	slot_outline.set_border_width_all(2)
	slot_outline.border_color = BORDER_STRONG
	slot_outline.set_corner_radius_all(8)
	t.set_stylebox("panel", "CardSlot", slot_outline)
	t.set_type_variation("CardGlow", "Panel")
	var halo := StyleBoxFlat.new()
	halo.bg_color = GOLD
	halo.set_corner_radius_all(14)
	halo.set_expand_margin_all(5.0)
	halo.shadow_color = Color(GOLD, 0.6)
	halo.shadow_size = 12
	t.set_stylebox("panel", "CardGlow", halo)

	t.set_type_variation("ChatBubble", "PanelContainer")
	var bubble := panel(&"panel", 0)
	bubble.border_color = BORDER_STRONG
	bubble.content_margin_left = 8
	bubble.content_margin_right = 8
	bubble.content_margin_top = 4
	bubble.content_margin_bottom = 5
	t.set_stylebox("panel", "ChatBubble", bubble)
	_label_variation(t, "ChatText", BODY_FONT, 13, TEXT)
	t.set_type_variation("ChatField", "LineEdit")
	var chat_field := panel(&"inset", 8)
	chat_field.border_color = ACCENT
	t.set_stylebox("normal", "ChatField", chat_field)
	t.set_stylebox("focus", "ChatField", chat_field)
	t.set_font_size("font_size", "ChatField", 13)

	t.set_type_variation("TopBarFrame", "Panel")
	var frame := panel(&"panel", 0)
	frame.set_border_width_all(2) # colour: the player's, set by TopBarSlot
	t.set_stylebox("panel", "TopBarFrame", frame)
	t.set_type_variation("LetterTab", "PanelContainer")
	var tab_box := StyleBoxFlat.new()
	tab_box.bg_color = SURFACE
	tab_box.set_border_width_all(1)
	tab_box.border_color = BORDER_STRONG
	tab_box.content_margin_left = 3
	tab_box.content_margin_right = 3
	t.set_stylebox("panel", "LetterTab", tab_box)
	_label_variation(t, "LetterLabel", HEADING_FONT_BOLD, 10, TEXT)
	t.set_type_variation("BarTrack", "Panel")
	var track := StyleBoxFlat.new()
	track.bg_color = WELL
	t.set_stylebox("panel", "BarTrack", track)

	t.set_type_variation("ActiveRowBg", "Panel")
	t.set_stylebox("panel", "ActiveRowBg", panel(&"panel", 0))
	_label_variation(t, "ActiveName", HEADING_FONT, 12, TEXT)
	_label_variation(t, "ActiveUses", BODY_FONT, 11, TEXT_DIM)

	t.set_type_variation("Backdrop", "Panel")
	t.set_stylebox("panel", "Backdrop", panel(&"backdrop", 0))
	t.set_type_variation("PausePanel", "PanelContainer")
	var pause := panel(&"panel", 28)
	pause.border_width_top = 3
	pause.border_color = ACCENT
	t.set_stylebox("panel", "PausePanel", pause)

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
	t.set_stylebox("panel", "TabContainer", panel(&"panel", 16))
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
	t.set_type_variation("DashBar", "ProgressBar")
	var dash_bg := StyleBoxFlat.new()
	dash_bg.bg_color = WELL
	var dash_fill := StyleBoxFlat.new()
	dash_fill.bg_color = ACCENT
	t.set_stylebox("background", "DashBar", dash_bg)
	t.set_stylebox("fill", "DashBar", dash_fill)

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
	cut_corner(focus)
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
