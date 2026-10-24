extends RefCounted
## P0 customer paths (issues #15, #23, #26). The real simulation (fixed seeds) runs on a store, and the presentation
## is driven with the same snapshot the StoreWorld gets (FixturePresenter._sync_customers + compose(), real frame
## deltas, the calm #117 pace that lags the simulation). Variants (QA 2026-10-24, docs/qa/CUSTOMER_PATH_VERIFY_2026-10-24.md):
##   lab      the 7-fixture test store (forced arrivals), 1.5 game hours
##   sample   data/layouts/sample_store_v1.json (20 fixtures, the bench layout), 2 game hours:
##            crowd  = the bench's crowded demand (200000 visitors/day, max 30 active; 1 game hour at x1 and x2)
##            normal = the balance file's own demand
##            hitch  = crowd with a 0.5 s real stall every HITCH_EVERY frames (catch-up after a long lag)
## Logical checks, every fixed step:
##   (a) every tile a customer stands on or walks through is free of fixture footprints, and so is the
##       remaining path;
##   (b) every move is 4-connected (no diagonal steps, so no corner cutting in the logic);
##   (d) a customer who walks to a shelf stops on one of that fixture's access tiles (the front side).
## Presentation checks, every frame at speeds 1, 2 and 4, for every figure on screen (live and departing):
##   (c) the drawn position, and every point of the straight segment from the previous drawn position to
##       the new one, stays out of every fixture footprint (customer radius RADIUS);
##   (e) draw order (DrawOrder.is_behind in both directions);
##   (f) no teleport: a figure moves at most WALK_MAX tiles per real second, so a frame never jumps.
## Overflow (every OVERFLOW_EVERY frames): a WAIT_QUEUE customer without a queue slot stands on a free tile; the
## check counts how far it is from its register and whether standing there would cut an access tile off (counted,
## not a violation: customers do not block the domain's paths).

const Seeds := preload("res://tests/support/test_seeds.gd")
const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const SampleLayout := preload("res://tools/sample_layout.gd")
const FRAME := 1.0 / 60.0   # real seconds per rendered frame
const HITCH_SEC := 2.0      # real seconds of one stalled frame (hitch variant): 60 steps at x1, 240 at x4
const HITCH_EVERY := 400    # every this many frames
const RADIUS := 0.2         # customer body radius in tiles
const RUN_UNTIL_SEC := 5400 # lab: game seconds per run (1.5 game hours)
const SAMPLE_UNTIL_SEC := 7200 # sample layout: 2 game hours
## The crowd at x1 and x2 runs 1 game hour: the simulation is the same at every speed (same seeds, same steps), so the
## logic checks repeat x4's; only the per-frame presentation differs, and x1 renders 4x the frames of x4 (it took 2 min).
const CROWD_SLOW_UNTIL_SEC := 3600
const ARRIVE_EVERY_STEPS := 6
const OVERFLOW_EVERY := 30
const CROWD_VISITORS := 200000   # the bench's crowded demand (tools/perf_bench.gd)

## type_id, x, y, rotation, sku for the shelf (empty = no stock)
const LAYOUT := [
	["shelf_onigiri", 4, 3, 0, "rice_001"],
	["shelf_bread", 4, 8, 1, "bread_001"],
	["shelf_snack", 9, 3, 2, "snack_001"],
	["shelf_noodle", 9, 8, 3, "noodle_001"],
	["freezer_ice", 12, 3, 0, "ice_001"],
	["fridge_drink", 12, 7, 1, "drink_001"],
	["register_basic", 11, 10, 0, ""],
]


## Fake StoreWorld: the fields FixturePresenter reads (compose() needs the layout and the catalogs too).
class FakeWorld extends Node2D:
	var customers: Array = []
	var speed_setting := 1
	var fixtures: Array = []
	var fixture_catalog: FixtureCatalog
	var product_catalog: ProductCatalog
	var projection: IsoProjection = null
	var revision := 0
	var overlay_mode := 0
	var selected_customer := ""
	var shelf_stock: Dictionary = {}
	var shelf_skus: Dictionary = {}

	func selected_fixture_id() -> String:
		return ""


