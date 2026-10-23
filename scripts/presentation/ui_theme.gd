class_name UiTheme
extends RefCounted
## Theme built from docs/design/UI_DESIGN_TOKENS.md. Sizes live here, not in scenes (04 §1).
## Game-style look (#61): chunky two-tone buttons with a bottom edge that presses down, thick
## rounded frames, outlined numbers, a segmented speed group, pill toggles, round-knob sliders and
## pill toasts. Colours are tokens; scenes only pick type variations. Button text is kept at
## contrast >= 4.5:1 against its face (white on the saturated faces below).

const BACKGROUND := Color("0b1a2b")
const PANEL := Color("13283d")
const PANEL_ELEVATED := Color("1d3b57")
const BORDER := Color("38597a")
const EDGE_DARK := Color("07111d")
const BRAND_BLUE := Color("1a6ad8")
const HIGHLIGHT_BLUE := Color("2f8cff")
const TEXT_PRIMARY := Color("edf5fb")
const TEXT_SECONDARY := Color("adc4d5")

const WARM := Color("ffc873")
const GOLD := Color("ffc24a")
const SUCCESS_GREEN := Color("43c67d")
const CONFIRM_GREEN := Color("17784a")
const DANGER_RED := Color("c93a3f")
const INFO_CYAN := Color("5caefd")
const CARD := Color("183350")
const SLATE := Color("2a4f74")
const SLATE_EDGE := Color("0a1828")
const SLATE_HOVER := Color("386489")
const DISABLED_FACE := Color("1b2f44")
const DISABLED_EDGE := Color("0e1c2c")
const TOAST_BG := Color(0.04, 0.08, 0.13, 0.9)
const RADIUS := 10
const BUTTON_RADIUS := 8
const BAR_RADIUS := 4
const HUD_RADIUS := 14
const FRAME_RADIUS := 14
const TOAST_RADIUS := 16
const FRAME_TOP := Color("1a3652")
const FRAME_BOTTOM := Color("0f2236")
const FRAME_RIM := Color("5d82a8")
const CARD_TOP := Color("22446a")
const CARD_BOTTOM := Color("142c46")
const CARD_RIM := Color("4a6f96")
const CHIP_FACE := Color(0.04, 0.1, 0.17, 0.9)

## Type scale (13 / 15 / 18 / 24) and spacing (8 / 12 / 16).
const FONT_SMALL := 13
const FONT_BODY := 15
const FONT_TITLE := 18
const FONT_VALUE := 24
const FONT_HUD := FONT_BODY
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16

const HUD_HEIGHT := 64
const BAR_HEIGHT := 8
const PALETTE_WIDTH := 280
const INSPECTOR_WIDTH := 340
const STORE_MIN_WIDTH := 640
const COMPACT_WIDTH := 1280

## Baked frame textures, one per colour pair (built on first use, see _rounded_texture).
static var _texture_cache: Dictionary = {}


