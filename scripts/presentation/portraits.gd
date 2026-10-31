class_name Portraits
extends RefCounted
## Round head-and-shoulders portraits for the panels (ComfyUI renders, tools/assets/build_character_ui.py; 144 px for a
## 96 px slot). A customer's portrait is the one of its in-store look (CustomerSprites.variant_for), so the panel and
## the figure on the floor match; a staff member's is picked from the staff set by name, so the same person keeps the
## same face from candidate to hire. Presentation only: the face never says anything about budget or character (#141).

const DIR := "res://assets/ui/portraits/"
const STAFF: Array[String] = ["staff_1", "staff_2", "staff_3", "staff_4"]

static var _cache := {}


## Portrait id of a customer or staff id ("" when the look has no portrait).
static func id_for_customer(customer_id: String, staff_name: String = "") -> String:
	if customer_id.begins_with("staff_"):
		return id_for_staff(staff_name if staff_name != "" else customer_id)
	return CustomerSprites.variant_for(customer_id).trim_prefix(CustomerSprites.CHIBI)


## Portrait id of a staff member or candidate, stable for the same name.
static func id_for_staff(name: String) -> String:
	var h := 0
	for i in name.length():
		h = (h * 31 + name.unicode_at(i)) % 1000003   # not String.hash(): stable across runs and platforms
	return STAFF[h % STAFF.size()]


static func texture(portrait_id: String) -> Texture2D:
	if portrait_id == "":
		return null
	if not _cache.has(portrait_id):
		var path := DIR + portrait_id + ".png"
		_cache[portrait_id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[portrait_id]


## A TextureRect for a portrait slot of `side` px.
static func make_rect(side: float) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(side, side)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
