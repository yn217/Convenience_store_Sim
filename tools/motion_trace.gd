extends SceneTree
## Customer motion trace (issue #117): what the player sees of customer movement.
## The real simulation runs with fixed seeds on the bench layout (tools/perf_bench.gd PLAN, 16x12, 20 fixtures,
## arrivals queued every ARRIVE_EVERY_STEPS game steps) and FixturePresenter is driven with real frame deltas
## (1/60 s x speed) at x1, x2 and x4. Read-only: it never writes the simulation state.
## Per customer per real second it reports: shown distance, facing changes, facing flips (A-B-A within 0.3 s),
## walk-animation frames while the shown figure stands still, standing time at a shelf and in the queue,
## frames with a jump above one tile, and how many customers are on screen.
## Usage: godot --headless --path . --script res://tools/motion_trace.gd -- <out.json> [seconds=60]

const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const Seeds := preload("res://tests/support/test_seeds.gd")
const FRAME := 1.0 / 60.0
const ARRIVE_EVERY_STEPS := 6   # the crowded setting of tests/scenario/test_customer_paths.gd (about 30 customers in store)
const FLIP_WINDOW := 0.3
const JUMP_TILES := 1.0
const SHELF_RADIUS := 1.2
const MOVE_EPS := 0.0005
const PLAN := [
	["register_basic", 13, 5, 0], ["shelf_general", 3, 2, 0], ["shelf_onigiri", 3, 5, 0], ["shelf_noodle", 3, 8, 0],
	["shelf_bread", 6, 2, 0], ["shelf_snack", 6, 5, 0], ["shelf_general", 6, 8, 0], ["fridge_drink", 9, 2, 0],
	["fridge_dessert", 9, 5, 0], ["freezer_ice", 11, 9, 0], ["warmer_oden", 13, 2, 0], ["shelf_general", 1, 11, 1],
	["shelf_onigiri", 4, 11, 1], ["shelf_snack", 12, 11, 1], ["shelf_bread", 10, 7, 1], ["shelf_noodle", 14, 9, 1],
	["shelf_general", 14, 11, 1], ["fridge_drink", 1, 9, 1], ["shelf_snack", 12, 7, 1], ["fridge_dessert", 8, 9, 1],
]


## Fake StoreWorld: the fields FixturePresenter reads (same as tests/scenario/test_customer_paths.gd).
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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://motion_trace.json"
	var seconds := float(args[1]) if args.size() > 1 else 60.0
	var result := {"seed": Seeds.SEEDS, "layout": "perf_bench PLAN 16x12", "real_seconds": seconds, "arrive_every_steps": ARRIVE_EVERY_STEPS}
	for speed in [1, 2, 4]:
		result["x%d" % speed] = _run_speed(speed, seconds)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print(JSON.stringify(result, "  "))
	quit(0)


