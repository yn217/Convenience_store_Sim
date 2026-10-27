class_name ProductIcons
extends RefCounted
## Code-made placeholder package icons (issue #12 stand-in until generated art is approved).
## Everything is drawn with Image pixels: a per-category silhouette, a colour derived from the
## sku_id hash and the category, and a fictional two-glyph label plate. No external assets,
## no real brands or logos. Textures are cached per (sku, category, label, size).

const PLATE_COLOR := Color(0.97, 0.96, 0.92)
const INK_COLOR := Color(0.18, 0.16, 0.2)
const NORI_COLOR := Color(0.1, 0.18, 0.12)
const BROTH_COLOR := Color(0.45, 0.25, 0.12)
const CONE_COLOR := Color(0.85, 0.62, 0.36)

static var _cache: Dictionary = {}


## Texture for one SKU row. `sku` is a product dictionary (sku_id, category, name_ja/display_name).
static func texture(sku: Dictionary, size: int = 48) -> Texture2D:
	var sku_id := str(sku.get("sku_id", ""))
	var category := str(sku.get("category", ""))
	var label := label_for(sku)
	var px := maxi(size, 8)
	var key := "%s|%s|%s|%d" % [sku_id, category, label, px]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(_draw(sku_id, category, label, px))
	_cache[key] = tex
	return tex


## First two characters of name_ja, falling back to display_name. Both are fictional product names.
static func label_for(sku: Dictionary) -> String:
	var text := str(sku.get("name_ja", sku.get("display_name", "")))
	return text.substr(0, 2)


static func _draw(sku_id: String, category: String, label: String, px: int) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var body := _body_color(sku_id, category)
	var plate := _plate_rect(category)
	var glyphs: Array[int] = []
	for i in label.length():
		var bits := _hash(label[i]) & 0xFFF
		glyphs.append(bits if bits != 0 else 0x2A5)
	for y in px:
		for x in px:
			var u := (float(x) + 0.5) / float(px)
			var v := (float(y) + 0.5) / float(px)
			var hit := _hit(category, u, v)
			if hit == 0:
				continue
			var c := _color_for(category, hit, body)
			if hit == 1 and not glyphs.is_empty() and plate.has_point(Vector2(u, v)):
				c = _plate_pixel(plate, glyphs, u, v)
			img.set_pixel(x, y, c)
	return img