## base: visitors per day (-1 keeps the balance file's own demand).
func _state(base: int = 0) -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	if base >= 0:
		balance["base_potential_visitors_per_day"] = base
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 5000000   # the layout and the first stock orders must not run out of cash
	return s


var _n := 0


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "cp%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## Builds the lab layout through the real commands (validated placement) and opens the store.
func _store(t, speed: int) -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var ids := {}
	for row in LAYOUT:
		var r := _run(cmds, &"PLACE_FIXTURE", {"type_id": row[0], "x": row[1], "y": row[2], "rotation": row[3]})
		t.ok(r.ok, "placed %s at (%d,%d) r%d: %s" % [row[0], row[1], row[2], row[3], r.code])
		if r.ok:
			ids[row[0] + "@%d,%d" % [row[1], row[2]]] = r.data["instance_id"]
	for row in LAYOUT:
		var sku: String = row[4]
		if sku == "":
			continue
		var id: String = ids.get(row[0] + "@%d,%d" % [row[1], row[2]], "")
		var first_slot: Dictionary = s.fixtures.get_type(row[0])["shelf_slots"][0]
		var qty := mini(12, int(first_slot["capacity_units"]))
		_run(cmds, &"ORDER_STOCK", {"sku_id": sku, "qty": qty})
		var rr := _run(cmds, &"RESTOCK", {"instance_id": id, "slot_id": first_slot["slot_id"], "sku_id": sku, "qty": qty})
		t.ok(rr.ok, "restocked %s: %s %s" % [row[0], rr.code, rr.message_key])
	s.business_state = GameState.OPEN
	s.speed_setting = speed
	s.balance["checkout_base_game_seconds"] = 30   # the old single-item checkout time (issue #128 keeps it for this path test)
	s.balance["checkout_per_item_game_seconds"] = 0
	return s


