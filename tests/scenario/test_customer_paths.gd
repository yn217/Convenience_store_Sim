extends RefCounted
## P0 customer paths (issues #15, #23, #26). The real simulation (fixed seeds) runs on a store with a 1x2
## shelf, rotated 1x2 shelves, a rotated 1x2 fridge and a 2x2 freezer, and the presentation is driven
## with the same snapshot the StoreWorld gets (FixturePresenter._sync_customers, real frame deltas).
##
## Logical checks, every fixed step:
##   (a) every tile a customer stands on or walks through is free of fixture footprints, and so is the
##       remaining path;
##   (b) every move is 4-connected (no diagonal steps, so no corner cutting in the logic);
##   (d) a customer who walks to a shelf stops on one of that fixture's access tiles (the front side).
## Presentation checks, every frame at speeds 1, 2 and 4:
##   (c) the drawn position, and every point of the straight segment from the previous drawn position to
##       the new one, stays out of every fixture footprint (customer radius RADIUS).

const Seeds := preload("res://tests/support/test_seeds.gd")
const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const FRAME := 1.0 / 60.0   # real seconds per rendered frame
const RADIUS := 0.2         # customer body radius in tiles
const RUN_UNTIL_SEC := 5400 # game seconds per run (1.5 game hours)
const ARRIVE_EVERY_STEPS := 6

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
	var store_width := 20
	var store_height := 12

	func selected_fixture_id() -> String:
		return ""

	func in_store(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < store_width and c.y < store_height


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	balance["base_potential_visitors_per_day"] = 0   # arrivals are queued by the test, deterministically
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


## Builds the layout through the real commands (validated placement) and opens the store.
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
	s.balance["checkout_duration_game_seconds"] = 30
	return s


func _access_cells(s: GameState, instance_id: String) -> Array[Vector2i]:
	var inst: Dictionary = s.grid.instances[instance_id]
	var def := s.fixtures.get_type(inst["type_id"])
	return PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"])


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


func _check_presentation(pres: Presenter, views: Array, before: Dictionary, blocked: Dictionary, viol: Array, stats: Dictionary) -> void:
	for v in views:
		var id: String = v["customer_id"]
		var p: Vector2 = pres._pos[id]
		for cell in blocked.keys():
			if _dist_to_cell(p, cell) < RADIUS:
				viol.append("c %s drawn at %s inside fixture cell %s" % [id, p, cell])
				break
		if before.has(id):
			var q: Vector2 = before[id]
			var jump := q.distance_to(p)
			stats["max_jump"] = maxf(float(stats["max_jump"]), jump)
			for i in range(1, 21):
				var m := q.lerp(p, float(i) / 20.0)
				var hit := false
				for cell in blocked.keys():
					if _dist_to_cell(m, cell) < RADIUS:
						hit = true
						break
				if hit:
					viol.append("c %s segment %s -> %s crosses fixture cell at %s" % [id, q, p, m])
					break


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


func _run_speed(t, speed: int) -> Dictionary:
	var s := _store(t, speed)
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
	var stats := {"moves": 0, "shopping": 0, "picks": 0, "max_jump": 0.0, "frames": 0}
	var step_no := 0
	var guard := 0
	while s.time_sec < RUN_UNTIL_SEC and guard < 200000:
		guard += 1
		var steps := clock.advance(FRAME, speed)
		for i in steps:
			step_no += 1
			if step_no % ARRIVE_EVERY_STEPS == 0:
				s.next_customer_seq += 1
				s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
			runner._run_step()
			_check_logic(s, prev, blocked, viol, stats)
		stats["frames"] += 1
		var views: Array = s._customer_views()
		fake.customers = views
		var before := {}
		for k in pres._pos.keys():
			before[k] = pres._pos[k]
		pres._sync_customers(FRAME * speed)
		_check_presentation(pres, views, before, blocked, viol, stats)
		_check_draw_order(pres, pres.compose(), viol, stats)
	stats["purchased"] = int(s.visit_stats.get("purchased", 0))
	stats["viol"] = viol
	stats["steps"] = step_no
	stats["order_checks"] = int(stats.get("order_checks", 0))
	stats["time_sec"] = s.time_sec
	return stats


func _report(speed: int, st: Dictionary) -> void:
	var viol: Array = st["viol"]
	print("PATHS x%d steps=%d frames=%d moves=%d shopping=%d picks=%d purchased=%d draw_order_checks=%d max_frame_jump=%.3f violations=%d" % [
		speed, st["steps"], st["frames"], st["moves"], st["shopping"], st["picks"], st["purchased"], st["order_checks"], st["max_jump"], viol.size()])
	var by_kind := {}
	for v in viol:
		var k: String = String(v).substr(0, 1)
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	print("  by check: ", by_kind)
	for i in mini(viol.size(), 8):
		print("  ", viol[i])


func test_customer_paths_speed_1(t, _tree) -> void:
	var st := _run_speed(t, 1)
	_report(1, st)
	_assert_clean(t, 1, st)


func test_customer_paths_speed_2(t, _tree) -> void:
	var st := _run_speed(t, 2)
	_report(2, st)
	_assert_clean(t, 2, st)


func test_customer_paths_speed_4(t, _tree) -> void:
	var st := _run_speed(t, 4)
	_report(4, st)
	_assert_clean(t, 4, st)


func _assert_clean(t, speed: int, st: Dictionary) -> void:
	var viol: Array = st["viol"]
	t.ok(int(st["picks"]) > 0, "x%d: customers reached a shelf and picked" % speed)
	t.ok(int(st["moves"]) > 0, "x%d: customers walked" % speed)
	t.ok(viol.is_empty(), "x%d: %d path/presentation violations, first: %s" % [speed, viol.size(), str(viol.slice(0, 3))])


func _clear_of(path: Array, blocked: Dictionary) -> bool:
	for p in path:
		if blocked.has(p):
			return false
	return true


## The customer route cache (CustomerAI._path) follows every layout change: a shelf placed on the route,
## moved across it and removed again must give the same route as a fresh search each time.
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
