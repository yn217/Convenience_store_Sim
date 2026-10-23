class_name ProductSprites
extends RefCounted
## Manifest-driven product sprites (Codex art, iso2x_v1). A visual_id maps to a shared shape with four
## direction PNGs. Each direction is cropped to its alpha bounds once and cached as an ImageTexture.
## On-screen size follows the shape's dimensions_m height through the projection's metres-to-pixels scale,
## so a 500 ml bottle stands taller than an onigiri. Pure helpers are static; caching is per instance.

const DIR := "res://assets/generated/products"
const MANIFEST := DIR + "/products_manifest.json"
## Readability exaggeration applied to every shape; relative sizes still follow dimensions_m.
const ITEM_SCALE := 2.2
## Below this zoom the half-resolution crop is drawn (the "small" LOD). From it on, the full crop.
const SMALL_ZOOM := 0.9
## Shapes whose front and back are both labelled: their facing may alternate between two opposite directions.
const SYMMETRIC_SHAPES := ["bottle_500", "cup_noodle", "dessert_cup", "ice_bar_pack"]
## Per-SKU colour multipliers. A category shares one shape, so the tint is what tells its SKUs apart.
const PALETTE := [Color(1, 1, 1), Color(1.0, 0.9, 0.86), Color(0.86, 0.95, 1.0), Color(0.93, 1.0, 0.86)]
## Category colour multiplier: cups, bags and packs that share a silhouette still read as different categories.
const CATEGORY_TINT := {
	"rice_ball": Color(1, 1, 1), "oden": Color(0.95, 0.8, 0.7), "instant_noodle": Color(1, 0.86, 0.5),
	"bread": Color(1, 0.9, 0.72), "drink": Color(0.9, 0.97, 1), "snack": Color(1, 0.85, 0.8),
	"dessert": Color(0.9, 0.84, 1), "ice_cream": Color(0.8, 1, 1),
}

var _manifest: Dictionary = {}
var _loaded := false
var _cache: Dictionary = {}
var _heights: Dictionary = {}   # shape_id -> dimensions_m.height


## Sprite for one SKU at a fixture rotation: {"texture": ImageTexture, "size": Vector2, "height_m": float, "shape_id": String}
## or {}. `size` is the full-resolution crop in texels (the logical size); `texture` is the small LOD when `small`.
func sprite(visual_id: String, rotation: int, variant: int = 0, small: bool = false) -> Dictionary:
	_load_manifest()
	var spec: Dictionary = _manifest.get(visual_id, {})
	if spec.is_empty():
		return {}
	var shape := String(spec.get("shape_id", ""))
	var dir := direction_for(rotation, variant, shape in SYMMETRIC_SHAPES)
	var key := "%s/%d/%s" % [visual_id, dir, "s" if small else "f"]
	if _cache.has(key):
		return _cache[key]
	var out := _build(spec, shape, dir, small)
	_cache[key] = out
	return out


## {"sku_id", "shape_id", "texture", "rotation"} of the full-resolution sprite, or {} (kept for ProductOverlayPlan).
func entry(visual_id: String, rotation: int) -> Dictionary:
	var s := sprite(visual_id, rotation)
	if s.is_empty():
		return {}
	return {
		"sku_id": String(_manifest[visual_id].get("sku_id", "")),
		"shape_id": s["shape_id"],
		"texture": s["texture"],
		"rotation": posmod(rotation, 4),
	}


func has_visual(visual_id: String) -> bool:
	_load_manifest()
	return _manifest.has(visual_id)


func visual_count() -> int:
	_load_manifest()
	return _manifest.size()


## Direction index for a fixture rotation. Symmetric shapes alternate with `variant` between the
## direction and its opposite; every other shape always faces the fixture rotation.
static func direction_for(rotation: int, variant: int, symmetric: bool) -> int:
	var r := posmod(rotation, 4)
	if symmetric and posmod(variant, 2) == 1:
		return posmod(r + 2, 4)
	return r


## Screen size in pixels of a sprite entry at a zoom. Scale comes from the height in metres:
## metres -> screen height through IsoProjection.Z_PX_PER_M, then the crop height in texels.
static func screen_size(entry: Dictionary, zoom: float) -> Vector2:
	var size: Vector2 = entry.get("size", Vector2.ZERO)
	if size.y <= 0.0:
		return Vector2.ZERO
	var k := float(entry["height_m"]) * ITEM_SCALE * IsoProjection.Z_PX_PER_M * zoom / size.y
	return size * k


## "bar" (far), "small" (half-resolution sprites) or "full" (full sprites). The bar cut-off is ShelfDisplay's.
static func sprite_lod(zoom: float) -> String:
	if ShelfDisplay.lod(zoom) == "bar":
		return "bar"
	return "small" if zoom < SMALL_ZOOM else "full"


## Which stock picture a row shows, from the same item counts the presenter draws.
static func stock_state(qty: int, capacity: int) -> String:
	match ShelfDisplay.item_count(qty, capacity):
		0:
			return "empty"
		2:
			return "low"
		5:
			return "medium"
	return "full"


## Facing variant of item `index` in a slot: alternates item to item, with a per-slot phase. Deterministic.
static func variant_for(slot_id: String, index: int) -> int:
	return posmod(slot_id.hash() + index, 2)


## Horizontal screen jitter of item `index` in a slot, -1, 0 or +1 px. Deterministic, so frames never differ.
static func jitter_px(slot_id: String, index: int) -> float:
	return float(posmod((slot_id + "#" + str(index)).hash(), 3) - 1)


## Colour multiplier of a SKU: its category's tint times a PALETTE entry. "rice_001" -> entry 0, "rice_002" -> entry 1.
static func tint_for(sku_id: String, category: String = "") -> Color:
	var n := sku_id.right(3).to_int()
	var idx := posmod(n - 1, PALETTE.size()) if n > 0 else posmod(sku_id.hash(), PALETTE.size())
	return CATEGORY_TINT.get(category, Color(1, 1, 1)) * PALETTE[idx]


func _build(spec: Dictionary, shape: String, dir: int, small: bool) -> Dictionary:
	var rel := String(spec.get("directions", {}).get(str(dir), ""))
	if rel.is_empty():
		return {}
	var tex := load("%s/%s" % [DIR, rel]) as Texture2D
	if tex == null:
		return {}
	var img := tex.get_image()
	if img == null:
		return {}
	var rect := img.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var crop := img.get_region(rect)
	var height_m := _height_m(shape)
	if height_m <= 0.0:
		return {}
	if small:
		crop.resize(maxi(1, rect.size.x / 2), maxi(1, rect.size.y / 2), Image.INTERPOLATE_BILINEAR)
	return {
		"texture": ImageTexture.create_from_image(crop),
		"size": Vector2(rect.size),
		"height_m": height_m,
		"shape_id": shape,
	}


func _height_m(shape: String) -> float:
	if _heights.has(shape):
		return _heights[shape]
	var h := 0.0
	var path := "%s/%s/%s.product.json" % [DIR, shape, shape]
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			h = float(json.data.get("dimensions_m", {}).get("height", 0.0))
	_heights[shape] = h
	return h


func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(MANIFEST)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var root: Dictionary = json.data
	if typeof(root.get("products", {})) == TYPE_DICTIONARY:
		_manifest = root["products"]