## The bench's sample store (tools/perf_bench.gd): the 20 placements of data/layouts/sample_store_v1.json through
## PLACE_FIXTURE, every shelf slot stocked with a SKU of its first allowed category.
func _store_sample(t, demand: String) -> GameState:
	var s := _state(-1)
	var cmds := GameCommands.new(s)
	var placed := 0
	for p in SampleLayout.placements():
		var r := _run(cmds, &"PLACE_FIXTURE", {"type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
		t.ok(r.ok, "sample: placed %s at (%d,%d) r%d: %s" % [p[0], p[1], p[2], p[3], r.code])
		if r.ok:
			placed += 1
	t.eq(placed, 20, "sample: all 20 fixtures placed")
	for id in s.grid.instances.keys():
		var inst: Dictionary = s.grid.instances[id]
		var def := s.fixtures.get_type(inst["type_id"])
		if def["allowed_categories"].is_empty():
			continue
		var cat: String = def["allowed_categories"][0]
		for slot in def["shelf_slots"]:
			for sku in s.products.skus.values():
				if sku["category"] == cat:
					var qty := int(slot["capacity_units"])
					_run(cmds, &"ORDER_STOCK", {"sku_id": sku["sku_id"], "qty": qty})
					_run(cmds, &"RESTOCK", {"instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": qty})
					break
	s.business_state = GameState.OPEN
	s.balance["checkout_base_game_seconds"] = 30   # the old single-item checkout time (issue #128)
	s.balance["checkout_per_item_game_seconds"] = 0
	if demand == "crowd":
		s.balance["base_potential_visitors_per_day"] = CROWD_VISITORS
		s.balance["max_active_customers"] = 30
	return s


## Distance from point p to the footprint rectangle of cell c (0 when inside).
static func _dist_to_cell(p: Vector2, c: Vector2i) -> float:
	var dx := maxf(absf(p.x - c.x) - 0.5, 0.0)
	var dy := maxf(absf(p.y - c.y) - 0.5, 0.0)
	return sqrt(dx * dx + dy * dy)


func _check_logic(s: GameState, prev: Dictionary, blocked: Dictionary, viol: Array, stats: Dictionary) -> void:
	for c in s.customers:
		var id: String = c["customer_id"]
		var tile: Vector2i = c["tile"]
		var path: Array = c["path"]
		var phase: String = c["phase"]
		if blocked.has(tile):
			viol.append("a %s standing on fixture cell %s (%s)" % [id, tile, phase])
		for p in path:
			if blocked.has(p):
				viol.append("a %s path %s crosses fixture cell %s (%s)" % [id, path, p, phase])
				break
		if prev.has(id):
			var old: Dictionary = prev[id]
			var chain: Array = [old["tile"]] + old["path"]
			var k: int = chain.find(tile)
			if k < 0:
				if tile != old["tile"]:
					viol.append("a %s moved to %s outside its path %s" % [id, tile, chain])
			else:
				for i in range(1, k + 1):
					var a: Vector2i = chain[i - 1]
					var b: Vector2i = chain[i]
					if blocked.has(b):
						viol.append("a %s walked through fixture cell %s" % [id, b])
					if absi(a.x - b.x) + absi(a.y - b.y) != 1:
						viol.append("b %s diagonal or jump %s -> %s" % [id, a, b])
					stats["moves"] += 1
		if phase == "WALK_SHELF":
			var goal: Vector2i = path.back() if not path.is_empty() else tile
			var cands := _access_cells(s, c["fixture_id"])
			if not cands.has(goal):
				viol.append("d %s walks to %s which is not an access tile of %s" % [id, goal, c["fixture_id"]])
			stats["shopping"] += 1
		if prev.has(id) and prev[id]["phase"] == "WALK_SHELF" and phase in ["WAIT_QUEUE", "WALK_REGISTER", "QUEUE", "CHECKOUT"]:
			var cands2 := _access_cells(s, c["fixture_id"])
			if not cands2.has(tile):
				viol.append("d %s picked at %s which is not an access tile of %s" % [id, tile, c["fixture_id"]])
			stats["picks"] += 1
		prev[id] = {"tile": tile, "path": path.duplicate(), "phase": phase}
	for id in prev.keys():
		var alive := false
		for c in s.customers:
			if c["customer_id"] == id:
				alive = true
				break
		if not alive:
			prev.erase(id)


func _access_cells(s: GameState, instance_id: String) -> Array[Vector2i]:
	var inst: Dictionary = s.grid.instances[instance_id]
	var def := s.fixtures.get_type(inst["type_id"])
	return PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"])


## Every figure the presenter holds (live customers and departing ones, see Walk.departed) is checked here, so a
## departing figure that walks on through a shelf is caught too.
## True when point m is within RADIUS of a fixture cell. Only the 3x3 cells around the rounded point can qualify
## (RADIUS is below half a tile), so this stays cheap for every figure and sample.
static func _inside_fixture(m: Vector2, blocked: Dictionary) -> Vector2i:
	var base := Vector2i(roundi(m.x), roundi(m.y))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := base + Vector2i(dx, dy)
			if blocked.has(c) and _dist_to_cell(m, c) < RADIUS:
				return c
	return Vector2i(1 << 20, 1 << 20)


const NO_CELL := Vector2i(1 << 20, 1 << 20)


func _check_presentation(pres: Presenter, before: Dictionary, blocked: Dictionary, real: float, viol: Array, stats: Dictionary) -> void:
	var max_step := Presenter.WALK_MAX * real + 0.01
	for id in pres._pos.keys():
		var p: Vector2 = pres._pos[id]
		var cell := _inside_fixture(p, blocked)
		if cell != NO_CELL:
			viol.append("c %s drawn at %s inside fixture cell %s" % [id, p, cell])
		if before.has(id):
			var q: Vector2 = before[id]
			var jump := q.distance_to(p)
			stats["max_jump"] = maxf(float(stats["max_jump"]), jump)
			if jump > max_step:
				viol.append("f %s jumped %.2f tiles in one frame (a walk moves at most %.2f): teleport %s -> %s" % [id, jump, max_step, q, p])
				stats["teleports"] += 1
			for i in range(1, 21):
				var m := q.lerp(p, float(i) / 20.0)
				var c2 := _inside_fixture(m, blocked)
				if c2 != NO_CELL:
					viol.append("c %s segment %s -> %s crosses fixture cell %s at %s" % [id, q, p, c2, m])
					break
		else:
			stats["placements"] += 1


## (e) draw order: customers and fixture segments in the order compose() returns them must respect
## DrawOrder.is_behind in both directions (a fixture behind a customer is drawn first, and vice versa).
func _check_draw_order(pres: Presenter, ordered: Array, viol: Array, stats: Dictionary) -> void:
	var index := {}
	for i in ordered.size():
		var it: Dictionary = ordered[i]
		if it["kind"] == "customer":
			index["c:" + it["customer"]["customer_id"]] = i
		else:
			index["f:%s/%d" % [it["inst"]["instance_id"], int(it["column"])]] = i
	var fixtures_items := []
	var customers_items := []
	for it in ordered:
		if it["kind"] == "customer":
			customers_items.append(it)
		else:
			fixtures_items.append(it)
	for cu in customers_items:
		var ci: int = index["c:" + cu["customer"]["customer_id"]]
		for fx in fixtures_items:
			var fi: int = index["f:%s/%d" % [fx["inst"]["instance_id"], int(fx["column"])]]
			if DrawOrder.is_behind(fx["rect"], cu["rect"]) and not fi < ci:
				viol.append("e %s drawn before fixture %s it stands in front of" % [cu["customer"]["customer_id"], fx["inst"]["instance_id"]])
			if DrawOrder.is_behind(cu["rect"], fx["rect"]) and not ci < fi:
				viol.append("e %s drawn after fixture %s that stands in front of it" % [cu["customer"]["customer_id"], fx["inst"]["instance_id"]])
	stats["order_checks"] = int(stats.get("order_checks", 0)) + customers_items.size()


## Overflow customers (WAIT_QUEUE without a slot): distance to the nearest register cell, and whether standing on
## their tile would cut off a walkable access tile of some fixture (counted; customers do not block the domain).
func _check_overflow(s: GameState, views: Array, blocked: Dictionary, stats: Dictionary) -> void:
	var reg: Array[Vector2i] = []
	var access: Array[Vector2i] = []
	for id in s.grid.instances:
		var inst: Dictionary = s.grid.instances[id]
		var def := s.fixtures.get_type(inst["type_id"])
		if (inst["type_id"] as String).begins_with("register"):
			reg.append_array(StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"]))
		if def["access_edges"].is_empty():
			continue
		for c in PlacementRules.walkable_access(s.grid, PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"]), blocked):
			access.append(c)
	var reach0 := PathService.distances(s.grid, blocked)
	for v in views:
		if v["phase"] != "WAIT_QUEUE" or int(v["queue_slot"]) >= 0:
			continue
		var t: Vector2i = v["tile"]
		stats["overflow_checked"] += 1
		var best := 1 << 20
		for c in reg:
			best = mini(best, absi(c.x - t.x) + absi(c.y - t.y))
		stats["overflow_dist"] = maxi(int(stats["overflow_dist"]), best if best < (1 << 20) else 0)
		var b2 := blocked.duplicate()
		b2[t] = true
		var reach := PathService.distances(s.grid, b2)
		for a in access:
			if a != t and reach0.has(a) and not reach.has(a):
				stats["overflow_cut"] += 1
				break


func _run_speed(t, speed: int, cfg: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sample: bool = cfg["layout"] == "sample"
	var demand: String = cfg["demand"]
	var hitch: bool = cfg.get("hitch", false)
	var s: GameState = _store_sample(t, demand) if sample else _store(t, speed)
	s.speed_setting = speed
	var until: int = cfg["until"]
	var runner := SimulationRunner.new(s)
	var clock := GameClock.new()
	var pres: Presenter = Presenter.new()
	var fake := FakeWorld.new()
	pres._world = fake
	fake.speed_setting = speed
	fake.fixtures = s.grid.to_save()["fixture_instances"]
	fake.fixture_catalog = s.fixtures
	fake.product_catalog = s.products
	var blocked := s.grid.blocked_cells()
	var prev := {}
	var viol: Array = []
	var stats := {"moves": 0, "shopping": 0, "picks": 0, "max_jump": 0.0, "frames": 0, "teleports": 0, "placements": 0,
		"overflow_checked": 0, "overflow_cut": 0, "overflow_dist": 0, "order_checks": 0, "max_steps_frame": 0}
	var step_no := 0
	var frame := 0
	var guard := 0
	while s.time_sec < until and guard < 400000:
		guard += 1
		var real := FRAME
		if hitch and frame % HITCH_EVERY == HITCH_EVERY - 1:
			real = HITCH_SEC
		frame += 1
		var steps := clock.advance(real, speed)
		stats["max_steps_frame"] = maxi(int(stats["max_steps_frame"]), steps)   # the most one presenter sync must replay
		for i in steps:
			step_no += 1
			if demand == "forced" and step_no % ARRIVE_EVERY_STEPS == 0:
				s.next_customer_seq += 1
				s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
			runner._run_step()
			_check_logic(s, prev, blocked, viol, stats)
		stats["frames"] += 1
		fake.customers = s._customer_views()
		var before := {}
		for k in pres._pos.keys():
			before[k] = pres._pos[k]
		pres._sync_customers(real * speed)
		_check_presentation(pres, before, blocked, real, viol, stats)
		_check_draw_order(pres, pres.compose(), viol, stats)
		if frame % OVERFLOW_EVERY == 0:
			_check_overflow(s, fake.customers, blocked, stats)
	stats["purchased"] = int(s.visit_stats.get("purchased", 0))
	stats["viol"] = viol
	stats["steps"] = step_no
	stats["time_sec"] = s.time_sec
	stats["ms"] = Time.get_ticks_msec() - t0
	return stats


func _report(label: String, speed: int, st: Dictionary) -> void:
	var viol: Array = st["viol"]
	print("PATHS %s x%d game_s=%d steps=%d frames=%d moves=%d shopping=%d picks=%d purchased=%d draw_order_checks=%d max_steps_frame=%d max_frame_jump=%.3f teleports=%d placements=%d overflow_checked=%d overflow_cut=%d overflow_max_dist=%d violations=%d ms=%d" % [
		label, speed, st["time_sec"], st["steps"], st["frames"], st["moves"], st["shopping"], st["picks"], st["purchased"], st["order_checks"], st["max_steps_frame"], st["max_jump"],
		st["teleports"], st["placements"], st["overflow_checked"], st["overflow_cut"], st["overflow_dist"], viol.size(), st["ms"]])
	var by_kind := {}
	for v in viol:
		var k: String = String(v).substr(0, 1)
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	print("  by check: ", by_kind)
	for i in mini(viol.size(), 8):
		print("  ", viol[i])


func _assert_clean(t, label: String, speed: int, st: Dictionary) -> void:
	var viol: Array = st["viol"]
	t.ok(int(st["picks"]) > 0, "%s x%d: customers reached a shelf and picked" % [label, speed])
	t.ok(int(st["moves"]) > 0, "%s x%d: customers walked" % [label, speed])
	t.ok(viol.is_empty(), "%s x%d: %d path/presentation violations, first: %s" % [label, speed, viol.size(), str(viol.slice(0, 3))])


func _lab(t, speed: int) -> void:
	var st := _run_speed(t, speed, {"layout": "lab", "demand": "forced", "until": RUN_UNTIL_SEC})
	_report("lab", speed, st)
	_assert_clean(t, "lab", speed, st)


func test_customer_paths_speed_1(t, _tree) -> void:
	_lab(t, 1)


func test_customer_paths_speed_2(t, _tree) -> void:
	_lab(t, 2)


func test_customer_paths_speed_4(t, _tree) -> void:
	_lab(t, 4)


func _sample(t, speed: int, demand: String, hitch: bool) -> void:
	var label := "sample_%s%s" % [demand, "_hitch" if hitch else ""]
	var until := CROWD_SLOW_UNTIL_SEC if demand == "crowd" and speed < 4 else SAMPLE_UNTIL_SEC
	var st := _run_speed(t, speed, {"layout": "sample", "demand": demand, "until": until, "hitch": hitch})
	_report(label, speed, st)
	_assert_clean(t, label, speed, st)


func test_sample_crowd_speed_1(t, _tree) -> void:
	_sample(t, 1, "crowd", false)


func test_sample_crowd_speed_2(t, _tree) -> void:
	_sample(t, 2, "crowd", false)


func test_sample_crowd_speed_4(t, _tree) -> void:
	_sample(t, 4, "crowd", false)


func test_sample_normal_speed_1(t, _tree) -> void:
	_sample(t, 1, "normal", false)


func test_sample_normal_speed_2(t, _tree) -> void:
	_sample(t, 2, "normal", false)


func test_sample_normal_speed_4(t, _tree) -> void:
	_sample(t, 4, "normal", false)


## x4 is the worst case for a stall: the most steps per frame (240 for a 2 s stall).
func test_sample_crowd_hitch_speed_4(t, _tree) -> void:
	_sample(t, 4, "crowd", true)


## The debug route of a lagging figure (FixturePresenter.shown_route, drawn by DebugPathLayer) starts at its shown
## position and then runs over tile centres only: the walked tiles it still has to cover, then the remaining path.
func test_shown_route_is_walkable_tiles(t, _tree) -> void:
	var fake := FakeWorld.new()
	fake.fixture_catalog = FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pres: Presenter = Presenter.new()
	pres._world = fake
	var c := {"customer_id": "route_1", "tile": Vector2i(1, 1), "phase": "WALK_SHELF", "path": [], "progress": 0.0, "moved": 0}
	fake.customers = [c]
	pres._sync_customers(0.0)
	c = {"customer_id": "route_1", "tile": Vector2i(2, 2), "phase": "WALK_SHELF", "path": [Vector2i(2, 3), Vector2i(3, 3)],
		"progress": 0.0, "moved": 2, "trail": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]}
	fake.customers = [c]
	pres._sync_customers(0.1)
	var route: PackedVector2Array = pres.shown_route(c)
	t.eq(route.size(), 5, "shown route: shown position, then (2,1) (2,2) (2,3) (3,3)")
	t.ok(route[0].distance_to(pres._pos["route_1"]) < 0.0001, "the route starts at the drawn position")
	var ok := true
	for i in range(1, route.size()):
		var p := route[i]
		var q := route[i - 1] if i > 1 else Vector2(1, 1)
		if p != p.round() or absf(p.x - q.x) + absf(p.y - q.y) != 1.0:
			ok = false
	t.ok(ok, "every point after the drawn position is a tile centre, one 4-connected step from the last")
	t.eq(route[route.size() - 1], Vector2(3, 3), "the route ends on the remaining path's last tile")


## A stall longer than the simulation's trail (TRAIL_MAX steps in one presenter sync) cannot be replayed step by step.
## The figure must then catch up on free tiles around the fixtures, never jump straight across them.
func test_catch_up_after_a_long_stall_stays_on_free_tiles(t, _tree) -> void:
	var fake := FakeWorld.new()
	fake.fixture_catalog = FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	for i in 6:   # a wall of shelves across x = 4, y = 2..7: the straight line from (0,5) to (8,5) is blocked
		fake.fixtures.append({"instance_id": "wall_%d" % i, "type_id": "shelf_general", "x": 4, "y": 2 + i, "rotation": 0})
	var blocked := {}
	for inst in fake.fixtures:
		var def: Dictionary = fake.fixture_catalog.get_type(inst["type_id"])
		for cell in StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"]):
			blocked[cell] = true
	var pres: Presenter = Presenter.new()
	pres._world = fake
	var c := {"customer_id": "stall_1", "tile": Vector2i(0, 5), "phase": "WALK_SHELF", "path": [], "progress": 0.0, "moved": 0}
	fake.customers = [c]
	pres._sync_customers(0.0)
	var trail: Array = []
	for i in 32:
		trail.append(Vector2i(8, 5))
	c = {"customer_id": "stall_1", "tile": Vector2i(8, 5), "phase": "WALK_SHELF", "path": [], "progress": 0.0,
		"moved": 40, "trail": trail}   # 40 steps since the last frame, but the trail only keeps 32
	fake.customers = [c]
	var viol: Array = []
	var stats := {"max_jump": 0.0, "teleports": 0}
	var prev: Vector2 = pres._pos["stall_1"]
	for i in 200:
		pres._sync_customers(0.05)
		var p: Vector2 = pres._pos["stall_1"]
		_check_presentation(pres, {"stall_1": prev}, blocked, 0.05, viol, stats)
		prev = p
	t.ok(viol.is_empty(), "catch-up after a long stall: no jump or crossing (first: %s)" % str(viol.slice(0, 2)))
	t.ok(pres._pos["stall_1"].distance_to(Vector2(8, 5)) < 0.05, "the figure reaches the simulation's tile, %s" % str(pres._pos["stall_1"]))


## The customer route cache (CustomerAI._path) follows every layout change: a shelf placed on the route,
## moved across it and removed again must give the same route as a fresh search each time.
func _clear_of(path: Array, blocked: Dictionary) -> bool:
	for p in path:
		if blocked.has(p):
			return false
	return true


func test_path_cache_follows_layout_changes(t, _tree) -> void:
	var s := _state()   # SETUP: construction is allowed
	var cmds := GameCommands.new(s)
	var ai := CustomerAI.new()
	var a := Vector2i(0, 5)
	var b := Vector2i(7, 5)
	var p0: Array = ai._path(s, a, b)
	t.eq(p0.size(), 8, "straight route on the empty store")
	var r := _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_general", "x": 3, "y": 5, "rotation": 0})
	t.ok(r.ok, "placed the shelf on the route: %s" % r.code)
	var id: String = r.data["instance_id"]
	var p1: Array = ai._path(s, a, b)
	t.ok(_clear_of(p1, s.grid.blocked_cells()), "route avoids the new shelf cells")
	t.eq(p1, PathService.find_path(s.grid, s.grid.blocked_cells(), a, b), "placed: same route as a fresh search")
	t.ok(p1 != p0, "placing a shelf changed the route")
	r = _run(cmds, &"MOVE_FIXTURE", {"instance_id": id, "x": 3, "y": 3, "rotation": 1})
	t.ok(r.ok, "moved the shelf off the row: %s" % r.code)
	var p2: Array = ai._path(s, a, b)
	t.ok(_clear_of(p2, s.grid.blocked_cells()), "route avoids the moved shelf")
	t.eq(p2, PathService.find_path(s.grid, s.grid.blocked_cells(), a, b), "moved: same route as a fresh search")
	t.eq(p2, p0, "moved away from the row: straight route again")
	r = _run(cmds, &"MOVE_FIXTURE", {"instance_id": id, "x": 3, "y": 5, "rotation": 1})
	t.ok(r.ok, "rotated the shelf onto the row: %s" % r.code)
	var p3: Array = ai._path(s, a, b)
	t.ok(_clear_of(p3, s.grid.blocked_cells()), "route avoids the rotated shelf")
	t.eq(p3, PathService.find_path(s.grid, s.grid.blocked_cells(), a, b), "rotated: same route as a fresh search")
	r = _run(cmds, &"REMOVE_FIXTURE", {"instance_id": id})
	t.ok(r.ok, "removed the shelf: %s" % r.code)
	t.eq(ai._path(s, a, b), p0, "removed: straight route again")