static func build() -> Theme:
	var theme := Theme.new()
	# Frames: default panels are thick rounded game windows, cards are lifted with a shadow.
	theme.set_stylebox("panel", "PanelContainer", _frame())
	theme.add_type("Card")
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", _card_box())
	# Buttons: chunky, bottom edge, hover lifts to a cyan rim, pressed sinks onto the edge.
	_button_set(theme, "Button", SLATE, SLATE_EDGE, SLATE_HOVER, INFO_CYAN)
	_variation_button(theme, "PrimaryButton", BRAND_BLUE, Color("0b3f91"), Color("2a7cf0"), Color("8fc4ff"))
	_variation_button(theme, "ConfirmButton", CONFIRM_GREEN, Color("0a4a2b"), Color("1f9159"), Color("8ff0b8"))
	_variation_button(theme, "DangerButton", DANGER_RED, Color("6e1c21"), Color("dd4a4f"), Color("ffb3b3"))
	# A disabled danger button keeps a muted red face, so 撤去 still reads as destructive when it cannot be used.
	theme.set_stylebox("disabled", "DangerButton", _button(Color("4a2226"), Color("2a1214")))
	# Inspector window: framed info tiles, pill chips (plain and green status) and the name / value type scale.
	theme.add_type("InfoTile")
	theme.set_type_variation("InfoTile", "PanelContainer")
	theme.set_stylebox("panel", "InfoTile", _tile_box())
	theme.add_type("Chip")
	theme.set_type_variation("Chip", "PanelContainer")
	theme.set_stylebox("panel", "Chip", chip_box())
	theme.add_type("StatusChip")
	theme.set_type_variation("StatusChip", "PanelContainer")
	theme.set_stylebox("panel", "StatusChip", badge_box())
	theme.add_type("ChipLabel")
	theme.set_type_variation("ChipLabel", "Label")
	theme.set_color("font_color", "ChipLabel", TEXT_PRIMARY)
	theme.set_font_size("font_size", "ChipLabel", FONT_SMALL)
	theme.add_type("InspectorName")
	theme.set_type_variation("InspectorName", "Label")
	theme.set_color("font_color", "InspectorName", TEXT_PRIMARY)
	theme.set_font_size("font_size", "InspectorName", FONT_VALUE)
	_outline(theme, "InspectorName", 2)
	theme.add_type("TileValue")
	theme.set_type_variation("TileValue", "Label")
	theme.set_color("font_color", "TileValue", GOLD)
	theme.set_font_size("font_size", "TileValue", FONT_TITLE)
	_outline(theme, "TileValue", 2)
	# Speed control: one segmented pill, the selected segment filled blue with a soft glow.
	_segment_type(theme, "SegmentLeft", true, false)
	_segment_type(theme, "SegmentMid", false, false)
	_segment_type(theme, "SegmentRight", false, true)
	_segment_type(theme, "HudSpeedButton", true, true)
	# Labels: numbers carry a dark outline so they read over any background.
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	theme.add_type("SectionTitle")
	theme.set_type_variation("SectionTitle", "Label")
	theme.set_color("font_color", "SectionTitle", WARM)
	theme.set_font_size("font_size", "SectionTitle", FONT_TITLE)
	theme.set_constant("outline_size", "SectionTitle", 2)
	theme.set_color("font_outline_color", "SectionTitle", Color(0, 0, 0, 0.7))
	theme.add_type("CardTitle")
	theme.set_type_variation("CardTitle", "Label")
	theme.set_color("font_color", "CardTitle", TEXT_SECONDARY)
	theme.set_font_size("font_size", "CardTitle", FONT_SMALL)
	theme.add_type("CardValue")
	theme.set_type_variation("CardValue", "Label")
	theme.set_color("font_color", "CardValue", GOLD)
	theme.set_font_size("font_size", "CardValue", FONT_VALUE)
	_outline(theme, "CardValue", 3)
	theme.add_type("HudValue")
	theme.set_type_variation("HudValue", "Label")
	theme.set_color("font_color", "HudValue", TEXT_PRIMARY)
	theme.set_font_size("font_size", "HudValue", FONT_HUD)
	_outline(theme, "HudValue", 2)
	theme.add_type("HudCash")   # the money chip's value: a larger gold figure
	theme.set_type_variation("HudCash", "Label")
	theme.set_color("font_color", "HudCash", GOLD)
	theme.set_font_size("font_size", "HudCash", FONT_TITLE)
	_outline(theme, "HudCash", 3)
	# Toggles: pill track with a white knob (blue when on).
	theme.set_icon("checked", "CheckButton", _toggle_texture(true))
	theme.set_icon("checked_disabled", "CheckButton", _toggle_texture(true))
	theme.set_icon("unchecked", "CheckButton", _toggle_texture(false))
	theme.set_icon("unchecked_disabled", "CheckButton", _toggle_texture(false))
	theme.set_constant("h_separation", "CheckButton", 10)
	# Sliders: thin track, blue fill up to a round white grabber.
	theme.set_stylebox("slider", "HSlider", _track_box())
	theme.set_stylebox("grabber_area", "HSlider", _fill_box(HIGHLIGHT_BLUE))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _fill_box(INFO_CYAN))
	var knob := _disc_texture(18, Color.WHITE, EDGE_DARK)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", knob)
	theme.set_icon("grabber_disabled", "HSlider", knob)
	# Tabs: an underline in warm gold marks the active tab.
	for tab_type in ["TabBar", "TabContainer"]:
		theme.set_stylebox("tab_selected", tab_type, _tab_box(true))
		theme.set_stylebox("tab_unselected", tab_type, _tab_box(false))
		theme.set_stylebox("tab_hovered", tab_type, _tab_box(false, true))
		theme.set_color("font_selected_color", tab_type, TEXT_PRIMARY)
		theme.set_color("font_unselected_color", tab_type, TEXT_SECONDARY)
		theme.set_color("font_hovered_color", tab_type, TEXT_PRIMARY)
	theme.set_stylebox("background", "ProgressBar", _bar_box(Color("0a1726")))
	theme.set_stylebox("fill", "ProgressBar", _bar_box(WARM))
	return theme