## 0 = background, 1 = body, 2 = accent (band, cap, cone, crust), 3 = highlight (lid, neck, topping, broth).
static func _hit(category: String, u: float, v: float) -> int:
	match category:
		"rice_ball":
			if not _in_triangle(Vector2(u, v), Vector2(0.5, 0.08), Vector2(0.1, 0.92), Vector2(0.9, 0.92)):
				return 0
			return 2 if v >= 0.66 and v <= 0.84 else 1
		"drink":
			if v >= 0.08 and v < 0.3 and u >= 0.4 and u <= 0.6:
				return 2 if v < 0.16 else 3
			if v >= 0.3 and v <= 0.92 and u >= 0.3 and u <= 0.7:
				return 1
			return 0
		"instant_noodle":
			if v < 0.12 or v > 0.9:
				return 0
			var half := 0.4 - (v - 0.12) / 0.78 * 0.1
			if absf(u - 0.5) > half:
				return 0
			if v < 0.2:
				return 3
			return 2 if v >= 0.62 and v <= 0.68 else 1
		"bread":
			if pow((u - 0.5) / 0.42, 2.0) + pow((v - 0.6) / 0.26, 2.0) > 1.0:
				return 0
			return 2 if fposmod(u * 6.0 - v * 4.0, 1.5) < 0.2 else 1
		"snack":
			if u < 0.18 or u > 0.82 or v < 0.22 or v > 0.9:
				return 0
			return 2 if v < 0.28 or v > 0.84 else 1
		"dessert":
			if pow((u - 0.5) / 0.4, 2.0) + pow((v - 0.4) / 0.12, 2.0) <= 1.0:
				return 3
			if v < 0.42 or v > 0.9:
				return 0
			var half_d := 0.36 - (v - 0.42) / 0.48 * 0.1
			return 1 if absf(u - 0.5) <= half_d else 0
		"oden":
			if pow((u - 0.5) / 0.46, 2.0) + pow((v - 0.42) / 0.1, 2.0) <= 1.0:
				return 3
			if v < 0.42:
				return 0
			return 1 if pow((u - 0.5) / 0.46, 2.0) + pow((v - 0.42) / 0.48, 2.0) <= 1.0 else 0
		"bento":   # a tray with a clear lid band and compartments
			if u < 0.1 or u > 0.9 or v < 0.3 or v > 0.86:
				return 0
			if v < 0.4:
				return 3
			return 2 if absf(u - 0.5) < 0.02 or absf(v - 0.63) < 0.02 else 1
		"daily_fresh":   # a round head of cabbage with leaf veins
			var d := pow((u - 0.5) / 0.4, 2.0) + pow((v - 0.56) / 0.36, 2.0)
			if d > 1.0:
				return 0
			return 2 if absf(u - 0.5) < 0.03 or absf((u - 0.5) - (v - 0.56) * 0.8) < 0.025 else 1
		"coffee":   # a paper cup with a lid and a sleeve
			if v < 0.14 or v > 0.92:
				return 0
			if v < 0.24:
				return 3 if absf(u - 0.5) <= 0.36 else 0
			var half_k := 0.32 - (v - 0.24) / 0.68 * 0.08
			if absf(u - 0.5) > half_k:
				return 0
			return 2 if v >= 0.48 and v <= 0.66 else 1
		"daily_goods":   # a hanging pack: a card header with a hole and a soft bag below
			if u < 0.2 or u > 0.8 or v < 0.1 or v > 0.92:
				return 0
			if v < 0.26:
				return 0 if pow(u - 0.5, 2.0) + pow(v - 0.18, 2.0) < 0.004 else 3
			return 2 if absf(v - 0.4) < 0.025 else 1
		"hygiene":   # a flat box with a band (no cross: the red cross is a protected emblem)
			if u < 0.14 or u > 0.86 or v < 0.24 or v > 0.86:
				return 0
			if v < 0.34:
				return 3
			return 2 if absf(v - 0.5) < 0.06 else 1
		"capsule_toy":   # a round capsule: a coloured top half and a clear bottom half
			var r := pow(u - 0.5, 2.0) + pow(v - 0.55, 2.0)
			if r > 0.36 * 0.36:
				return 0
			if absf(v - 0.55) < 0.025:
				return 2
			return 1 if v < 0.55 else 3
		"ice_cream":
			if pow(u - 0.5, 2.0) + pow(v - 0.36, 2.0) <= 0.28 * 0.28:
				return 1
			if v < 0.5 or v > 0.96:
				return 0
			var half_c := 0.26 * (0.96 - v) / 0.46
			return 2 if absf(u - 0.5) <= half_c else 0
	return 0


static func _color_for(category: String, hit: int, body: Color) -> Color:
	match category:
		"rice_ball":
			return NORI_COLOR if hit == 2 else body
		"drink":
			if hit == 2:
				return body.darkened(0.45)
			return body.lightened(0.3) if hit == 3 else body
		"instant_noodle":
			if hit == 2:
				return body.darkened(0.3)
			return body.lightened(0.4) if hit == 3 else body
		"bread", "snack":
			return body.darkened(0.35) if hit == 2 else body
		"dessert":
			return body.lightened(0.5) if hit == 3 else body
		"oden":
			return BROTH_COLOR if hit == 3 else body
		"ice_cream":
			return CONE_COLOR if hit == 2 else body
		"bento":
			if hit == 3:
				return body.lightened(0.6)
			return body.darkened(0.35) if hit == 2 else body
		"daily_fresh":
			return body.darkened(0.3) if hit == 2 else body
		"coffee":
			if hit == 3:
				return Color(0.95, 0.95, 0.92)
			return body.darkened(0.4) if hit == 2 else body
		"capsule_toy":
			if hit == 3:
				return Color(0.92, 0.95, 0.98)
			return body.darkened(0.3) if hit == 2 else body
		"daily_goods", "hygiene":
			if hit == 3:
				return Color(0.96, 0.96, 0.94)
			return body.darkened(0.3) if hit == 2 else body
	return body


