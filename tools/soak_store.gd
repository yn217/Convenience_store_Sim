extends SceneTree
## Soak run on a realistic store (data/layouts/realistic_store_v1.json, large 20x16): the real balance (slow walking,
## staff, outdoor approach), every morning the backroom is reordered so the staff restock, and the day runs to the end.
## Read-only watchers flag what a player would see as broken:
##   customers: standing still in a walking phase, a visit far longer than normal, the same tile entered again and
##              again (a loop), many phase changes in one visit, a phase that never ends;
##   staff:     standing still in a walking phase, phase flapping (many changes per hour), shelves left empty while
##              stock waits in the backroom and nobody is busy, people waiting at a closed till.
## Usage: godot --headless --path . --script res://tools/soak_store.gd -- <out.json> [days=3] [visitors_x=1.0] [staff=4] [location=station]

const Seeds := preload("res://tests/support/test_seeds.gd")
const LAYOUT := "res://data/layouts/realistic_store_v1.json"
const WALKING := ["APPROACH", "ENTER", "WALK_SHELF", "WALK_REGISTER", "EXIT", "WALK_AWAY"]
const STAFF_WALKING := ["TO_REGISTER", "TO_PICKUP", "TO_SHELF", "TO_REST"]
const STILL_SEC := 180            # a walker that has not changed tile for this long is stuck
const LONG_VISIT_SEC := 3 * 3600  # far beyond browse + queue + checkout
const REVISIT_LIMIT := 6          # entering one tile more often than this in one visit = walking in circles
const FLAP_PER_HOUR := 40         # staff phase changes per game hour


static func layout() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))


## A stocked, open store on the realistic layout. Returns {state, cmds, placed, failed}.
static func build(location: String, staff_n: int, visitors_x: float) -> Dictionary:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	balance["base_potential_visitors_per_day"] = float(balance["base_potential_visitors_per_day"]) * visitors_x
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 50000000
	var cmds := GameCommands.new(s)
	var lay := layout()
	cmds.execute({"command_id": "size", "kind": &"SET_STORE_SIZE", "size_id": lay.get("store_size", "large")})
	if location != "":
		cmds.execute({"command_id": "loc", "kind": &"SET_LOCATION", "location_id": location})
	var failed: Array = []
	var n := 0
	for p in lay["placements"]:
		n += 1
		var r := cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p["type_id"], "x": int(p["x"]), "y": int(p["y"]), "rotation": int(p["rotation"])})
		if not r.ok:
			failed.append("%s@(%d,%d) r%d: %s" % [p["type_id"], p["x"], p["y"], p["rotation"], r.message_key])
	while s.staff.size() < staff_n:
		s.staff.append(StaffAI.make(s, {"name": "追加%d" % s.staff.size(), "skills": {"register": 3, "restock": 3, "stamina": 3, "service": 3}}, s.staff[0]["tile"]))
	stock(s, cmds, 0, true)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	return {"state": s, "cmds": cmds, "placed": s.grid.instances.size(), "failed": failed}


