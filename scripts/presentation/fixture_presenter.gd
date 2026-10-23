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
## From this zoom on (and when the row is not in the far "bar" LOD) a shelf item without its sprite falls back to a
## code-made package icon (ProductIcons). Shelf items are Codex product sprites at every LOD above "bar".
const ICON_MIN_ZOOM := 0.9
const ICON_PX := 32
## Item size caps: height up to this share of the row gap to the board above; width up to this multiple of the
## spacing to the neighbour (so a neighbour overlaps by at most about 15%).
const ROW_FILL := 0.85
const SPACING_FILL := 1.15

var _world: Node2D
var _sprites := FixtureSprites.new()
var _people := CustomerSprites.new()
var _art := ProductSprites.new()   # Codex product sprites by visual_id and facing (cached per direction)
## Presentation-only state of the people shown (never saved, never read by the simulation):
## smoothed tile position, last facing, and the animation clock in game seconds (frozen at speed 0).
var _pos: Dictionary = {}
var _facing: Dictionary = {}
var _alive: Dictionary = {}   # ids seen by the current _sync_customers call (reused, not reallocated)
var _look: Dictionary = {}    # customer_id -> [sheet, variant_id, time offset]; fixed per customer, so computed once
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


## Presentation-only walk state per customer: {"hist": tiles walked so far (ends at the simulation's tile),
## "seen": steps already taken in from the simulation's trail, "s": shown position as an index into the chain
## hist + remaining path}. The shown position only moves along that chain, so it stays on tile centres.
## Forward motion also stops at every turning tile of the chain, so the straight line between two frames
## never cuts a corner, whatever the frame rate or the speed (x1, x2, x4) and however many steps one frame covers.
var _track: Dictionary = {}
## Catch-up rate of the shown position toward the simulation's (per unit of dt, which is real time x speed).
const SHOW_EASE := 120.0
const TRACK_KEEP := 4


## Moves the shown positions along each customer's walk and keeps each person's facing.
func _sync_customers(dt: float) -> void:
	_alive.clear()
	var k := 1.0 - exp(-dt * SHOW_EASE)   # same for every customer this call
	for c in _world.customers:
		var id: String = c["customer_id"]
		_alive[id] = true
		var tile: Vector2i = c["tile"]
		var path: Array = c.get("path", [])
		if not c.has("path") and c.has("next") and c["next"] != tile:
			path = [c["next"]]   # a view without the full path: the next tile is all there is
		var tr: Dictionary = _track.get(id, {})
		if tr.is_empty():
			tr = {"hist": [tile], "seen": int(c.get("moved", 0)), "s": 0.0}
			_track[id] = tr
			if not _facing.has(id):
				_facing[id] = CustomerSprites.facing_for(Vector2(c.get("next", tile) - tile), CustomerSprites.FACING_E)
		else:
			_take_steps(tr, c)
		var hist: Array = tr["hist"]
		var chain: Array = hist + path
		var target := float(hist.size() - 1)
		if not path.is_empty():
			target += float(c.get("progress", 0.0))
		var s0: float = tr["s"]
		var s := s0 + (target - s0) * k
		if s > s0:
			s = minf(s, _next_turn(chain, s0))
		tr["s"] = s
		var pos := _point_on(chain, s)
		var old: Vector2 = _pos.get(id, pos)
		if pos.distance_to(old) > 0.0001:
			_facing[id] = CustomerSprites.facing_for(pos - old, int(_facing.get(id, CustomerSprites.FACING_E)))
		_pos[id] = pos
	for id in _track.keys():
		if not _alive.has(id):
			_track.erase(id)
			_pos.erase(id)
			_facing.erase(id)
			_look.erase(id)


