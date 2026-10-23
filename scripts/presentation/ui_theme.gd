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

const WARM := Color("ffc873")
const CARD := Color("1b3248")
const RADIUS := 8
const HUD_RADIUS := 14

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
	theme.set_stylebox("disabled", "Button", _box(PANEL, 8))
	var warm_hover := _box(PANEL_ELEVATED, 8)
	warm_hover.border_color = WARM
	theme.set_stylebox("hover", "Button", warm_hover)
	theme.set_stylebox("normal", "Button", _box(PANEL_ELEVATED, 8))
	theme.set_stylebox("pressed", "Button", _box(BRAND_BLUE, 8))
	theme.add_type("Card")
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", _box(CARD, RADIUS))
	theme.add_type("CardTitle")
	theme.set_type_variation("CardTitle", "Label")
	theme.set_color("font_color", "CardTitle", TEXT_SECONDARY)
	theme.set_font_size("font_size", "CardTitle", 13)
	theme.add_type("CardValue")
	theme.set_type_variation("CardValue", "Label")
	theme.set_color("font_color", "CardValue", WARM)
	theme.set_font_size("font_size", "CardValue", 24)
	theme.add_type("HudValue")
	theme.set_type_variation("HudValue", "Label")
	theme.set_color("font_color", "HudValue", WARM)
	theme.set_font_size("font_size", "HudValue", FONT_HUD)
	theme.add_type("HudSpeedButton")
	theme.set_type_variation("HudSpeedButton", "Button")
	theme.set_stylebox("normal", "HudSpeedButton", _hud_button_box(PANEL_ELEVATED, BORDER))
	theme.set_stylebox("hover", "HudSpeedButton", _hud_button_box(PANEL_ELEVATED, WARM))
	theme.set_stylebox("disabled", "HudSpeedButton", _hud_button_box(PANEL, BORDER))
	theme.set_stylebox("pressed", "HudSpeedButton", _hud_button_box(BRAND_BLUE, WARM))
	theme.set_stylebox("hover_pressed", "HudSpeedButton", _hud_button_box(BRAND_BLUE, WARM))
	theme.set_color("font_color", "HudSpeedButton", TEXT_PRIMARY)
	theme.set_font_size("font_size", "HudSpeedButton", FONT_HUD)
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	theme.set_font_size("font_size", "Button", FONT_BODY)
	return theme


static func _box(color: Color, radius: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(radius)
	b.bg_color = color
	b.border_color = BORDER
	b.set_border_width_all(1)
	b.set_content_margin_all(8)
	return b


static func _hud_button_box(color: Color, border: Color) -> StyleBoxFlat:
	var b := _box(color, HUD_RADIUS)
	b.border_color = border
	return b