## Orders stock for every shelf slot; on day 0 the shelves are filled too, later days only the backroom (staff restock).
static func stock(s: GameState, cmds: GameCommands, day: int, fill: bool) -> void:
	var n := 0
	var ids := s.grid.instances.keys()
	ids.sort()
	for id in ids:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		var i := 0
		for slot in def["shelf_slots"]:
			var cats: Array = def["allowed_categories"]
			var cat: String = cats[i % cats.size()]
			i += 1
			var skus: Array = s.products.skus.values().filter(func(k): return k["category"] == cat)
			if skus.is_empty():
				continue
			var sku: Dictionary = skus[(n) % skus.size()]
			n += 1
			var units := maxi(int(sku["slot_units"]), 1)
			var qty := int(slot["capacity_units"]) / units
			var tag := "%d_%d" % [day, n]
			cmds.execute({"command_id": "o" + tag, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": qty * (2 if fill else 1)})
			if fill:
				cmds.execute({"command_id": "r" + tag, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": qty})


class Watch:
	var issues: Array = []
	var counts := {}
	var visits: Dictionary = {}     # customer id -> {tile, since, enter, tiles{}, phases, phase, phase_since, flagged{}}
	var staff_w: Dictionary = {}    # staff id -> {tile, since, changes_hour[], phase, phase_time{}}
	var finished: Array = []        # [seconds in store, outcome, max revisits, phase changes]
	var starve_steps := 0
	var closed_wait_steps := 0
	var steps := 0

	func _issue(kind: String, who: String, t: int, detail: String) -> void:
		counts[kind] = int(counts.get(kind, 0)) + 1
		if int(counts[kind]) <= 15:
			issues.append({"kind": kind, "who": who, "time": "%d %02d:%02d" % [t / 86400, (t % 86400) / 3600, (t % 3600) / 60], "detail": detail})

	func observe(s: GameState) -> void:
		steps += 1
		var t := s.time_sec
		var seen := {}
		for c in s.customers:
			var id: String = c["customer_id"]
			seen[id] = true
			if not visits.has(id):
				visits[id] = {"tile": c["tile"], "since": t, "enter": t, "tiles": {}, "phases": 0, "phase": c["phase"], "phase_since": t, "flagged": {}}
			var v: Dictionary = visits[id]
			if c["tile"] != v["tile"]:
				v["tile"] = c["tile"]
				v["since"] = t
				if not c["phase"] in ["APPROACH", "WALK_AWAY"]:
					v["tiles"][c["tile"]] = int(v["tiles"].get(c["tile"], 0)) + 1
					if int(v["tiles"][c["tile"]]) > REVISIT_LIMIT and not v["flagged"].has("loop"):
						v["flagged"]["loop"] = true
						_issue("customer_loop", id, t, "tile %s entered %d times, phase %s, outcome so far %s" % [c["tile"], v["tiles"][c["tile"]], c["phase"], c.get("outcome", "")])
			if c["phase"] != v["phase"]:
				v["phase"] = c["phase"]
				v["phase_since"] = t
				v["since"] = t   # standing in line or at the till is not being stuck
				v["phases"] = int(v["phases"]) + 1
			if c["phase"] in WALKING and not (c["path"] as Array).is_empty() and t - int(v["since"]) >= STILL_SEC and not v["flagged"].has("still"):
				v["flagged"]["still"] = true
				_issue("customer_still", id, t, "%s at %s for %ds, next %s" % [c["phase"], c["tile"], t - int(v["since"]), c["path"][0]])
			if t - int(v["enter"]) >= LONG_VISIT_SEC and not v["flagged"].has("long"):
				v["flagged"]["long"] = true
				_issue("customer_long_visit", id, t, "%ds in the store, phase %s at %s" % [t - int(v["enter"]), c["phase"], c["tile"]])
		for id in visits.keys():
			if not seen.has(id):
				var v: Dictionary = visits[id]
				var most := 0
				for k in v["tiles"]:
					most = maxi(most, int(v["tiles"][k]))
				finished.append([t - int(v["enter"]), "", most, int(v["phases"])])
				visits.erase(id)
		var reg := ""
		for st in s.staff:
			var id: String = st["staff_id"]
			if not staff_w.has(id):
				staff_w[id] = {"tile": st["tile"], "since": t, "changes": [], "phase": st["phase"], "phase_time": {}, "flagged": {}}
			var w: Dictionary = staff_w[id]
			w["phase_time"][st["phase"]] = int(w["phase_time"].get(st["phase"], 0)) + int(GameClock.STEP_GAME_SECONDS)
			if st["tile"] != w["tile"]:
				w["tile"] = st["tile"]
				w["since"] = t
			if st["phase"] != w["phase"]:
				w["phase"] = st["phase"]
				w["since"] = t
				(w["changes"] as Array).append(t)
				while not (w["changes"] as Array).is_empty() and t - int(w["changes"][0]) > 3600:
					(w["changes"] as Array).pop_front()
				if (w["changes"] as Array).size() > FLAP_PER_HOUR and not w["flagged"].has("flap%d" % (t / 3600)):
					w["flagged"]["flap%d" % (t / 3600)] = true
					_issue("staff_flapping", id, t, "%d phase changes in the last hour, now %s at %s" % [(w["changes"] as Array).size(), st["phase"], st["tile"]])
			if st["phase"] in STAFF_WALKING and not (st["path"] as Array).is_empty() and t - int(w["since"]) >= STILL_SEC and not w["flagged"].has("still%d" % int(w["since"])):
				w["flagged"]["still%d" % int(w["since"])] = true
				_issue("staff_still", id, t, "%s at %s for %ds" % [st["phase"], st["tile"], t - int(w["since"])])
			if st["phase"] == "REGISTER":
				reg = id
		var waiting := 0
		for c in s.customers:
			if c["phase"] in ["QUEUE", "WAIT_QUEUE", "CHECKOUT"]:
				waiting += 1
		if waiting > 0 and reg == "":
			closed_wait_steps += 1
		# Restock starvation: an empty slot with backroom stock while every person is idle (sampled each minute).
		if steps % 30 == 0 and s.staff.all(func(x): return x["phase"] in ["IDLE"]) and _has_empty_slot_with_stock(s):
			starve_steps += 1

	func _has_empty_slot_with_stock(s: GameState) -> bool:
		for seg_owner in s.grid.instances:
			var def := s.fixtures.get_type(s.grid.instances[seg_owner]["type_id"])
			for slot in def["shelf_slots"]:
				var have := 0
				var sku := ""
				for seg in s.inventory_segments:
					var loc: Dictionary = seg["location"]
					if loc["kind"] == "FIXTURE" and loc["fixture_id"] == seg_owner and loc["slot_id"] == slot["slot_id"]:
						have += int(seg["physical_qty"])
						sku = seg["sku_id"]
				if have == 0:
					for k in s.products.skus:
						if slot["allowed_categories"].has(s.products.get_sku(k)["category"]) and s.backroom_available(k) > 0:
							return true
		return false


static func run(days: int, visitors_x: float, staff_n: int, location: String) -> Dictionary:
	var b := build(location, staff_n, visitors_x)
	var s: GameState = b["state"]
	var cmds: GameCommands = b["cmds"]
	var runner := SimulationRunner.new(s)
	var w := Watch.new()
	var outcomes := {}
	var day_rows: Array = []
	var start := Time.get_ticks_msec()
	for day in days:
		if day > 0:
			stock(s, cmds, day, false)
		var guard := 0
		while s.day == day and guard < 200000:
			runner._run_step()
			w.observe(s)
			guard += 1
			if s.time_sec % 3600 == 0:
				print("day %d %02d:00 customers=%d staff=%s real=%ds" % [s.day, (s.time_sec % 86400) / 3600, s.customers.size(), s.staff.map(func(x): return x["phase"]), (Time.get_ticks_msec() - start) / 1000])
		var rep: Dictionary = s.daily_reports[-1] if not s.daily_reports.is_empty() else {}
		day_rows.append({"day": day, "visitors": rep.get("visitors", 0), "buyers": rep.get("purchasing_customers", 0), "revenue": rep.get("revenue_yen", 0),
			"balked": rep.get("balked_customers", 0), "lost": rep.get("lost_customers", rep.get("abandoned_customers", 0))})
	var durations: Array = w.finished.map(func(f): return int(f[0]))
	durations.sort()
	var revisit: Array = w.finished.map(func(f): return int(f[2]))
	revisit.sort()
	var staff_out := {}
	for id in w.staff_w:
		staff_out[id] = w.staff_w[id]["phase_time"]
	return {
		"layout": "realistic_store_v1", "days": days, "visitors_x": visitors_x, "staff": staff_n, "location": location,
		"placed": b["placed"], "placement_failures": b["failed"], "real_ms": Time.get_ticks_msec() - start, "steps": w.steps,
		"days_report": day_rows, "visit_stats": s.visit_stats.duplicate(),
		"finished_visits": w.finished.size(), "still_in_store": s.customers.size(),
		"visit_sec_p50": durations[durations.size() / 2] if not durations.is_empty() else 0,
		"visit_sec_p95": durations[int(durations.size() * 0.95)] if not durations.is_empty() else 0,
		"visit_sec_max": durations[-1] if not durations.is_empty() else 0,
		"max_tile_revisits": revisit[-1] if not revisit.is_empty() else 0,
		"issue_counts": w.counts, "issues": w.issues,
		"restock_starved_steps": w.starve_steps, "people_waiting_at_closed_till_steps": w.closed_wait_steps,
		"staff_phase_seconds": staff_out,
	}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://soak.json"
	var days := int(a[1]) if a.size() > 1 else 3
	var vx := float(a[2]) if a.size() > 2 else 1.0
	var staff_n := int(a[3]) if a.size() > 3 else 4
	var loc := String(a[4]) if a.size() > 4 else "station"
	var result := run(days, vx, staff_n, loc)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	print(JSON.stringify(result, "  "))
	quit(0)
