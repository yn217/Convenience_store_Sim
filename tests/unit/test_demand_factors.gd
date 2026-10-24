extends RefCounted
## Issue #27: price attractiveness, assortment, reputation and the balance-driven parameters.

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	_n += 1
	var c := {"command_id": "f%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _near(a: float, b: float, eps: float = 1e-9) -> bool:
	return absf(a - b) < eps


## Shelf with two rice-ball SKUs (rice_001 150 yen, rice_002) and a register; OPEN.
func _store() -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	for spec in [["rice_001", "row0"], ["rice_002", "row1"]]:
		_run(cmds, &"ORDER_STOCK", {"sku_id": spec[0], "qty": 12})
		_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": spec[1], "sku_id": spec[0], "qty": 12})
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.balance["base_potential_visitors_per_day"] = 0
	return s


func _arrive(s: GameState, n: int = 1) -> void:
	for i in n:
		s.next_customer_seq += 1
		s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})


func test_defaults_are_the_spec_values(t, _tree) -> void:
	t.ok(_near(DemandModel.param({}, "base_purchase_probability", 0.8), 0.8))
	t.ok(_near(DemandModel.price_factor(150, 150), 1.0))
	t.ok(_near(DemandModel.price_factor(150, 300), 0.5))
	t.ok(_near(DemandModel.price_factor(150, 100), 1.5))
	t.ok(_near(DemandModel.price_factor(150, 1500), 0.3), "floor 0.3")
	t.ok(_near(DemandModel.price_factor(150, 10), 2.0), "cap 2.0")
	t.ok(_near(DemandModel.price_factor(150, 0), 2.0), "a zero price cannot divide by zero")
	t.ok(_near(DemandModel.purchase_probability(1.0), 0.8))
	t.ok(_near(DemandModel.purchase_probability(2.0), 0.95), "cap 0.95")
	t.ok(_near(DemandModel.purchase_probability(0.3), 0.24))
	t.ok(_near(DemandModel.purchase_probability(0.0), 0.05), "floor 0.05")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	t.ok(balance.has("demand_model"), "the coefficients live in the balance data")
	t.ok(_near(DemandModel.price_factor(150, 300, balance), 0.5), "shipped balance = defaults")
	for c in ProductCatalog.CATEGORIES:
		t.ok(_near(DemandModel.category_preference(c, balance), 1.0), c)


func test_higher_price_lowers_the_relative_weight(t, _tree) -> void:
	var s := _store()
	var ai := CustomerAI.new()
	var base := ai.candidates(s)
	t.eq(base.size(), 2)
	t.ok(_near(base[0]["weight"], base[1]["weight"]), "same price level, same weight")
	s.product_price_overrides["rice_001"] = 300   # double the reference price
	var w1 := 0.0
	var w2 := 0.0
	for c in ai.candidates(s):
		if c["sku_id"] == "rice_001":
			w1 = c["weight"]
		else:
			w2 = c["weight"]
	t.ok(_near(w1, 0.5), "factor 0.5 at double the price")
	t.ok(w1 < w2, "the dearer item is relatively less likely to be picked")
	t.ok(_near(w1 / (w1 + w2), 0.5 / 1.5), "share of the choice")
	s.product_price_overrides["rice_001"] = 75   # half price
	for c in ai.candidates(s):
		if c["sku_id"] == "rice_001":
			t.ok(_near(c["weight"], 2.0), "cheaper = more attractive, capped at 2.0")


func test_elasticity_and_preference_come_from_the_balance(t, _tree) -> void:
	var s := _store()
	s.balance["demand_model"] = {"price_elasticity": 2.0, "category_preference": {"rice_ball": 3.0}}
	s.product_price_overrides["rice_001"] = 200
	var ai := CustomerAI.new()
	for c in ai.candidates(s):
		if c["sku_id"] == "rice_001":
			t.ok(_near(c["weight"], 3.0 * 0.5625), "(150/200)^2 = 0.5625, times preference 3")
		else:
			t.ok(_near(c["weight"], 3.0))
	s.balance["demand_model"] = {"category_preference": {"rice_ball": 0.0}}
	_arrive(s)
	s.time_sec += 2
	ai.step(s)
	t.eq(s.customers[0]["outcome"], "no_candidate", "a category nobody wants is never picked")


func test_higher_price_lowers_the_real_purchase_rate_with_the_same_seed(t, _tree) -> void:
	var declined: Array[int] = []
	for price in [150, 600]:
		var s := _store()
		s.product_price_overrides["rice_001"] = price
		s.product_price_overrides["rice_002"] = price
		var ai := CustomerAI.new()
		_arrive(s, 20)
		s.time_sec += 2
		ai.step(s)
		var n := 0
		for c in s.customers:
			if c["outcome"] == "declined":
				n += 1
		declined.append(n)
	t.ok(declined[1] > declined[0], "more customers walk away at 4x the price: %s" % str(declined))