func _store() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	balance["base_potential_visitors_per_day"] = 0   # arrivals are queued below, deterministically
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 5000000
	var cmds := GameCommands.new(s)
	var n := 0
	for p in PLAN:
		n += 1
		cmds.execute({"command_id": "mt_place%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
	var k := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		if def["allowed_categories"].is_empty():
			continue
		var cat: String = def["allowed_categories"][0]
		for slot in def["shelf_slots"]:
			for sku in s.products.skus.values():
				if sku["category"] != cat:
					continue
				k += 1
				cmds.execute({"command_id": "mt_order%d" % k, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
				cmds.execute({"command_id": "mt_restock%d" % k, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
				break
	s.business_state = GameState.OPEN
	s.balance["checkout_duration_game_seconds"] = 30
	return s


func _fixture_center(pres: Presenter, cache: Dictionary, fixture_id: String) -> Vector2:
	if not cache.has(fixture_id):
		cache[fixture_id] = pres._fixture_center(fixture_id)
	return cache[fixture_id]


func _run_speed(speed: int, seconds: float) -> Dictionary:
	var s := _store()
	s.speed_setting = speed
	var runner := SimulationRunner.new(s)
	var clock := GameClock.new()
	var pres: Presenter = Presenter.new()
	var fake := FakeWorld.new()
	pres._world = fake
	fake.speed_setting = speed
	fake.fixtures = s.grid.to_save()["fixture_instances"]
	fake.fixture_catalog = s.fixtures
	fake.product_catalog = s.products
	var frames := int(round(seconds / FRAME))
	var step_no := 0
	var t := 0.0
	var customer_sec := 0.0
	var moving_sec := 0.0
	var dist := 0.0
	var max_frame := 0.0
	var jumps := 0
	var facing_changes := 0
	var flips := 0
	var walk_still_frames := 0
	var sim_moves := 0
	var shelf_still := 0.0
	var shelf_walk := 0.0
	var queue_still := 0.0
	var queue_walk := 0.0
	var shelf_ids := {}
	var queue_ids := {}
	var visible_sum := 0
	var visible_max := 0
	var customers_max := 0
	var prev_pos := {}
	var prev_moved := {}
	var fac := {}
	var centers := {}
	for f in frames:
		for i in clock.advance(FRAME, speed):
			step_no += 1
			if step_no % ARRIVE_EVERY_STEPS == 0:
				s.next_customer_seq += 1
				s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
			runner._run_step()
		var views: Array = s._customer_views()
		fake.customers = views
		var dt := FRAME * speed
		pres._sync_customers(dt)
		pres.anim_time += dt
		t += FRAME
		var ordered: Array = pres.compose()
		var visible := 0
		for it in ordered:
			if it["kind"] == "customer":
				visible += 1
		visible_sum += visible
		visible_max = maxi(visible_max, visible)
		customers_max = maxi(customers_max, views.size())
		var alive := {}
		for c in views:
			var id: String = c["customer_id"]
			alive[id] = true
			var v := pres.customer_view(c)
			var pos: Vector2 = v["pos"]
			var facing: int = v["facing"]
			var anim: String = v["anim"]
			var phase: String = c["phase"]
			customer_sec += FRAME
			var moved := false
			if prev_pos.has(id):
				var d: float = pos.distance_to(prev_pos[id])
				moved = d > MOVE_EPS
				dist += d
				max_frame = maxf(max_frame, d)
				if d > JUMP_TILES:
					jumps += 1
			prev_pos[id] = pos
			if moved:
				moving_sec += FRAME
			var mc: int = int(c.get("moved", 0))
			sim_moves += maxi(mc - int(prev_moved.get(id, mc)), 0)
			prev_moved[id] = mc
			if fac.has(id):
				var st: Array = fac[id]
				if facing != st[0]:
					facing_changes += 1
					if facing == st[1] and t - float(st[2]) < FLIP_WINDOW:
						flips += 1
					st[1] = st[0]
					st[0] = facing
					st[2] = t
			else:
				fac[id] = [facing, facing, t]
			if anim == "walk" and not moved:
				walk_still_frames += 1
			var fid := String(c.get("fixture_id", ""))
			var near_shelf := fid != "" and _fixture_center(pres, centers, fid).distance_to(pos) < SHELF_RADIUS
			if (phase == "WALK_SHELF" or phase == "WAIT_QUEUE" or phase == "WALK_REGISTER") and near_shelf:
				shelf_ids[id] = true
				if moved:
					shelf_walk += FRAME
				else:
					shelf_still += FRAME
			if phase == "QUEUE" or phase == "WAIT_QUEUE":
				queue_ids[id] = true
				if moved:
					queue_walk += FRAME
				else:
					queue_still += FRAME
		for id in prev_pos.keys():
			if not alive.has(id):
				prev_pos.erase(id)
				prev_moved.erase(id)
				fac.erase(id)
	var cs := maxf(customer_sec, 1e-9)
	var real := frames * FRAME
	var shelf_n := maxi(shelf_ids.size(), 1)
	var queue_n := maxi(queue_ids.size(), 1)
	return {
		"customers_avg": snappedf(customer_sec / real, 0.01), "customers_max": customers_max,
		"on_screen_avg": snappedf(float(visible_sum) / maxf(frames, 1), 0.01), "on_screen_max": visible_max,
		"shown_tiles_per_customer_s": snappedf(dist / cs, 0.0001),
		"sim_tiles_per_customer_s": snappedf(float(sim_moves) / cs, 0.0001),
		"moving_fraction": snappedf(moving_sec / cs, 0.001),
		"max_shown_tiles_per_frame": snappedf(max_frame, 0.0001),
		"frames_jump_over_1_tile": jumps,
		"facing_changes_per_customer_s": snappedf(float(facing_changes) / cs, 0.0001),
		"facing_flips_within_0_3s": flips,
		"walk_anim_while_still_s_per_customer_s": snappedf(float(walk_still_frames) * FRAME / cs, 0.0001),
		"shelf_still_s_per_customer": snappedf(shelf_still / shelf_n, 0.01),
		"shelf_walk_s_per_customer": snappedf(shelf_walk / shelf_n, 0.01),
		"queue_still_s_per_customer": snappedf(queue_still / queue_n, 0.01),
		"queue_walk_s_per_customer": snappedf(queue_walk / queue_n, 0.01),
		"customers_reaching_shelf": shelf_ids.size(), "customers_in_queue": queue_ids.size(),
		"purchased": int(s.visit_stats.get("purchased", 0)), "sim_time_sec": snappedf(s.time_sec, 0.01),
	}
