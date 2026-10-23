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
var _people := CustomerSprites.new()
## Presentation-only state of the people shown (never saved, never read by the simulation):
## smoothed tile position, last facing, and the animation clock in game seconds (frozen at speed 0).
var _pos: Dictionary = {}
var _facing: Dictionary = {}
var anim_time: float = 0.0


func _ready() -> void:
	_world = get_parent().get_parent()


func _process(delta: float) -> void:
	if _world == null or _world.customers.is_empty() or _world.speed_setting <= 0:
		return
	var dt := delta * float(_world.speed_setting)
	anim_time += dt
	_sync_customers(dt)
	queue_redraw()


## Where the customer is aimed (tile units): the current tile moved toward the next path tile.
static func target_pos(c: Dictionary) -> Vector2:
	var t: Vector2i = c["tile"]
	var n: Vector2i = c.get("next", t)
	return Vector2(t) + Vector2(n - t) * float(c.get("progress", 0.0))


## Eases the shown positions toward the simulation's and keeps each person's facing.
func _sync_customers(dt: float) -> void:
	var alive := {}
	for c in _world.customers:
		var id: String = c["customer_id"]
		alive[id] = true
		var target := target_pos(c)
		if not _pos.has(id) or (_pos[id] as Vector2).distance_to(target) > 2.5:
			_pos[id] = target
			if not _facing.has(id):
				_facing[id] = CustomerSprites.facing_for(Vector2(c.get("next", c["tile"]) - c["tile"]), CustomerSprites.FACING_E)
		else:
			var old: Vector2 = _pos[id]
			var now := old.lerp(target, 1.0 - exp(-dt * 3.0))
			_facing[id] = CustomerSprites.facing_for(target - old, int(_facing.get(id, CustomerSprites.FACING_E)))
			_pos[id] = now
	for id in _pos.keys():
		if not alive.has(id):
			_pos.erase(id)
			_facing.erase(id)


## What is drawn for a customer now: {"pos", "facing", "anim", "frame", "variant"}.
func customer_view(c: Dictionary) -> Dictionary:
	var id: String = c["customer_id"]
	var anim := CustomerSprites.anim_for(c["phase"])
	var variant_id := CustomerSprites.variant_for(id)
	var sheet := _people.variant(variant_id)
	var frame := 0
	if not sheet.is_empty():
		frame = CustomerSprites.frame_index(sheet["animations"][anim], anim_time + float(id.hash() % 7) * 0.37)
	return {"pos": _pos.get(id, target_pos(c)), "facing": int(_facing.get(id, CustomerSprites.FACING_E)), "anim": anim, "frame": frame, "variant": variant_id}


const CUSTOMER_HEIGHT_M := 1.6
const CUSTOMER_HALF_W_M := 0.16
const CUSTOMER_COLOR := Color("3d6fb5")
const OUTLINE_ZOOM := 1.5
const FADE_ALPHA := 0.35
const XRAY_ALPHA := 0.5


## The draw list in back-to-front order: {"kind": "fixture"|"customer", "rect": Rect2, ...}.
func compose() -> Array:
	var items: Array = _fixture_items().duplicate()
	for it in items:
		it.erase("fade")
	_sync_customers(0.0)
	for c in _world.customers:
		var shown: Vector2 = _pos.get(c["customer_id"], target_pos(c))
		var cell := Vector2i(roundi(shown.x), roundi(shown.y))
		items.append({"kind": "customer", "rect": DrawOrder.cell_rect(cell), "customer": c, "pos": shown})
	var sorted := DrawOrder.sorted(items)
	_mark_see_through(sorted)
	return sorted


## Segment items of the fixtures; rebuilt only when the layout revision changes.
var _fixture_items_cache: Array = []
var _fixture_items_key := [-1, -1]


func _fixture_items() -> Array:
	var key := [_world.revision, _world.fixtures.size()]
	if key == _fixture_items_key:
		return _fixture_items_cache
	_fixture_items_key = key
	_fixture_items_cache = []
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
			_fixture_items_cache.append({
				"kind": "fixture", "rect": segs[k]["rect"], "inst": inst, "def": def, "lo": lo, "hi": hi,
				"column": segs[k]["column"], "first": k == 0, "last": k == segs.size() - 1,
			})
	return _fixture_items_cache


## Things that stand in front of the selected fixture / customer and cover it are drawn translucent,
## so what the player picked stays readable behind a tall case (#24).
func _mark_see_through(items: Array) -> void:
	var proj: IsoProjection = _world.projection
	var rect := Rect2()
	var bounds := Rect2()
	var found := false
	var sel_id: String = _world.selected_fixture_id()   # once per draw, not once per item
	for it in items:
		if it["kind"] == "fixture" and sel_id == it["inst"]["instance_id"]:
			rect = it["rect"] if not found else rect.merge(it["rect"])
			bounds = _fixture_bounds(proj, it) if not found else bounds.merge(_fixture_bounds(proj, it))
			found = true
		elif it["kind"] == "customer" and _world.selected_customer == it["customer"]["customer_id"]:
			rect = it["rect"]
			bounds = OverlayModel.customer_rect(proj, it["pos"])
			found = true
	if not found:
		return
	for it in items:
		if it["kind"] != "fixture" or sel_id == it["inst"]["instance_id"]:
			continue
		if DrawOrder.is_behind(rect, it["rect"]) and _fixture_bounds(proj, it).intersects(bounds):
			it["fade"] = true


