class_name MockStyle
extends RefCounted
## Builders for the 2026-11-01 mockup look, all in code: the rounded font, the filled glyphs (assets/ui/glyphs), the
## UI pictures (assets/ui/art), and labels / shapes / buttons placed at fixed spots of the 1920x1080 base screen
## (the mockup is measured at that size). Colours are the mockup's.

const FONT_DIR := "res://assets/fonts/"
const GLYPH_DIR := "res://assets/ui/glyphs/"
const ART_DIR := "res://assets/ui/art/"

const INK := Color("3b2a22")          # dark text on cream
const MUTED := Color("7a5e4e")
const CREAM := Color("fff1dc")        # light text on the dark faces
const GOLD := Color("ffd23c")         # the yellow figures on the dark faces
const GREEN := Color("1c8a3a")
const RED := Color("e0344e")
const RIBBON_BLUE := [Color("3a7fd6"), Color("1d4f9e")]
const RIBBON_BROWN := [Color("8a4a42"), Color("5e2a2a")]

static var _fonts: Dictionary = {}
static var _glyphs: Dictionary = {}


## M PLUS Rounded 1c (SIL OFL, assets/fonts): "Bold", "ExtraBold" or "Black".
static func font(weight: String = "ExtraBold") -> Font:
	if not _fonts.has(weight):
		var path := FONT_DIR + "MPLUSRounded1c-%s.ttf" % weight
		_fonts[weight] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[weight]


## A white filled glyph rendered at `px` (cached); tint it with the TextureRect's modulate.
static func glyph(name: String, px: int) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if not _glyphs.has(key):
		var img := Image.new()
		var path := GLYPH_DIR + name + ".svg"
		if FileAccess.file_exists(path) and img.load_svg_from_string(FileAccess.get_file_as_string(path), float(px) / 24.0) == OK:
			_glyphs[key] = ImageTexture.create_from_image(img)
		else:
			_glyphs[key] = null
	return _glyphs[key]


static func art(name: String) -> Texture2D:
	var path := ART_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func label(parent: Control, text: String, r: Rect2, px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT,
		weight := "ExtraBold", outline := 0, outline_color := Color(0, 0, 0, 0.55)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, px, color, weight, outline, outline_color)
	parent.add_child(l)
	return l


static func style_label(l: Control, px: int, color: Color, weight := "ExtraBold", outline := 0, outline_color := Color(0, 0, 0, 0.55)) -> void:
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 2)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)


static func shape(parent: Control, r: Rect2, props: Dictionary) -> UiShape:
	var s := UiShape.new()
	s.position = r.position
	s.size = r.size
	parent.add_child(s)
	s.setup(props)
	return s


static func picture(parent: Control, tex: Texture2D, r: Rect2, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # before the size, or the texture's own size wins
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = tex
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	t.position = r.position
	t.size = r.size
	return t


## A flat Button over `r` (it draws nothing itself; the shapes and labels inside it do), lighter while hovered.
static func button(parent: Control, r: Rect2, tip: String = "") -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.mouse_entered.connect(func(): b.modulate = Color(1.08, 1.08, 1.08))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	parent.add_child(b)
	return b


## The cream page card (a panel inside the window).
static func card(parent: Control, r: Rect2) -> UiShape:
	return shape(parent, r, {"top": Color("fffaf3"), "bottom": Color("fbeee2"), "border": Color("e6c9b0"), "border_width": 2.0,
		"radius": 14.0, "shadow": Color(0.45, 0.25, 0.15, 0.12), "shadow_offset": Vector2(0, 2)})


## A section ribbon: coloured band with a round right end, a white glyph and white heading text.
static func ribbon(parent: Control, r: Rect2, text: String, colors: Array, glyph_name: String = "", px := 26) -> UiShape:
	var s := shape(parent, r, {"kind": UiShape.Kind.RIBBON, "arrow": true, "tip": 16.0, "top": colors[0], "bottom": colors[1], "radius": 10.0,
		"shadow": Color(0, 0, 0, 0.18), "shadow_offset": Vector2(0, 2), "gloss": 0.18})
	var x := 16.0
	if glyph_name != "":
		var gs := minf(r.size.y - 6.0, 40.0)
		picture(s, glyph(glyph_name, 96), Rect2(18, (r.size.y - gs) * 0.5, gs, gs))
		x = 28.0 + gs
	label(s, text, Rect2(x, 0, r.size.x - x - 20, r.size.y), px, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "Black", 2, Color(0, 0, 0, 0.25))
	return s


## A button face: gradient plate with border and gloss, its label (and optional glyph) centred.
static func face_button(parent: Control, r: Rect2, text: String, top: Color, bottom: Color, edge: Color, text_color: Color,
		px := 20, glyph_name := "", radius := 10.0) -> Button:
	var b := button(parent, r, text)
	shape(b, Rect2(Vector2.ZERO, r.size), {"top": top, "bottom": bottom, "border": edge, "border_width": 2.0, "radius": radius,
		"gloss": 0.25, "shadow": Color(0, 0, 0, 0.22), "shadow_offset": Vector2(0, 2)})
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2.ZERO
	row.size = r.size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if glyph_name != "":
		var g := TextureRect.new()
		g.texture = glyph(glyph_name, 64)
		g.custom_minimum_size = Vector2(px + 4, px + 4)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.modulate = text_color
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(g)
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, px, text_color, "Black")
	row.add_child(l)
	return b


## Field stylebox (white, tan edge) for LineEdits and dropdowns.
static func field_box(radius := 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color("fffdf9")
	b.border_color = Color("c9ab98")
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	b.shadow_color = Color(0.4, 0.25, 0.15, 0.15)
	b.shadow_size = 2
	b.shadow_offset = Vector2(0, 1)
	b.content_margin_left = 10
	b.content_margin_right = 10
	return b