## Appends the tiles the simulation walked since the last call to the customer's history (from its trail).
## Any tile change the trail does not explain (a spawn, a teleport, a gap longer than the trail) restarts
## the history at the current tile: the one place where the shown position is placed rather than walked.
func _take_steps(tr: Dictionary, c: Dictionary) -> void:
	var tile: Vector2i = c["tile"]
	var moved := int(c.get("moved", 0))
	var new_steps := moved - int(tr["seen"])
	var hist: Array = tr["hist"]
	var trail: Array = c.get("trail", [])
	tr["seen"] = moved
	var still: bool = new_steps == 0 and hist.back() == tile
	var walked: bool = new_steps > 0 and new_steps <= trail.size() and trail.back() == tile
	if not (still or walked):
		hist.clear()
		hist.append(tile)
		tr["s"] = 0.0
		return
	for i in range(trail.size() - new_steps, trail.size()):
		hist.append(trail[i])
	while hist.size() > TRACK_KEEP and float(tr["s"]) >= 1.0:
		hist.pop_front()
		tr["s"] = float(tr["s"]) - 1.0


## First turning tile of the chain strictly after position s (the chain end when there is none).
static func _next_turn(chain: Array, s: float) -> float:
	var last := chain.size() - 1
	var i := int(floor(s)) + 1
	while i < last:
		if (chain[i] - chain[i - 1]) != (chain[i + 1] - chain[i]):
			return float(i)
		i += 1
	return float(last)


## Point at chain position s (index + fraction): always on the straight segment between two chain tiles.
static func _point_on(chain: Array, s: float) -> Vector2:
	if chain.size() == 1 or s <= 0.0:
		return Vector2(chain[0])
	var i := int(floor(s))
	if i >= chain.size() - 1:
		return Vector2(chain[chain.size() - 1])
	return Vector2(chain[i]).lerp(Vector2(chain[i + 1]), s - float(i))


## Sprite sheet, variant id and animation time offset of a customer, looked up once per id (not per frame).
func _look_for(id: String) -> Array:
	if not _look.has(id):
		var variant_id := CustomerSprites.variant_for(id)
		_look[id] = [_people.variant(variant_id), variant_id, float(id.hash() % 7) * 0.37]
	return _look[id]


## What is drawn for a customer now: {"pos", "facing", "anim", "frame", "variant"}.
func customer_view(c: Dictionary) -> Dictionary:
	var id: String = c["customer_id"]
	var anim := CustomerSprites.anim_for(c["phase"])
	var look := _look_for(id)
	var sheet: Dictionary = look[0]
	var frame := 0
	if not sheet.is_empty():
		frame = CustomerSprites.frame_index(sheet["animations"][anim], anim_time + float(look[2]))
	var pos: Vector2 = _pos[id] if _pos.has(id) else target_pos(c)
	return {"pos": pos, "facing": int(_facing.get(id, CustomerSprites.FACING_E)), "anim": anim, "frame": frame, "variant": look[1]}


const CUSTOMER_HEIGHT_M := 1.6
const CUSTOMER_HALF_W_M := 0.16
const CUSTOMER_COLOR := Color("3d6fb5")
const OUTLINE_ZOOM := 1.5
const FADE_ALPHA := 0.35
const XRAY_ALPHA := 0.5


## The draw list in back-to-front order: {"kind": "fixture"|"customer", "rect": Rect2, ...}.
func compose() -> Array:
	var fixture_items := _fixture_items()   # refreshes _fixed when the layout changed
	var fixed := _fixed
	_clear_fade()
	_sync_customers(0.0)
	var items: Array = fixture_items.duplicate()
	var cells: Array[Vector2i] = []
	for c in _world.customers:
		var shown: Vector2 = _pos.get(c["customer_id"], target_pos(c))
		var cell := Vector2i(roundi(shown.x), roundi(shown.y))
		items.append({"kind": "customer", "rect": DrawOrder.cell_rect(cell), "customer": c, "pos": shown})
		cells.append(cell)
	var sorted := DrawOrder.sorted_fixed(items, fixed, cells)
	_mark_see_through(sorted)
	return sorted


## Segment items of the fixtures; rebuilt only when the layout revision changes.
var _fixture_items_cache: Array = []
var _fixture_revision := -2
var _fixture_count := -1
var _fixed: DrawOrder.FixedSet   # the fixture segments in their depth order, rebuilt with them
var _faded: Array = []           # items given "fade" by the last compose, cleared by the next one