func _fixture_bounds(proj: IsoProjection, it: Dictionary) -> Rect2:
	var cells := StoreGrid.footprint_cells(it["def"]["footprint"], it["inst"]["x"], it["inst"]["y"], it["inst"]["rotation"])
	return OverlayModel.fixture_bounds(proj, cells, float(it["def"]["dimensions_m"]["height"]))


## Customers hidden behind a fixture get a translucent copy on top (information / layout modes).
func hidden_customers(items: Array) -> Array:
	var out: Array = []
	var proj: IsoProjection = _world.projection
	for it in items:
		if it["kind"] != "customer":
			continue
		var r := OverlayModel.customer_rect(proj, it["pos"])
		for other in items:
			if other["kind"] == "fixture" and DrawOrder.is_behind(it["rect"], other["rect"]) and _fixture_bounds(proj, other).intersects(r):
				out.append(it)
				break
	return out


func _draw() -> void:
	if _world == null or _world.fixture_catalog == null:
		return
	var t0 := Time.get_ticks_usec()
	_draw_all()
	draw_usec_total += Time.get_ticks_usec() - t0
	draw_count += 1


## Cost of the script side of drawing (for tools/perf_bench.gd).
var draw_usec_total := 0
var draw_count := 0
var prof_compose := 0
var prof_customers := 0
var prof_fixtures := 0


func _draw_all() -> void:
	var proj: IsoProjection = _world.projection
	var boxes_done := {}
	var q0 := Time.get_ticks_usec()
	var ordered := compose()
	prof_compose += Time.get_ticks_usec() - q0
	for it in ordered:
		if it["kind"] == "customer":
			q0 = Time.get_ticks_usec()
			_draw_customer(proj, it["customer"])
			prof_customers += Time.get_ticks_usec() - q0
			continue
		var entry := _sprites.rotation_entry(it["inst"]["type_id"], int(it["inst"]["rotation"]))
		if not entry.is_empty():
			q0 = Time.get_ticks_usec()
			_draw_sprite(proj, it, entry)
			prof_fixtures += Time.get_ticks_usec() - q0
		elif not boxes_done.has(it["inst"]["instance_id"]):
			boxes_done[it["inst"]["instance_id"]] = true   # the placeholder is one box, drawn with its first segment in order
			_draw_box(proj, it)
	if _world.overlay_mode != OverlayModel.Mode.NORMAL or _world.selected_customer != "":
		for it in hidden_customers(ordered):
			_draw_customer(proj, it["customer"], XRAY_ALPHA)


## Sprite person (#23); a plain bar stands in when the art is missing. Anchor = feet, shared by all frames.
func _draw_customer(proj: IsoProjection, c: Dictionary, alpha: float = 1.0) -> void:
	var view := customer_view(c)
	var pos: Vector2 = view["pos"]
	var sheet := _people.variant(view["variant"])
	if sheet.is_empty():
		_draw_customer_bar(proj, pos)
		return
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var top_left := proj.sprite_top_left(proj.world_to_screen(pos.x, pos.y), sheet["anchor"])
	var shadow: Texture2D = sheet["shadow"]
	var tint := Color(1, 1, 1, alpha)
	draw_texture_rect(shadow, Rect2(top_left, shadow.get_size() * s), false, tint)
	var tex: Texture2D = sheet["frames"][view["facing"]][view["anim"]][view["frame"]]
	draw_texture_rect(tex, Rect2(top_left, tex.get_size() * s), false, tint)


func _draw_customer_bar(proj: IsoProjection, pos: Vector2) -> void:
	var foot := proj.world_to_screen(pos.x, pos.y)
	var hw := CUSTOMER_HALF_W_M * IsoProjection.HALF_TILE_W * proj.zoom
	draw_colored_polygon(_ellipse(foot, hw * 1.6, hw * 0.8), Color(0, 0, 0, 0.25))
	var top := proj.world_to_screen(pos.x, pos.y, CUSTOMER_HEIGHT_M)
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
	var tint := Color(1, 1, 1, FADE_ALPHA if it.get("fade", false) else 1.0)
	var layers: Dictionary = entry["layers"]
	for name in FixtureSprites.LAYER_ORDER_BELOW:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint)
	_draw_products(it, entry, top_left, s, proj.zoom, strip, tint.a)
	for name in FixtureSprites.LAYER_ORDER_ABOVE:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint)


func _blit(tex: Texture2D, top_left: Vector2, s: float, strip: Vector2, tint: Color = Color.WHITE) -> void:
	var size := tex.get_size()
	var u0 := clampf((strip.x - top_left.x) / s, 0.0, size.x)
	var u1 := clampf((strip.y - top_left.x) / s, 0.0, size.x)
	if u1 - u0 < 0.5:
		return
	draw_texture_rect_region(tex, Rect2(top_left + Vector2(u0 * s, 0.0), Vector2(u1 - u0, size.y) * s), Rect2(u0, 0.0, u1 - u0, size.y), tint)


func _draw_products(it: Dictionary, entry: Dictionary, top_left: Vector2, s: float, zoom: float, strip: Vector2, alpha: float = 1.0) -> void:
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
			draw_rect(r, Color(color, alpha))
			if zoom >= OUTLINE_ZOOM:   # the outline doubles the draw commands; small items read fine without it
				draw_rect(r, Color(color.darkened(0.45), alpha), false, 1.0)


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
