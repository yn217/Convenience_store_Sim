class_name OverlayModel
extends RefCounted
## Pure helpers of the information overlays (#24): which tiles are the customer side of a fixture,
## the stock badge text/icon of a fixture, and the screen shapes used to pick overlapping objects.
## Every status has an icon AND a word, never a colour alone.

enum Mode { NORMAL, LAYOUT, INFO }

const MODE_NAMES := {Mode.NORMAL: "通常", Mode.LAYOUT: "配置", Mode.INFO: "情報"}
const LOW_RATIO := 0.25
const EDGE_STEP := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const PHASE_TEXT := {
	"SELECT": "商品を選んでいる", "WALK_SHELF": "棚へ移動中", "WALK_REGISTER": "レジへ移動中", "WAIT_QUEUE": "列の空きを待っている",
	"QUEUE": "レジ待ち", "CHECKOUT": "会計中", "EXIT": "退店中",
}


## Free tiles in front of the fixture's customer-facing edges (after rotation).
static func access_cells(cells: Array[Vector2i], access_edges: Array, rotation: int, store_w: int, store_h: int) -> Array[Vector2i]:
	var own := {}
	for c in cells:
		own[c] = true
	var out: Array[Vector2i] = []
	for e in access_edges:
		var step: Vector2i = EDGE_STEP[PlacementRules.rotate_edge(e, rotation)]
		for c in cells:
			var n := c + step
			if own.has(n) or n.x < 0 or n.y < 0 or n.x >= store_w or n.y >= store_h or out.has(n):
				continue
			out.append(n)
	return out


## {"level": "register"|"none"|"empty"|"low"|"ok", "icon": String, "text": String} for a fixture's badge.
static func stock_status(def: Dictionary, stock: Dictionary) -> Dictionary:
	if def["shelf_slots"].is_empty():
		return {"level": "register" if def["type_id"].begins_with("register") else "none", "icon": "■", "text": "レジ" if def["type_id"].begins_with("register") else ""}
	var qty := 0
	var cap := 0
	for slot in def["shelf_slots"]:
		qty += int(stock.get(slot["slot_id"], 0))
		cap += int(slot["capacity_units"])
	if qty <= 0:
		return {"level": "empty", "icon": "×", "text": "売切"}
	if cap > 0 and float(qty) / float(cap) < LOW_RATIO:
		return {"level": "low", "icon": "!", "text": "残少 %d" % qty}
	return {"level": "ok", "icon": "✓", "text": "在庫 %d" % qty}


static func sales_text(units_today: int) -> String:
	return "本日 %d個" % units_today


## Convex screen outline of a fixture box (footprint cells, floor to `height_m`): what the player sees as that object.
static func hit_polygon(proj: IsoProjection, cells: Array[Vector2i], height_m: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in cells:
		for dx in [-0.5, 0.5]:
			for dy in [-0.5, 0.5]:
				pts.append(proj.world_to_screen(c.x + dx, c.y + dy, 0.0))
				pts.append(proj.world_to_screen(c.x + dx, c.y + dy, height_m))
	return Geometry2D.convex_hull(pts)


static func customer_rect(proj: IsoProjection, pos: Vector2) -> Rect2:
	var foot := proj.world_to_screen(pos.x, pos.y)
	var hw := 0.25 * IsoProjection.HALF_TILE_W * proj.zoom
	var top := proj.world_to_screen(pos.x, pos.y, 1.7).y
	return Rect2(Vector2(foot.x - hw, top), Vector2(hw * 2.0, foot.y - top + 4.0 * proj.zoom))


static func fixture_bounds(proj: IsoProjection, cells: Array[Vector2i], height_m: float) -> Rect2:
	var poly := hit_polygon(proj, cells, height_m)
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func phase_text(phase: String) -> String:
	return PHASE_TEXT.get(phase, phase)
