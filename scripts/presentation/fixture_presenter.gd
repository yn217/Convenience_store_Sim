extends Node2D
## Fixtures: manifest sprites where generated (#9), placeholder boxes otherwise. Read-only: draws the
## snapshot's fixture list with the catalog dimensions, back-to-front by footprint position.
## The yellow edge marks the customer-facing access side, so rotation is visible.

const CATEGORY_COLOR := {
	"rice_ball": Color("e8a87c"), "oden": Color("c0794a"), "instant_noodle": Color("e6c35c"),
	"bread": Color("d9b38c"), "drink": Color("5caefd"), "snack": Color("e07a9a"),
	"dessert": Color("b79bdc"), "ice_cream": Color("8fd6e0"),
}
const REGISTER_COLOR := Color("7f8c99")
const FRONT_COLOR := Color("ffc873")
const INSET := 0.46
## Product placeholder size in source px (anchor = bottom centre of the item).
const ITEM_W := 22.0
const ITEM_H := 30.0

var _world: Node2D
var _sprites := FixtureSprites.new()


func _ready() -> void:
	_world = get_parent().get_parent()


func _draw() -> void:
	if _world == null or _world.fixture_catalog == null:
		return
	var proj: IsoProjection = _world.projection
	var items: Array = []
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-1, -1)
		for c in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		items.append({"inst": inst, "def": def, "lo": lo, "hi": hi, "depth": hi.x + hi.y})
	items.sort_custom(func(a, b): return a["depth"] < b["depth"])
	for it in items:
		var entry := _sprites.rotation_entry(it["inst"]["type_id"], int(it["inst"]["rotation"]))
		if entry.is_empty():
			_draw_box(proj, it)
		else:
			_draw_sprite(proj, it, entry)


## Layers back to front: shadow, body, products, glass_front. Source px scale by zoom / 2.
func _draw_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var ground := proj.world_to_screen(lo.x, lo.y)
	var top_left := proj.sprite_top_left(ground, entry["anchor"])
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var layers: Dictionary = entry["layers"]
	for name in FixtureSprites.LAYER_ORDER_BELOW:
		if layers.has(name):
			_blit(layers[name], top_left, s)
	_draw_products(it, entry, top_left, s, proj.zoom)
	for name in FixtureSprites.LAYER_ORDER_ABOVE:
		if layers.has(name):
			_blit(layers[name], top_left, s)


func _blit(tex: Texture2D, top_left: Vector2, s: float) -> void:
	draw_texture_rect(tex, Rect2(top_left, tex.get_size() * s), false)


func _draw_products(it: Dictionary, entry: Dictionary, top_left: Vector2, s: float, zoom: float) -> void:
	var slots: Dictionary = entry["slots"]
	if slots.is_empty():
		return
	var def: Dictionary = it["def"]
	var stock: Dictionary = _world.shelf_stock.get(it["inst"]["instance_id"], {})
	var color := _color_for(def)
	for slot in def["shelf_slots"]:
		var sid: String = slot["slot_id"]
		var qty := int(stock.get(sid, 0))
		var cap := int(slot["capacity_units"])
		if not slots.has("%s_item0" % sid):
			continue
		if ShelfDisplay.lod(zoom) == "bar":
			_draw_row_bar(slots, sid, ShelfDisplay.fill_ratio(qty, cap), color, top_left, s)
			continue
		var n := mini(ShelfDisplay.visible_items(qty, cap, zoom), _anchor_count(slots, sid))
		# Item 0 is the end nearest the viewer's right; draw far items first so near ones overlap.
		for i in range(n - 1, -1, -1):
			var a: Vector2 = top_left + slots["%s_item%d" % [sid, i]] * s
			var half := ITEM_W * 0.5 * s
			var r := Rect2(a - Vector2(half, ITEM_H * s), Vector2(ITEM_W * s, ITEM_H * s))
			draw_rect(r, color)
			draw_rect(r, color.darkened(0.45), false, 1.0)


func _anchor_count(slots: Dictionary, sid: String) -> int:
	var n := 0
	while slots.has("%s_item%d" % [sid, n]):
		n += 1
	return n


func _draw_row_bar(slots: Dictionary, sid: String, ratio: float, color: Color, top_left: Vector2, s: float) -> void:
	var a: Vector2 = top_left + slots["%s_item0" % sid] * s
	var last := _anchor_count(slots, sid) - 1
	var b: Vector2 = top_left + slots["%s_item%d" % [sid, last]] * s
	if last == 0:
		b = a + Vector2(18.0 * s, 9.0 * s)   # single-cell slot: short bar along the +X screen direction
	draw_line(a, b, Color(0, 0, 0, 0.25), 4.0)
	if ratio > 0.0:
		draw_line(a, a.lerp(b, ratio), color, 4.0)


func _color_for(def: Dictionary) -> Color:
	if def["allowed_categories"].is_empty():
		return REGISTER_COLOR
	return CATEGORY_COLOR.get(def["allowed_categories"][0], REGISTER_COLOR)


func _draw_box(proj: IsoProjection, it: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var hi: Vector2i = it["hi"]
	var h: float = float(it["def"]["dimensions_m"]["height"])
	var x0 := lo.x - INSET
	var y0 := lo.y - INSET
	var x1 := hi.x + INSET
	var y1 := hi.y + INSET
	var base := _color_for(it["def"])
	var a_g := proj.world_to_screen(x0, y0)
	var b_g := proj.world_to_screen(x1, y0)
	var c_g := proj.world_to_screen(x1, y1)
	var d_g := proj.world_to_screen(x0, y1)
	var a_t := proj.world_to_screen(x0, y0, h)
	var b_t := proj.world_to_screen(x1, y0, h)
	var c_t := proj.world_to_screen(x1, y1, h)
	var d_t := proj.world_to_screen(x0, y1, h)
	draw_colored_polygon(PackedVector2Array([b_g, c_g, c_t, b_t]), base.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([d_g, c_g, c_t, d_t]), base.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([a_t, b_t, c_t, d_t]), base)
	var edge := Color(0, 0, 0, 0.45)
	draw_polyline(PackedVector2Array([a_t, b_t, c_t, d_t, a_t]), edge, 1.5)
	draw_polyline(PackedVector2Array([d_t, d_g, c_g, c_t]), edge, 1.5)
	draw_line(c_g, b_g, edge, 1.5)
	var w := 4.0 * maxf(proj.zoom, 0.75)
	for e in it["def"]["access_edges"]:
		match PlacementRules.rotate_edge(e, it["inst"]["rotation"]):
			"N":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x1, y0, h), FRONT_COLOR, w)
			"E":
				draw_line(proj.world_to_screen(x1, y0, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"S":
				draw_line(proj.world_to_screen(x0, y1, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"W":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x0, y1, h), FRONT_COLOR, w)