## Toast pill (CueLayer draws it with draw_style_box). The caller fades it by setting bg/border alpha.
static func toast_box(edge: Color, achievement: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = TOAST_BG
	b.set_corner_radius_all(TOAST_RADIUS)
	b.set_border_width_all(1)
	b.border_color = WARM if achievement else Color(edge, 0.7)
	b.content_margin_left = 16.0
	b.content_margin_right = 16.0
	b.content_margin_top = 5.0
	b.content_margin_bottom = 5.0
	b.shadow_color = Color(0, 0, 0, 0.4)
	b.shadow_size = 6
	b.shadow_offset = Vector2(0, 3)
	return b


## Inspector info tile: a small rounded face in the chip colour with a thin card-rim edge.
static func _tile_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(CHIP_FACE, 0.85)
	b.border_color = Color(CARD_RIM, 0.6)
	b.set_border_width_all(1)
	b.set_corner_radius_all(10)
	b.content_margin_left = 10.0
	b.content_margin_right = 10.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	return b


static func _box(color: Color, radius: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(radius)
	b.bg_color = color
	b.border_color = BORDER
	b.set_border_width_all(1)
	b.set_content_margin_all(8)
	return b


## Game window: a rounded frame with a vertical gradient, a 2 px light rim and a darker 2 px inner band.
static func _frame() -> StyleBoxTexture:
	return _rounded_box(FRAME_TOP, FRAME_BOTTOM, FRAME_RIM, FRAME_RADIUS, 10)


## Card: the same window look in the card colours, a little tighter.
static func _card_box() -> StyleBoxTexture:
	return _rounded_box(CARD_TOP, CARD_BOTTOM, CARD_RIM, RADIUS, 10)


static func _rounded_box(top: Color, bottom: Color, rim: Color, radius: int, pad: int) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = _rounded_texture(top, bottom, rim, radius)
	b.set_texture_margin_all(radius)
	b.set_content_margin_all(pad)
	return b


## The frame texture is (2 * radius + 4) px square and is stretched by StyleBoxTexture's 9-slice, so the corners stay
## round at any size. Baked once per colour set and cached.
static func _rounded_texture(top: Color, bottom: Color, rim: Color, radius: int) -> ImageTexture:
	var key := "%s|%s|%s|%d" % [top.to_html(), bottom.to_html(), rim.to_html(), radius]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var n := radius * 2 + 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := n * 0.5
	var inner := half - float(radius)
	var band_colour := 0.7
	for y in n:
		var fill := top.lerp(bottom, (y + 0.5) / n)
		var band := fill.darkened(band_colour)
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(inner, inner)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - float(radius)
			var cover := clampf(0.5 - d, 0.0, 1.0)   # antialiased outline
			if cover <= 0.0:
				continue
			var from_edge := -d
			var c := rim if from_edge < 2.0 else (band if from_edge < 4.0 else fill)
			c.a = cover
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex


## Header ribbon behind a card title: a warm-edged strip. Drawn by the label's own draw signal so the title stays a
## plain Label (the card's first child). It extends a little into the card's padding so the text is not on the edge.
static func ribbon(label: Label) -> void:
	if label.has_meta(&"ribbon"):
		return
	label.set_meta(&"ribbon", true)
	var box := ribbon_box()
	label.draw.connect(func(): label.draw_style_box(box, Rect2(Vector2(-8, -2), label.size + Vector2(16, 4))))


static func ribbon_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(WARM, 0.2)
	b.set_corner_radius_all(6)
	b.border_width_left = 3
	b.border_color = WARM
	return b


## A game-style pill for a HUD value group.
static func chip_box(edge: Color = BORDER) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = CHIP_FACE
	b.border_color = Color(edge, 0.7)
	b.set_border_width_all(1)
	b.set_corner_radius_all(14)
	return b


## Filled green badge for the open-for-business state.
static func badge_box() -> StyleBoxFlat:
	var b := chip_box(SUCCESS_GREEN)
	b.bg_color = CONFIRM_GREEN
	b.border_color = SUCCESS_GREEN
	return b


## Round icon badge on a metric card: a disc in the tint, with a ring of the same tint.
static func badge_circle(tint: Color, size: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(tint, 0.28)
	b.border_color = tint
	b.set_border_width_all(2)
	b.set_corner_radius_all(size)
	b.set_content_margin_all(0)
	return b


## Selected palette row: the blue face with a soft blue glow.
static func selected_row_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(BRAND_BLUE, 0.7)
	b.border_color = HIGHLIGHT_BLUE
	b.set_border_width_all(2)
	b.set_corner_radius_all(BUTTON_RADIUS)
	b.shadow_color = Color(0.18, 0.55, 1.0, 0.5)
	b.shadow_size = 8
	b.content_margin_top = 2.0
	b.content_margin_bottom = 2.0
	return b


static func _bar_box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(BAR_RADIUS)
	b.bg_color = color
	b.set_content_margin_all(0)
	return b


## One button face. Pressed moves the content down onto the edge (thinner bottom edge, more top margin).
static func _button(face: Color, edge: Color, pressed: bool = false, radius: int = BUTTON_RADIUS) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = face
	b.border_color = edge
	b.set_corner_radius_all(radius)
	b.set_border_width_all(1)
	b.border_width_bottom = 1 if pressed else 4
	b.content_margin_left = 12.0
	b.content_margin_right = 12.0
	b.content_margin_top = 8.0 if pressed else 6.0
	b.content_margin_bottom = 6.0 if pressed else 8.0
	b.shadow_color = Color(0, 0, 0, 0.0 if pressed else 0.3)
	b.shadow_size = 0 if pressed else 3
	b.shadow_offset = Vector2(0, 0 if pressed else 2)
	return b


static func _button_set(theme: Theme, type: String, face: Color, edge: Color, hover_face: Color, hover_edge: Color) -> void:
	var pressed_face := face.darkened(0.12)
	theme.set_stylebox("normal", type, _button(face, edge))
	theme.set_stylebox("hover", type, _button(hover_face, hover_edge))
	theme.set_stylebox("pressed", type, _button(pressed_face, edge, true))
	theme.set_stylebox("hover_pressed", type, _button(pressed_face, edge, true))
	theme.set_stylebox("disabled", type, _button(DISABLED_FACE, DISABLED_EDGE))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_color("font_color", type, TEXT_PRIMARY)
	theme.set_color("font_hover_color", type, Color.WHITE)
	theme.set_color("font_pressed_color", type, Color.WHITE)
	theme.set_color("font_focus_color", type, Color.WHITE)
	theme.set_color("font_disabled_color", type, Color(1, 1, 1, 0.45))
	theme.set_font_size("font_size", type, FONT_BODY)


static func _variation_button(theme: Theme, name: String, face: Color, edge: Color, hover_face: Color, hover_edge: Color) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Button")
	_button_set(theme, name, face, edge, hover_face, hover_edge)


## Speed segment. Outer segments round their outside corners; the selected one glows blue.
static func _segment_type(theme: Theme, name: String, round_left: bool, round_right: bool) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, _segment_box(SLATE, SLATE_EDGE, round_left, round_right, false))
	theme.set_stylebox("hover", name, _segment_box(SLATE_HOVER, INFO_CYAN, round_left, round_right, false))
	theme.set_stylebox("pressed", name, _segment_box(HIGHLIGHT_BLUE, HIGHLIGHT_BLUE, round_left, round_right, true))
	theme.set_stylebox("hover_pressed", name, _segment_box(HIGHLIGHT_BLUE, HIGHLIGHT_BLUE, round_left, round_right, true))
	theme.set_stylebox("disabled", name, _segment_box(DISABLED_FACE, DISABLED_EDGE, round_left, round_right, false))
	theme.set_stylebox("focus", name, StyleBoxEmpty.new())
	theme.set_color("font_color", name, TEXT_PRIMARY)
	theme.set_color("font_hover_color", name, Color.WHITE)
	theme.set_color("font_pressed_color", name, Color.WHITE)
	theme.set_color("font_disabled_color", name, Color(1, 1, 1, 0.45))
	theme.set_font_size("font_size", name, FONT_HUD)


static func _segment_box(face: Color, edge: Color, round_left: bool, round_right: bool, glow: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = face
	b.border_color = edge
	b.set_border_width_all(1)
	b.border_width_bottom = 3
	b.corner_radius_top_left = 10 if round_left else 0
	b.corner_radius_bottom_left = 10 if round_left else 0
	b.corner_radius_top_right = 10 if round_right else 0
	b.corner_radius_bottom_right = 10 if round_right else 0
	b.content_margin_left = 12.0
	b.content_margin_right = 12.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	if glow:
		b.shadow_color = Color(0.18, 0.55, 1.0, 0.55)
		b.shadow_size = 8
	return b


static func _tab_box(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, 0.06) if hovered else (Color(WARM, 0.08) if selected else Color(0, 0, 0, 0))
	b.corner_radius_top_left = 8
	b.corner_radius_top_right = 8
	b.border_color = WARM
	b.border_width_bottom = 3 if selected else 0
	b.content_margin_left = 12.0
	b.content_margin_right = 12.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	return b


static func _track_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color("213a54")
	b.set_corner_radius_all(BAR_RADIUS)
	b.content_margin_top = 2.0
	b.content_margin_bottom = 2.0
	return b


static func _fill_box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(BAR_RADIUS)
	b.content_margin_top = 2.0
	b.content_margin_bottom = 2.0
	return b


static func _outline(theme: Theme, type: String, size: int) -> void:
	theme.set_constant("outline_size", type, size)
	theme.set_color("font_outline_color", type, Color(0, 0, 0, 0.75))


## Pill toggle track 44x24 with a white knob (on = blue track, knob right).
static func _toggle_texture(on: bool) -> ImageTexture:
	var w := 44
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := HIGHLIGHT_BLUE if on else Color("3b5a78")
	var r := h * 0.5
	var knob_x: float = (w - r) if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var core := Vector2(clampf(px.x, r, w - r), r)
			if px.distance_to(core) <= r:
				img.set_pixel(x, y, track)
				if px.distance_to(Vector2(knob_x, r)) <= r - 3.0:
					img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _disc_texture(d: int, fill: Color, rim: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= d * 0.5:
				img.set_pixel(x, y, rim if dist > d * 0.5 - 2.0 else fill)
	return ImageTexture.create_from_image(img)