func _fixture_items() -> Array:
	if _world.revision == _fixture_revision and _world.fixtures.size() == _fixture_count:
		return _fixture_items_cache
	_fixture_revision = _world.revision
	_fixture_count = _world.fixtures.size()
	_fixture_items_cache = []
	_seg_cache.clear()   # segment keys and commands belong to the item list that was just rebuilt
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
	var rects: Array[Rect2] = []
	for it in _fixture_items_cache:
		rects.append(it["rect"])
	_fixed = DrawOrder.FixedSet.new(rects)
	return _fixture_items_cache


func _clear_fade() -> void:
	for it in _faded:
		it.erase("fade")
	_faded.clear()


## Things that stand in front of the selected fixture / customer and cover it are drawn translucent,
## so what the player picked stays readable behind a tall case (#24).
func _mark_see_through(items: Array) -> void:
	var proj: IsoProjection = _world.projection
	var rect := Rect2()
	var bounds := Rect2()
	var found := false
	var sel_id: String = _world.selected_fixture_id()   # once per draw, not once per item
	if sel_id == "" and _world.selected_customer == "":
		return   # nothing selected: nothing can be in front of it
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
			_faded.append(it)


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


## Retained draw commands of fixture segments (#25), keyed "instance_id/column". A segment's commands
## depend only on zoom, its screen ground point, its stock and its fade state, so they are rebuilt when
## one of those changes and replayed otherwise. Customers moving never invalidate them, and compose()
## order is unchanged because replay happens at the same point of the back-to-front loop.
var _seg_cache: Dictionary = {}


## Layers back to front: shadow, body, products, glass_front, each cut to this segment's column.
func _draw_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var ground := proj.world_to_screen(lo.x, lo.y)
	var stock: Dictionary = _world.shelf_stock.get(it["inst"]["instance_id"], {})
	var skus: Dictionary = _world.shelf_skus.get(it["inst"]["instance_id"], {})
	var fade: bool = it.get("fade", false)
	var key := "%s/%d" % [it["inst"]["instance_id"], int(it["column"])]
	var hit: Dictionary = _seg_cache.get(key, {})
	if hit.is_empty() or hit["zoom"] != proj.zoom or hit["ground"] != ground or hit["fade"] != fade or hit["stock"] != stock or hit["skus"] != skus:
		var cmds: Array = []
		_emit_sprite(proj, it, entry, ground, stock, skus, cmds)
		hit = {"zoom": proj.zoom, "ground": ground, "fade": fade, "stock": stock.duplicate(true), "skus": skus.duplicate(true), "cmds": cmds}
		_seg_cache[key] = hit
	_replay(hit["cmds"])


## Command = [type, args...]: 0 texture region (tex, dst, src, tint), 1 rect (rect, color, filled, width),
## 2 line (a, b, color, width), 3 texture rect (tex, rect, tint: a package icon). Emitting in the original
## order keeps the output identical.
func _replay(cmds: Array) -> void:
	for c in cmds:
		match c[0]:
			0:
				draw_texture_rect_region(c[1], c[2], c[3], c[4])
			1:
				draw_rect(c[1], c[2], c[3], c[4])
			3:
				draw_texture_rect(c[1], c[2], false, c[3])
			_:
				draw_line(c[1], c[2], c[3], c[4])


func _emit_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary, ground: Vector2, stock: Dictionary, skus: Dictionary, cmds: Array) -> void:
	var top_left := proj.sprite_top_left(ground, entry["anchor"])
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var strip := _strip(proj, it)
	var tint := Color(1, 1, 1, FADE_ALPHA if it.get("fade", false) else 1.0)
	var layers: Dictionary = entry["layers"]
	for name in FixtureSprites.LAYER_ORDER_BELOW:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint, cmds)
	_emit_products(it, entry, top_left, s, proj.zoom, strip, stock, skus, tint.a, cmds)
	for name in FixtureSprites.LAYER_ORDER_ABOVE:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint, cmds)