func test_sold_out_sku_is_not_offered_and_inaccessible_shelves_sell_nothing(t, _tree) -> void:
	var s := _store()
	var ai := CustomerAI.new()
	for seg in s.inventory_segments:
		if seg["sku_id"] == "rice_001":
			seg["physical_qty"] = 0
	t.eq(ai.candidates(s).size(), 1, "the sold-out SKU has no weight at all")
	t.eq(ai.candidates(s)[0]["sku_id"], "rice_002")
	for spec in [["blk1", 5, 4], ["blk2", 5, 5], ["blk3", 5, 6]]:
		s.grid.add_instance({"instance_id": spec[0], "type_id": "warmer_oden", "x": spec[1], "y": spec[2], "rotation": 0, "enabled": true}, s.fixtures)
	t.eq(ai.candidates(s).size(), 0, "walled-in shelf: nothing can be sold from it")


func test_reputation_golden_updates(t, _tree) -> void:
	var cases := [
		[{"entered": 10, "purchased": 10}, {"abandoned": 0, "stockouts": 0}, 1],
		[{"entered": 10, "purchased": 8}, {"abandoned": 0, "stockouts": 0}, 1],
		[{"entered": 10, "purchased": 6}, {"abandoned": 0, "stockouts": 0}, 0],
		[{"entered": 10, "purchased": 5}, {"abandoned": 5, "stockouts": 0}, -1],
		[{"entered": 10, "purchased": 0}, {"abandoned": 10, "stockouts": 10}, -3],
		[{"entered": 0, "purchased": 0}, {"abandoned": 0, "stockouts": 0}, -1],
		[{"entered": 10, "purchased": 10}, {"abandoned": 0, "stockouts": 10}, 0],
	]
	for c in cases:
		t.eq(ReputationModel.daily_delta(c[0], c[1]), c[2], str(c))
	t.eq(ReputationModel.next_reputation(99, {"entered": 10, "purchased": 10}, {"abandoned": 0, "stockouts": 0}), 100, "capped at 100")
	t.eq(ReputationModel.next_reputation(1, {"entered": 10, "purchased": 0}, {"abandoned": 10, "stockouts": 10}), 0, "floored at 0")
	t.eq(ReputationModel.next_reputation(0, {"entered": 10, "purchased": 0}, {"abandoned": 10, "stockouts": 10}), 0)
	for rep in [0, 25, 50, 75, 100]:
		for purchased in [0, 5, 10]:
			var r := ReputationModel.next_reputation(rep, {"entered": 10, "purchased": purchased}, {"abandoned": 3, "stockouts": 2})
			t.ok(r >= 0 and r <= 100)
	var tuned := {"demand_model": {"reputation_update": {"max_daily_change": 1}}}
	t.eq(ReputationModel.daily_delta({"entered": 10, "purchased": 0}, {"abandoned": 10, "stockouts": 10}, tuned), -1, "the cap is tunable")


func test_reputation_moves_the_next_day_and_is_reproducible(t, _tree) -> void:
	var results: Array[int] = []
	for run in 2:
		var s := _store()
		s.balance["base_potential_visitors_per_day"] = 3000
		s.time_sec = 11 * 3600
		s.speed_setting = 4
		var runner := SimulationRunner.new(s)
		var steps := 0
		while steps < 3000:
			steps += runner.process_frame(1.0 / 15.0)
		s.close_day_once(s.day)
		t.ok(s.reputation >= 0 and s.reputation <= 100)
		t.eq(s.rate_stats, {"abandoned": 0, "stockouts": 0}, "counters restart after the daily update")
		results.append(s.reputation)
	t.eq(results[0], results[1], "same seeds and ticks -> same reputation")
	var empty_day := _store()
	empty_day.close_day_once(0)
	t.eq(empty_day.daily_reports[0]["store_reputation"], 50, "the report shows the reputation the day was played with")
	t.eq(empty_day.reputation, 49, "an empty day: purchase rate counts as 0 -> -1 (03 F)")


func test_queue_giveups_and_stockouts_are_counted_separately(t, _tree) -> void:
	var s := _store()
	s.balance["checkout_base_game_seconds"] = 100000
	var ai := CustomerAI.new()
	_arrive(s, 3)
	for i in 120:
		s.time_sec += 2
		ai.step(s)
	t.ok(s.rate_stats["abandoned"] >= 1, "the customers stuck behind the till gave up: %s" % str(s.rate_stats))
	var empty := _state()
	empty.business_state = GameState.OPEN
	empty.speed_setting = 1
	var ai2 := CustomerAI.new()
	_arrive(empty, 4)
	empty.time_sec += 2
	ai2.step(empty)
	t.eq(empty.rate_stats["stockouts"], 4, "nothing to buy counts as a stock-out")
	t.eq(empty.rate_stats["abandoned"], 0)
	t.eq(empty.visit_stats["purchased"], 0)


func test_advertising_and_assortment_do_not_touch_the_purchase_chance(t, _tree) -> void:
	var tiers: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))["advertising_tiers"]
	var base := DemandModel.step_probability(12, 100.0, 1.0, 50, 4)
	var more_ads := DemandModel.step_probability(12, 100.0, DemandModel.ad_multiplier(tiers, 5000), 50, 4)
	var wider := DemandModel.step_probability(12, 100.0, 1.0, 50, 8)
	t.ok(more_ads > base and wider > base, "both raise how many people come")
	t.ok(_near(DemandModel.purchase_probability(1.0), 0.8), "and neither appears in the buy decision")
	t.ok(_near(more_ads / base, 1.3), "ad tier is exactly its multiplier")
	t.ok(_near(wider / base, DemandModel.assortment_multiplier(8) / DemandModel.assortment_multiplier(4)))
