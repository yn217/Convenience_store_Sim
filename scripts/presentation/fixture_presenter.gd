extends Node2D
## Fixtures and customers composed back to front (#9, #26). Manifest sprites where generated,
## placeholder boxes otherwise. Read-only: draws the snapshot's fixtures and customers.
## A fixture is cut into screen-column segments (DrawOrder) so a customer can stand in front of one
## end of a long shelf and behind the other; each segment draws its own slice of the sprite layers
## (shadow, body, products, glass front) and the slice order follows DrawOrder, never one depth per fixture.
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


const CUSTOMER_HEIGHT_M := 1.6
const CUSTOMER_HALF_W_M := 0.16
const CUSTOMER_COLOR := Color("3d6fb5")


## The draw list in back-to-front order: {"kind": "fixture"|"customer", "rect": Rect2, ...}.
func compose() -> Array:
	var items: Array = []
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-1, -1)
		for c in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var segs := DrawOrder.column_segments(cells)
		for k in segs.size():
			items.append({
				"kind": "fixture", "rect": segs[k]["rect"], "inst": inst, "def": def, "lo": lo, "hi": hi,
				"column": segs[k]["column"], "first": k == 0, "last": k == segs.size() - 1,
			})
	for c in _world.customers:
		items.append({"kind": "customer", "rect": DrawOrder.cell_rect(c["tile"]), "customer": c})
	return DrawOrder.sorted(items)


func _draw() -> void:
	if _world == null or _world.fixture_catalog == null:
		return
	var proj: IsoProjection = _world.projection
	var boxes_done := {}
	for it in compose():
		if it["kind"] == "customer":
			_draw_customer(proj, it["customer"])
			continue
		var entry := _sprites.rotation_entry(it["inst"]["type_id"], int(it["inst"]["rotation"]))
		if not entry.is_empty():
			_draw_sprite(proj, it, entry)
		elif not boxes_done.has(it["inst"]["instance_id"]):
			boxes_done[it["inst"]["instance_id"]] = true   # the placeholder is one box, drawn with its first segment in order
			_draw_box(proj, it)


## Placeholder person until the customer sprites arrive (#23): shadow ellipse and a body bar.
func _draw_customer(proj: IsoProjection, c: Dictionary) -> void:
	var t: Vector2i = c["tile"]
	var foot := proj.world_to_screen(t.x, t.y)
	var hw := CUSTOMER_HALF_W_M * IsoProjection.HALF_TILE_W * proj.zoom
	draw_colored_polygon(_ellipse(foot, hw * 1.6, hw * 0.8), Color(0, 0, 0, 0.25))
	var top := proj.world_to_screen(t.x, t.y, CUSTOMER_HEIGHT_M)
	var body := Rect2(Vector2(foot.x - hw, top.y), Vector2(hw * 2.0, foot.y - top.y))
	draw_rect(body, CUSTOMER_COLOR)
	draw_rect(body, CUSTOMER_COLOR.darkened(0.5), false, 1.0)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Screen x range owned by this segment's column (a tile diamond is 2 * HALF_TILE_W * zoom wide);
## the outermost segments reach past the sprite edge so nothing of the sprite is lost.
func _strip(proj: IsoProjection, it: Dictionary) -> Vector2:
	var lo: Vector2i = it["lo"]
	var hw := IsoProjection.HALF_TILE_W * proj.zoom
	var x_center := proj.world_to_screen(lo.x, lo.y).x + float(int(it["column"]) - (lo.x - lo.y)) * hw
	var x0 := x_center - hw
	var x1 := x_center + hw
	if it["first"]:
		x0 = -1e6
	if it["last"]:
		x1 = 1e6
	return Vector2(x0, x1)


## Layers back to front: shadow, body, products, glass_front, each cut to this segment's column.
func _draw_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var ground := proj.world_to_screen(lo.x, lo.y)
	var top_left := proj.sprite_top_left(ground, entry["anchor"])
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var strip := _strip(proj, it)
	var layers: Dictionary = entry["layers"]
	for name in FixtureSprites.LAYER_ORDER_BELOW:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip)
	_draw_products(it, entry, top_left, s, proj.zoom, strip)
	for name in FixtureSprites.LAYER_ORDER_ABOVE:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip)


func _blit(tex: Texture2D, top_left: Vector2, s: float, strip: Vector2) -> void:
	var size := tex.get_size()
	var u0 := clampf((strip.x - top_left.x) / s, 0.0, size.x)
	var u1 := clampf((strip.y - top_left.x) / s, 0.0, size.x)
	if u1 - u0 < 0.5:
		return
	draw_texture_rect_region(tex, Rect2(top_left + Vector2(u0 * s, 0.0), Vector2(u1 - u0, size.y) * s), Rect2(u0, 0.0, u1 - u0, size.y))


func _draw_products(it: Dictionary, entry: Dictionary, top_left: Vector2, s: float, zoom: float, strip: Vector2) -> void:
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
			_draw_row_bar(slots, sid, ShelfDisplay.fill_ratio(qty, cap), color, top_left, s, strip)
			continue
		var n := mini(ShelfDisplay.visible_items(qty, cap, zoom), _anchor_count(slots, sid))
		# Item 0 is the end nearest the viewer's right; draw far items first so near ones overlap.
		for i in range(n - 1, -1, -1):
			var a: Vector2 = top_left + slots["%s_item%d" % [sid, i]] * s
			if a.x < strip.x or a.x >= strip.y:
				continue   # belongs to another column segment
			var half := ITEM_W * 0.5 * s
			var r := Rect2(a - Vector2(half, ITEM_H * s), Vector2(ITEM_W * s, ITEM_H * s))
			draw_rect(r, color)
			draw_rect(r, color.darkened(0.45), false, 1.0)


func _anchor_count(slots: Dictionary, sid: String) -> int:
	var n := 0
	while slots.has("%s_item%d" % [sid, n]):
		n += 1
	return n


func _draw_row_bar(slots: Dictionary, sid: String, ratio: float, color: Color, top_left: Vector2, s: float, strip: Vector2) -> void:
	var a: Vector2 = top_left + slots["%s_item0" % sid] * s
	var last := _anchor_count(slots, sid) - 1
	var b: Vector2 = top_left + slots["%s_item%d" % [sid, last]] * s
	if last == 0:
		b = a + Vector2(18.0 * s, 9.0 * s)   # single-cell slot: short bar along the +X screen direction
	var mid := (a.x + b.x) * 0.5
	if mid < strip.x or mid >= strip.y:
		return   # the bar is drawn by the segment that holds its middle
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