func _blit(tex: Texture2D, top_left: Vector2, s: float, strip: Vector2, tint: Color, cmds: Array) -> void:
	var size := tex.get_size()
	var u0 := clampf((strip.x - top_left.x) / s, 0.0, size.x)
	var u1 := clampf((strip.y - top_left.x) / s, 0.0, size.x)
	if u1 - u0 < 0.5:
		return
	cmds.append([0, tex, Rect2(top_left + Vector2(u0 * s, 0.0), Vector2(u1 - u0, size.y) * s), Rect2(u0, 0.0, u1 - u0, size.y), tint])


## True when shelf items are drawn as package icons: close zoom and not the far "bar" LOD. Otherwise rects.
static func use_icons(zoom: float) -> bool:
	return zoom >= ICON_MIN_ZOOM and ShelfDisplay.lod(zoom) != "bar"


## The product dictionary held in one slot, or {} when the slot holds nothing or the SKU is unknown
## (those items keep the plain rect). `per_slot` is {slot_id: sku_id} of one fixture.
static func sku_in_slot(per_slot: Dictionary, slot_id: String, products: ProductCatalog) -> Dictionary:
	var sku_id := str(per_slot.get(slot_id, ""))
	if sku_id == "" or products == null or not products.has_sku(sku_id):
		return {}
	return products.get_sku(sku_id)


func _emit_products(it: Dictionary, entry: Dictionary, top_left: Vector2, s: float, zoom: float, strip: Vector2, stock: Dictionary, skus: Dictionary, alpha: float, cmds: Array) -> void:
	var slots: Dictionary = entry["slots"]
	if slots.is_empty():
		return
	var def: Dictionary = it["def"]
	var color := _color_for(def)
	var lod := ShelfDisplay.lod(zoom)
	var icons := use_icons(zoom)
	var small := ProductSprites.sprite_lod(zoom) == "small"
	var rot := int(it["inst"]["rotation"])
	var half := ITEM_W * 0.5 * s
	var size := Vector2(ITEM_W * s, ITEM_H * s)
	var outline := zoom >= OUTLINE_ZOOM   # the outline doubles the draw commands; small items read fine without it
	var edge := Color(color.darkened(0.45), alpha)
	var fill := Color(color, alpha)
	var anchors := _slot_anchors(entry)
	for slot in def["shelf_slots"]:
		var sid: String = slot["slot_id"]
		if not anchors.has(sid):
			continue
		var pts: PackedVector2Array = anchors[sid]
		var qty := int(stock.get(sid, 0))
		var cap := int(slot["capacity_units"])
		if lod == "bar":
			_emit_row_bar(pts, ShelfDisplay.fill_ratio(qty, cap), color, top_left, s, strip, cmds)
			continue
		var sku: Dictionary = sku_in_slot(skus, sid, _world.product_catalog)
		var n := mini(ShelfDisplay.visible_items(qty, cap, zoom), pts.size())
		if n == 0:
			_emit_price_tag(top_left + pts[0] * s, zoom, strip, alpha, cmds)
			continue
		var sku_tint := ProductSprites.tint_for(str(sku.get("sku_id", "")), str(sku.get("category", "")))
		var tint := Color(sku_tint.r, sku_tint.g, sku_tint.b, alpha)
		# An item stays within its row: at most ROW_FILL of the gap to the board above, and no wider than its spacing.
		var max_h := float(_row_gaps(entry).get(sid, INF)) * s * ROW_FILL
		# Item 0 is the end nearest the viewer's right; draw far items first so near ones overlap.
		for i in range(n - 1, -1, -1):
			var a: Vector2 = top_left + pts[i] * s
			if a.x < strip.x or a.x >= strip.y:
				continue   # belongs to another column segment
			var spr := _art.sprite(str(sku.get("visual_id", "")), rot, ProductSprites.variant_for(sid, i), small) if not sku.is_empty() else {}
			if not spr.is_empty():
				var max_w := _item_spacing(pts, i) * s * SPACING_FILL
				var px := ProductSprites.screen_size(spr, zoom, Vector2(max_w, max_h))
				var base := a + Vector2(ProductSprites.jitter_px(sid, i), 0.0)
				cmds.append([3, spr["texture"], Rect2(base - Vector2(px.x * 0.5, px.y), px), tint])
				continue
			var r := Rect2(a - Vector2(half, ITEM_H * s), size)
			if icons and not sku.is_empty():
				cmds.append([3, ProductIcons.texture(sku, ICON_PX), r, Color(1, 1, 1, alpha)])
				continue
			cmds.append([1, r, fill, true, -1.0])
			if outline:
				cmds.append([1, r, edge, false, 1.0])


