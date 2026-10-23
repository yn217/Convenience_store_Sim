class_name FixtureThumbnails
extends RefCounted
## Build-palette thumbnails (#61): the rotation-0 body sprite of a fixture type (from its manifest, see FixtureSprites),
## cropped to its visible pixels and fitted into a SIZE x SIZE transparent square. Built once per type and cached;
## a type without a sprite gets null (the palette row then stays text-only).

const SIZE := 56

static var _cache: Dictionary = {}


static func texture(type_id: String) -> Texture2D:
	if _cache.has(type_id):
		return _cache[type_id]
	var tex := _build(type_id)
	_cache[type_id] = tex
	return tex


static func cached_count() -> int:
	return _cache.size()


static func _build(type_id: String) -> Texture2D:
	var entry := FixtureSprites.new().rotation_entry(type_id, 0)
	if entry.is_empty():
		return null
	var body := entry["layers"].get("body") as Texture2D
	if body == null:
		return null
	var src := body.get_image()
	if src == null or src.is_empty():
		return null
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var crop := src.get_region(used)
	var fit := minf(float(SIZE) / used.size.x, float(SIZE) / used.size.y)
	var w := maxi(1, roundi(used.size.x * fit))
	var h := maxi(1, roundi(used.size.y * fit))
	crop.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(crop, Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((SIZE - w) / 2, (SIZE - h) / 2))
	return ImageTexture.create_from_image(out)
