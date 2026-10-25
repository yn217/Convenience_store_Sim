class_name OverlayModel
extends RefCounted
## Pure helpers of the information overlays (#24): which tiles are the customer side of a fixture,
## the stock badge text/icon of a fixture, and the screen shapes used to pick overlapping objects.
## Every status has an icon AND a word, never a colour alone.

enum Mode { NORMAL, LAYOUT, INFO }

## Height (metres above the register top) of the "レジ待ち" badge; the sale pop-up starts above the badge.
const QUEUE_BADGE_LIFT := 0.35

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


## The customer panel (#141): purpose, money, basket and what the customer is doing, one line each, in Japanese.
## Read-only from the snapshot's customer view. A customer without a purpose (old save) shows its basket size only.
static func customer_panel_lines(c: Dictionary, fixture_name: String) -> Array[String]:
	var out: Array[String] = []
	if bool(c.get("passerby", false)):
		out.append("通行人（お店には入りません）")
		return out
	var purpose := String(c.get("purpose_name", ""))
	out.append("客 %s　来店目的：%s" % [c.get("customer_id", ""), purpose if purpose != "" else "（記録なし）"])
	if purpose != "":
		out.append("所持金 %s　予算 %s　予定 %s" % [yen(int(c.get("wallet_yen", 0))), yen(int(c.get("budget_yen", 0))), yen(int(c.get("planned_yen", 0)))])
	var items: Array[String] = []
	var passed: Array[String] = []
	for e in c.get("basket_log", []):
		var star := "★" if e.get("kind", "") == "impulse" else ""
		var label := "%s%s %s" % [star, e.get("name", e.get("sku_id", "")), yen(int(e.get("price", 0)))]
		match String(e.get("state", "")):
			"taken":
				items.append("✔" + label)
			"planned":
				items.append("・" + label)
			"too_expensive":
				passed.append(label + "（予算オーバー）")
			"not_bought":
				passed.append(label + "（見送り）")
			"stockout":
				passed.append(label + "（品切れ）")
	out.append("かご：" + ("、".join(items) if not items.is_empty() else "なし"))
	if not passed.is_empty():
		out.append("買わなかった：" + "、".join(passed))
	if int(c.get("impulse_count", 0)) > 0:
		out.append("★ ついで買い %d点" % int(c.get("impulse_count", 0)))
	out.append("状態：" + customer_action(c, fixture_name))
	return out


static func yen(v: int) -> String:
	var s := str(absi(v))
	var parts: Array[String] = []
	while s.length() > 3:
		parts.push_front(s.substr(s.length() - 3))
		s = s.substr(0, s.length() - 3)
	parts.push_front(s)
	return ("-" if v < 0 else "") + "¥" + ",".join(parts)


## What the selected customer is doing now, in Japanese, from its phase and targets (read-only snapshot fields).
## `fixture_name` is the display name of the shelf it is heading to or picked from ("" when unknown).
static func customer_action(c: Dictionary, fixture_name: String) -> String:
	var shelf := fixture_name if fixture_name != "" else "棚"
	match String(c.get("phase", "")):
		"SELECT":
			return "商品を選択中"
		"WALK_SHELF":
			if int(c.get("browse_left", -1)) > 0:
				return "%sで商品を見ている" % shelf
			return "%sへ移動中" % shelf
		"WALK_REGISTER":
			return "レジへ移動中"
		"WAIT_QUEUE":
			return "会計待ち（列の空きを待ち中）"
		"QUEUE":
			return "会計待ち (%d番目)" % (int(c.get("queue_slot", 0)) + 1)
		"CHECKOUT":
			return "会計中"
		"EXIT":
			return "退店中"
		"APPROACH":
			return "お店に向かって歩いている"
		"ENTER":
			return "入店するところ"
		"WALK_AWAY":
			return "レジの混雑を見て引き返した" if String(c.get("outcome", "")) == "balked" else "帰っていく"
	return String(c.get("phase", ""))
## Per register: {"queued": customers holding a queue slot (walking into one or standing in it),
## "overflow": customers who want to pay but have no slot (WAIT_QUEUE), "checkout": customers at the till,
## "left": game seconds left of the current checkout}. Counted from the snapshot's customer views only.
static func register_queues(customers: Array) -> Dictionary:
	var out := {}
	for c in customers:
		var reg := String(c.get("register_id", ""))
		if reg == "":
			continue
		var phase := String(c.get("phase", ""))
		var slot := int(c.get("queue_slot", -1))
		if not out.has(reg):
			out[reg] = {"queued": 0, "overflow": 0, "checkout": 0, "left": 0}
		if phase == "CHECKOUT":
			out[reg]["checkout"] = int(out[reg]["checkout"]) + 1
			out[reg]["left"] = int(c.get("checkout_left", 0))
		elif phase == "WAIT_QUEUE":
			out[reg]["overflow"] = int(out[reg]["overflow"]) + 1
		elif (phase == "WALK_REGISTER" or phase == "QUEUE") and slot >= 0:
			out[reg]["queued"] = int(out[reg]["queued"]) + 1
	return out


## Customers in line for this register, slots and overflow together (the estimate counts all of them).
static func line_size(q: Dictionary) -> int:
	return int(q.get("queued", 0)) + int(q.get("overflow", 0))


## Estimated minutes until a newly joined customer is served: the current checkout's time left plus one full
## checkout per customer already in line. Returns -1 when it cannot be stated (no checkout duration in the model).
static func estimated_wait_minutes(q: Dictionary, checkout_duration_sec: int) -> int:
	if checkout_duration_sec <= 0:
		return -1
	var sec := int(q.get("left", 0)) + line_size(q) * checkout_duration_sec
	return 0 if sec <= 0 else ceili(float(sec) / 60.0)


## "レジ待ち 3人" for the queue slots; " ＋列外14人" appended when customers have no slot.
static func queue_badge_text(queued: int, overflow: int = 0) -> String:
	var text := "レジ待ち %d人" % queued
	if overflow > 0:
		text += " ＋列外%d人" % overflow
	return text


## Badge colour state: "overflow" (red) when customers are outside the line, "full" (amber) when the line is at its
## max, else "normal" (the register blue).
static func queue_badge_state(queued: int, overflow: int, queue_max: int) -> String:
	if overflow > 0:
		return "overflow"
	if queued >= queue_max:
		return "full"
	return "normal"


static func register_info_text(q: Dictionary, est_minutes: int) -> String:
	var text := "■ レジ 待ち%d・列外%d・会計中%d" % [int(q.get("queued", 0)), int(q.get("overflow", 0)), int(q.get("checkout", 0))]
	if est_minutes >= 0 and line_size(q) + int(q.get("checkout", 0)) > 0:
		text += " 目安 約%d分" % maxi(est_minutes, 1)
	return text
