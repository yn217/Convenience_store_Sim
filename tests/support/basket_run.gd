extends RefCounted
## Fixed-seed day runner for the basket tests (issue #128). The sample layout (tools/sample_layout.gd) is
## stocked to capacity and opened on day 0; every later morning it is restocked, so demand rather than stock
## decides the sales. No scene and no presentation: GameState + GameCommands + SimulationRunner only.

const LegacyPace := preload("res://tests/support/legacy_pace.gd")

const SampleLayout := preload("res://tools/sample_layout.gd")
const Seeds := preload("res://tests/support/test_seeds.gd")


## `extra` is merged into the balance (test overrides); `base` replaces base_potential_visitors_per_day.
static func new_state(base: float, extra: Dictionary = {}) -> GameState:
	var balance = LegacyPace.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json")))
	balance["base_potential_visitors_per_day"] = base
	balance.merge(extra, true)
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 5000000
	return s


## Places the sample layout and returns the command helper (its command ids are unique per call).
static func place_layout(s: GameState) -> GameCommands:
	var cmds := GameCommands.new(s)
	var n := 0
	for p in SampleLayout.placements():
		n += 1
		cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
	return cmds


static func restock(s: GameState, cmds: GameCommands, round_no: int) -> void:
	var n := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		for slot in def["shelf_slots"]:
			var cat: String = def["allowed_categories"][0]
			for sku in s.products.skus.values():
				if sku["category"] == cat:
					n += 1
					var tag := "%d_%d" % [round_no, n]
					cmds.execute({"command_id": "ro" + tag, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					cmds.execute({"command_id": "rr" + tag, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					break


## Runs `days` full game days. Returns {units: Array, revenue: Array, buyers: Array, visitors: Array,
## peak: int, occupancy: float (mean customers in the store per step), steps: int}.
## `until_hour` (< 24) stops the last day at that game hour: enough for a test that only needs the goods to sell
## (the day is not closed then, so it has no daily report).
static func run_days(s: GameState, cmds: GameCommands, days: int, until_hour: int = 24) -> Dictionary:
	var out := {"units": [], "revenue": [], "buyers": [], "visitors": [], "peak": 0, "occupancy": 0.0, "steps": 0}
	var runner := SimulationRunner.new(s)
	var customer_steps := 0
	var total_steps := 0
	var histogram := {}   # customers in the store -> number of steps with exactly that many
	for day in days:
		restock(s, cmds, day)
		if day == 0:
			cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
		var guard := 0
		var tx_before := s.ledger.transactions.size()
		var stop_sec := day * DemandModel.SECONDS_PER_DAY + until_hour * 3600 if day == days - 1 and until_hour < 24 else 1 << 62
		while s.day == day and guard < 100000 and s.time_sec < stop_sec:
			runner._run_step()
			customer_steps += s.customers.size()
			histogram[s.customers.size()] = int(histogram.get(s.customers.size(), 0)) + 1
			out["peak"] = maxi(int(out["peak"]), s.customers.size())
			total_steps += 1
			guard += 1
		var units := 0
		var revenue := 0
		for i in range(tx_before, s.ledger.transactions.size()):
			var tx: Dictionary = s.ledger.transactions[i]
			if tx["event_type"] == "SALE":
				units += int(tx["details"]["qty"])
				revenue += int(tx["revenue_delta_yen"])
		out["units"].append(units)
		out["revenue"].append(revenue)
		out["buyers"].append(int(s.daily_reports[-1]["purchasing_customers"]) if not s.daily_reports.is_empty() else 0)
		out["visitors"].append(int(s.daily_reports[-1]["visitors"]) if not s.daily_reports.is_empty() else 0)
	out["occupancy"] = float(customer_steps) / float(maxi(total_steps, 1))
	out["steps"] = total_steps
	out["p95"] = _percentile(histogram, total_steps, 0.95)
	return out


## Smallest count k such that at least `q` of the steps had k or fewer customers in the store.
static func _percentile(histogram: Dictionary, total: int, q: float) -> int:
	var keys := histogram.keys()
	keys.sort()
	var seen := 0
	for k in keys:
		seen += int(histogram[k])
		if float(seen) >= q * float(total):
			return int(k)
	return 0


## Everything the simulation owns, as plain values: equal fingerprints mean equal runs.
static func fingerprint(s: GameState) -> Dictionary:
	return {
		"cash": s.cash_yen, "tx": s.ledger.transactions.size(), "rng": s.rng_states.duplicate(),
		"visits": s.visit_stats.duplicate(), "time": s.time_sec, "reservations": s.reservations.size(),
		"customers": s.customers.map(func(c): return [c["customer_id"], c["phase"], c["tile"], c["reservation_ids"]]),
		"last_tx": s.ledger.transactions.back() if not s.ledger.transactions.is_empty() else {},
	}