## A small price tag on the shelf front of an empty row (the bare shelf otherwise).
func _emit_price_tag(a: Vector2, zoom: float, strip: Vector2, alpha: float, cmds: Array) -> void:
	if a.x < strip.x or a.x >= strip.y:
		return
	var w := 7.0 * maxf(zoom, 0.75)
	var h := 5.0 * maxf(zoom, 0.75)
	var r := Rect2(a + Vector2(-w * 0.5, -h - 2.0 * zoom), Vector2(w, h))
	cmds.append([1, r, Color(1.0, 0.86, 0.3, alpha), true, -1.0])
	cmds.append([1, r, Color(0.2, 0.16, 0.1, alpha), false, 1.0])


## Horizontal distance (source px) from item i to its neighbour along the row: the item may be this wide at most,
## so neighbours overlap by about SPACING_FILL at most. Unbounded for a single-item slot.
static func _item_spacing(pts: PackedVector2Array, i: int) -> float:
	var nb := i + 1 if i + 1 < pts.size() else i - 1
	if nb < 0 or nb >= pts.size():
		return INF
	var d := absf(pts[nb].x - pts[i].x)
	if d < 1.0:
		d = pts[nb].distance_to(pts[i])
	return d if d >= 1.0 else INF


## Vertical distance (source px) from each slot's first item up to the board above it, at the same column; the top
## row measures to the fixture top. Cached on the entry (the manifest never changes at runtime).
func _row_gaps(entry: Dictionary) -> Dictionary:
	if entry.has("_gaps"):
		return entry["_gaps"]
	var anchors := _slot_anchors(entry)
	var out := {}
	for sid in anchors:
		var base: Vector2 = anchors[sid][0]
		var gap := base.y   # no board above: the distance to the fixture top
		for other in anchors:
			var o: Vector2 = anchors[other][0]
			if other != sid and absf(o.x - base.x) < 2.0 and o.y < base.y:
				gap = minf(gap, base.y - o.y)
		out[sid] = gap
	entry["_gaps"] = out
	return out


## Slot anchors of a sprite entry as {slot_id: PackedVector2Array}, built once (the manifest never changes at runtime).
func _slot_anchors(entry: Dictionary) -> Dictionary:
	if entry.has("_anchors"):
		return entry["_anchors"]
	var out := {}
	var slots: Dictionary = entry["slots"]
	for key in slots:
		var k: String = key
		var cut := k.rfind("_item")
		if cut < 0:
			continue
		var sid := k.substr(0, cut)
		if not out.has(sid):
			var pts := PackedVector2Array()
			var n := 0
			while slots.has("%s_item%d" % [sid, n]):
				pts.append(slots["%s_item%d" % [sid, n]])
				n += 1
			out[sid] = pts
	entry["_anchors"] = out
	return out


func _emit_row_bar(pts: PackedVector2Array, ratio: float, color: Color, top_left: Vector2, s: float, strip: Vector2, cmds: Array) -> void:
	var a: Vector2 = top_left + pts[0] * s
	var last := pts.size() - 1
	var b: Vector2 = top_left + pts[last] * s
	if last == 0:
		b = a + Vector2(18.0 * s, 9.0 * s)   # single-cell slot: short bar along the +X screen direction
	var mid := (a.x + b.x) * 0.5
	if mid < strip.x or mid >= strip.y:
		return   # the bar is drawn by the segment that holds its middle
	cmds.append([2, a, b, Color(0, 0, 0, 0.25), 4.0])
	if ratio > 0.0:
		cmds.append([2, a, a.lerp(b, ratio), color, 4.0])


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
