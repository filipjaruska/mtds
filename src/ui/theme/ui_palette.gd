extends RefCounted
class_name UiPalette
## The look of the whole UI lives in one file: src/ui/theme/main_theme.tres.
## Open it in Godot (double-click it in the FileSystem dock) to change it in
## the Theme editor. Every UI scene uses it: buttons, panels, the label styles
## (TitleLabel, CaptionLabel, HudValueLabel, ...) and so on.
##
## UI drawn in code (bars, tints, floating numbers) takes its colours from the
## theme's "Palette" type, read here. Change them in the Theme editor too.
## Note: a colour in Palette is not linked to the panels and buttons; those
## have their own colours in their styles.

const THEME_PATH := "res://src/ui/theme/main_theme.tres"

# Font sizes for labels made in code.
const XS := 12
const S := 14
const M := 16
const L := 20
const XL := 30

static var BG: Color
static var SURFACE: Color
static var SURFACE_RAISED: Color
static var SURFACE_HOVER: Color
static var BORDER: Color
static var BORDER_STRONG: Color
static var WELL: Color # tracks behind bars
static var BACKDROP: Color # the dim behind the Esc menu
static var OUTLINE: Color # outline around text over the map
static var TEXT: Color
static var TEXT_DIM: Color
static var TEXT_MUTED: Color
static var ACCENT: Color
static var ACCENT_TEXT: Color # text on the accent colour
static var GOOD: Color
static var WARN: Color
static var BAD: Color
static var INFO: Color
static var GOLD: Color # gold highlights (the blackjack table)

static func _static_init() -> void:
	var theme: Theme = load(THEME_PATH)
	BG = theme.get_color("bg", "Palette")
	SURFACE = theme.get_color("surface", "Palette")
	SURFACE_RAISED = theme.get_color("surface_raised", "Palette")
	SURFACE_HOVER = theme.get_color("surface_hover", "Palette")
	BORDER = theme.get_color("border", "Palette")
	BORDER_STRONG = theme.get_color("border_strong", "Palette")
	WELL = theme.get_color("well", "Palette")
	BACKDROP = theme.get_color("backdrop", "Palette")
	OUTLINE = theme.get_color("outline", "Palette")
	TEXT = theme.get_color("text", "Palette")
	TEXT_DIM = theme.get_color("text_dim", "Palette")
	TEXT_MUTED = theme.get_color("text_muted", "Palette")
	ACCENT = theme.get_color("accent", "Palette")
	ACCENT_TEXT = theme.get_color("accent_text", "Palette")
	GOOD = theme.get_color("good", "Palette")
	WARN = theme.get_color("warn", "Palette")
	BAD = theme.get_color("bad", "Palette")
	INFO = theme.get_color("info", "Palette")
	GOLD = theme.get_color("gold", "Palette")

## A label made in code, in the default text style.
static func label(text: String, size: int = S, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Text placed in the world (signs, damage numbers): the theme's WorldText style.
static func world_text(l: Label, size: int = S, color: Color = TEXT) -> void:
	l.theme_type_variation = &"WorldText"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