## Label plate area per category, in normalised icon coordinates.
static func _plate_rect(category: String) -> Rect2:
	match category:
		"rice_ball":
			return Rect2(0.36, 0.36, 0.28, 0.14)
		"drink":
			return Rect2(0.32, 0.5, 0.36, 0.2)
		"instant_noodle":
			return Rect2(0.3, 0.4, 0.4, 0.2)
		"bread":
			return Rect2(0.3, 0.5, 0.4, 0.16)
		"snack":
			return Rect2(0.26, 0.4, 0.48, 0.22)
		"dessert":
			return Rect2(0.3, 0.6, 0.4, 0.16)
		"oden":
			return Rect2(0.34, 0.56, 0.32, 0.14)
		"ice_cream":
			return Rect2(0.36, 0.3, 0.28, 0.12)
		"bento":
			return Rect2(0.3, 0.7, 0.4, 0.12)
		"daily_fresh":
			return Rect2(0.34, 0.66, 0.32, 0.12)
		"coffee":
			return Rect2(0.36, 0.5, 0.28, 0.12)
		"capsule_toy":
			return Rect2(0.36, 0.62, 0.28, 0.1)
		"daily_goods":
			return Rect2(0.3, 0.6, 0.4, 0.14)
		"hygiene":
			return Rect2(0.3, 0.64, 0.4, 0.14)
	return Rect2(0.3, 0.4, 0.4, 0.2)


## Each label character becomes a 3x4 dot glyph taken from its hash bits (a stand-in mark, not text).
static func _plate_pixel(plate: Rect2, glyphs: Array[int], u: float, v: float) -> Color:
	var lx := (u - plate.position.x) / plate.size.x
	var ly := (v - plate.position.y) / plate.size.y
	const INSET := 0.12
	if lx < INSET or lx > 1.0 - INSET or ly < 0.15 or ly > 0.85:
		return PLATE_COLOR
	var gx := (lx - INSET) / (1.0 - 2.0 * INSET)
	var gy := (ly - 0.15) / 0.7
	var n := glyphs.size()
	var ci := clampi(int(gx * n), 0, n - 1)
	var col := clampi(int(fposmod(gx * n, 1.0) * 3.0), 0, 2)
	var row := clampi(int(gy * 4.0), 0, 3)
	var bit := (glyphs[ci] >> (row * 3 + col)) & 1
	return INK_COLOR if bit == 1 else PLATE_COLOR


static func _tint(category: String) -> Color:
	match category:
		"rice_ball":
			return Color(0.96, 0.96, 0.92)
		"drink":
			return Color(0.35, 0.65, 0.9)
		"instant_noodle":
			return Color(0.95, 0.6, 0.25)
		"bread":
			return Color(0.85, 0.66, 0.38)
		"snack":
			return Color(0.9, 0.3, 0.35)
		"dessert":
			return Color(0.98, 0.7, 0.8)
		"oden":
			return Color(0.72, 0.45, 0.25)
		"ice_cream":
			return Color(0.6, 0.85, 0.95)
		"bento":
			return Color(0.85, 0.35, 0.25)
		"daily_fresh":
			return Color(0.55, 0.8, 0.4)
		"coffee":
			return Color(0.92, 0.88, 0.8)
		"capsule_toy":
			return Color(0.9, 0.35, 0.6)
		"daily_goods":
			return Color(0.45, 0.55, 0.8)
		"hygiene":
			return Color(0.45, 0.8, 0.9)
	return Color(0.7, 0.7, 0.7)


## Category tint nudged by the SKU hash, so SKUs in one category still look different.
static func _body_color(sku_id: String, category: String) -> Color:
	var h := _hash(sku_id + "|" + category)
	var base := _tint(category)
	var hue := fposmod(base.h + (float(h & 0xFF) / 255.0 - 0.5) * 0.08, 1.0)
	var sat := clampf(base.s + (float((h >> 8) & 0xFF) / 255.0 - 0.5) * 0.16, 0.0, 1.0)
	var val := clampf(base.v + (float((h >> 16) & 0xFF) / 255.0 - 0.5) * 0.14, 0.0, 1.0)
	return Color.from_hsv(hue, sat, val)


## FNV-1a 32-bit. Explicit so colours and glyphs stay identical across Godot builds.
static func _hash(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h


static func _in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _edge_side(p, a, b)
	var d2 := _edge_side(p, b, c)
	var d3 := _edge_side(p, c, a)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


static func _edge_side(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
