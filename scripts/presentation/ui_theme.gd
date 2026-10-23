class_name UiTheme
extends RefCounted
## Theme built from docs/design/UI_DESIGN_TOKENS.md. Sizes live here, not in scenes (04 §1).

const BACKGROUND := Color("0c1724")
const PANEL := Color("142638")
const PANEL_ELEVATED := Color("20394e")
const BORDER := Color("42617b")
const BRAND_BLUE := Color("226092")
const TEXT_PRIMARY := Color("edf5fb")
const TEXT_SECONDARY := Color("adc4d5")

const HUD_HEIGHT := 64
const PALETTE_WIDTH := 280
const INSPECTOR_WIDTH := 320
const STORE_MIN_WIDTH := 640
const COMPACT_WIDTH := 1280
const FONT_BODY := 16
const FONT_HUD := 20


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL))
	theme.set_stylebox("normal", "Button", _box(PANEL_ELEVATED))
	theme.set_stylebox("hover", "Button", _box(BRAND_BLUE))
	theme.set_stylebox("pressed", "Button", _box(BRAND_BLUE))
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	theme.set_font_size("font_size", "Button", FONT_BODY)
	return theme


static func _box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = BORDER
	b.set_border_width_all(1)
	b.set_content_margin_all(8)
	return b
