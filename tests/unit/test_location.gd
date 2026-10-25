extends RefCounted
## Issue #148: the store location shapes the day — visitors by hour, purposes, best sellers and budgets.

const Run := preload("res://tests/support/basket_run.gd")


func test_location_table_is_well_formed(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var purposes := {}
	for p in balance["visit_purposes"]:
		purposes[p["purpose_id"]] = true
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var cats := {}
	for sku in pr.skus.values():
		cats[sku["category"]] = true
	var ids: Array = StoreLocation.all().map(func(l): return l["location_id"])
	t.eq(ids, ["station", "school", "office", "residential"], "four locations")
	for l in StoreLocation.all():
		t.eq((l["hour_weights"] as Array).size(), 24, l["location_id"] + ": 24 hour weights")
		t.ok(String(l["description"]) != "", "a description for the picker")
		for k in l["purpose_multipliers"]:
			t.ok(purposes.has(k), "%s: purpose %s exists" % [l["location_id"], k])
		for k in l["category_multipliers"]:
			t.ok(cats.has(k), "%s: category %s exists" % [l["location_id"], k])
		var w := StoreLocation.hour_weights(l["location_id"])
		var total := 0.0
		for x in w:
			total += x
		t.ok(absf(total - 24.0) < 0.001, "normalised to mean 1")
	t.eq(StoreLocation.hour_weights(""), DemandModel.normalized_hour_weights(), "the standard store keeps the old curve")


## Potential visitors by hour over one day (arrivals only, no customers walking), same seed for every location.
func _arrivals_by_hour(location_id: String) -> Array:
	var s := Run.new_state(600.0)
	var cmds := Run.place_layout(s)
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	s.location_id = location_id
	var out: Array = []
	out.resize(24)
	out.fill(0)
	while s.time_sec < DemandModel.SECONDS_PER_DAY:
		s.time_sec += int(GameClock.STEP_GAME_SECONDS)
		if DemandGenerator.step(s):
			out[DemandModel.hour_of_day(s.time_sec)] += 1
		s.arrival_queue.clear()
	return out


static func _peak(a: Array, hours: Array) -> int:
	var best: int = hours[0]
	for h in hours:
		if int(a[h]) > int(a[best]):
			best = h
	return best


func test_visitors_follow_the_location(t, _tree) -> void:
	var office := _arrivals_by_hour("office")
	var school := _arrivals_by_hour("school")
	var station := _arrivals_by_hour("station")
	var home := _arrivals_by_hour("residential")
	var day := range(6, 23)
	t.eq(_peak(office, day), 12, "office: the lunch peak at 12 (%s)" % str(office))
	t.ok(_peak(school, day) in [15, 16], "school: after school (%d)" % _peak(school, day))
	t.ok(_peak(station, day) in [7, 8, 18], "station: commuters (%d)" % _peak(station, day))
	t.ok(_peak(home, day) in [16, 17, 18, 19], "residential: the evening before dinner, 16-19 (%d)" % _peak(home, day))
	t.ok(int(office[2]) < int(home[2]), "offices are empty at night, homes are not")
	var total := func(a): var n := 0; for v in a: n += int(v); return n
	t.ok(int(total.call(station)) > int(total.call(home)), "a station brings more people than a residential street")


func test_purposes_follow_the_location(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var share := func(loc: String, hour: int, purpose: String) -> float:
		var pick := Lcg32.new(55)
		var money := Lcg32.new(66)
		var n := 0
		for i in 3000:
			if VisitPurpose.draw(pick, money, hour, balance, loc)["purpose_id"] == purpose:
				n += 1
		return float(n) / 3000.0
	t.ok(share.call("office", 12, "lunch") > share.call("residential", 12, "lunch"), "lunch is an office thing")
	t.ok(share.call("residential", 17, "stock_up") > share.call("station", 17, "stock_up"), "stock-up shopping happens at home")
	t.ok(share.call("school", 15, "snack_time") > share.call("office", 15, "snack_time"), "after-school snacks")
	var budgets := func(loc: String) -> int:
		var pick := Lcg32.new(1)
		var money := Lcg32.new(2)
		var sum := 0
		for i in 500:
			sum += int(VisitPurpose.draw(pick, money, 15, balance, loc)["budget_yen"])
		return sum
	t.ok(int(budgets.call("school")) < int(budgets.call("residential")), "students spend less than families")


## A day with customers: what sells follows the location (same seed, layout and stock).
func _category_units(location_id: String) -> Dictionary:
	var s := Run.new_state(200.0)
	var cmds := Run.place_layout(s)
	s.location_id = location_id
	Run.run_days(s, cmds, 1)
	var out := {}
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE":
			var cat: String = s.products.get_sku(String(tx["details"].get("sku_id", "")))["category"] if s.products.has_sku(String(tx["details"].get("sku_id", ""))) else "?"
			out[cat] = int(out.get(cat, 0)) + int(tx["details"].get("qty", 1))
	return out


func test_best_sellers_follow_the_location(t, _tree) -> void:
	var office := _category_units("office")
	var school := _category_units("school")
	var share := func(d: Dictionary, cats: Array) -> float:
		var all := 0
		var part := 0
		for k in d:
			all += int(d[k])
			if cats.has(k):
				part += int(d[k])
		return 0.0 if all == 0 else float(part) / float(all)
	print("LOCATION office=%s school=%s" % [office, school])
	t.ok(float(share.call(school, ["snack", "ice_cream"])) > float(share.call(office, ["snack", "ice_cream"])), "snacks and ice sell better by a school")
	t.ok(float(share.call(office, ["rice_ball", "instant_noodle"])) > float(share.call(school, ["rice_ball", "instant_noodle"])), "onigiri and noodles sell better among offices")


func test_location_is_chosen_before_the_first_opening(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var r := cmds.execute({"command_id": "loc1", "kind": &"SET_LOCATION", "location_id": "office"})
	t.ok(r.ok, "chosen in SETUP")
	t.eq(s.location_id, "office")
	t.eq(String(s.snapshot()["location_name"]), "オフィス街")
	t.ok(not cmds.execute({"command_id": "loc2", "kind": &"SET_LOCATION", "location_id": "moon"}).ok, "an unknown location is refused")
	var saved := SaveGame.to_dict(s, "loc", "2026-10-25T00:00:00Z")
	var lr := SaveGame.from_dict(saved, s.balance, s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).location_id, "office", "the location survives a save")
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	SimulationRunner.new(s)._run_step()
	r = cmds.execute({"command_id": "loc3", "kind": &"SET_LOCATION", "location_id": "school"})
	t.ok(not r.ok and r.message_key == &"location_locked", "no moving after the store has opened")
