extends RefCounted
## Issue #14: hour weights, step probability, deterministic arrivals (09 §1-2, 10 §7).

const Seeds := preload("res://tests/support/test_seeds.gd")


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _open(s: GameState, speed: int = 1) -> SimulationRunner:
	s.business_state = GameState.OPEN
	s.speed_setting = speed
	return SimulationRunner.new(s)


func _near(a: float, b: float, eps: float = 1e-9) -> bool:
	return absf(a - b) < eps


func test_hour_weights_are_normalized_to_mean_one(t, _tree) -> void:
	var w := DemandModel.normalized_hour_weights()
	var sum := 0.0
	for x in w:
		sum += x
	t.ok(_near(sum, 24.0), "sum is 24")
	# raw sum = 3 + 6.25 + 5.25 + 3 + 6 + 2.25 = 25.75 -> mean 25.75 / 24
	t.ok(_near(w[0], 0.5 / (25.75 / 24.0)))
	t.ok(_near(w[12], 1.75 / (25.75 / 24.0)))
	t.ok(w[12] > w[8] and w[8] > w[15] and w[15] > w[3], "lunch > morning > afternoon > night")


func test_step_probability_golden_values(t, _tree) -> void:
	var norm12 := 1.75 / (25.75 / 24.0)
	var p := DemandModel.step_probability(12, 100.0, 1.0, 50, 8)
	t.ok(_near(p, 100.0 * norm12 * 1.0 * 1.0 / 43200.0), "reputation 50 and 8 categories are x1.0")
	t.ok(_near(DemandModel.reputation_multiplier(0), 0.75))
	t.ok(_near(DemandModel.reputation_multiplier(100), 1.25))
	t.ok(_near(DemandModel.assortment_multiplier(0), 0.75))
	t.ok(_near(DemandModel.assortment_multiplier(8), 1.0))
	t.ok(_near(DemandModel.assortment_multiplier(4), 0.875))
	var tiers: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))["advertising_tiers"]
	t.ok(_near(DemandModel.ad_multiplier(tiers, 5000), 1.3))
	t.ok(_near(DemandModel.ad_multiplier(tiers, 0), 1.0))
	t.ok(_near(DemandModel.ad_multiplier(tiers, 777), 1.0), "unknown budget = no advertising")
	t.ok(_near(DemandModel.step_probability(12, 1e9, 1.4, 100, 8), 1.0), "clamped to 1")
	t.ok(_near(DemandModel.step_probability(12, 0.0, 1.4, 100, 8), 0.0))
	t.eq(DemandModel.hour_of_day(0), 0)
	t.eq(DemandModel.hour_of_day(3600 * 13 + 59), 13)
	t.eq(DemandModel.hour_of_day(86400 + 7200), 2, "wraps at midnight")


func test_same_seed_and_ticks_give_identical_arrivals(t, _tree) -> void:
	var a := _state()
	var b := _state()
	var ra := _open(a)
	var rb := _open(b, 4)
	a.time_sec = 12 * 3600
	b.time_sec = 12 * 3600
	# 1x in small frames vs 4x in big frames: same number of steps, same results.
	var steps_a := 0
	while steps_a < 36000:
		steps_a += ra.process_frame(1.0 / 60.0)
	var steps_b := 0
	while steps_b < 36000:
		steps_b += rb.process_frame(1.0 / 15.0)
	t.eq(a.time_sec, b.time_sec, "same ticks")
	t.eq(a.visit_stats, b.visit_stats, "same arrivals")
	t.eq(a.rng_states, b.rng_states, "same RNG state")
	t.eq(a.arrival_queue, b.arrival_queue)
	t.ok(a.visit_stats["potential"] > 0, "the lunch hour produced visitors")


func test_one_arrivals_draw_per_open_step_and_other_streams_untouched(t, _tree) -> void:
	var s := _state()
	var runner := _open(s)
	var ref := Lcg32.new(Seeds.ARRIVALS)
	for i in 100:
		ref.next_state()
	var steps := 0
	while steps < 100:
		steps += runner.process_frame(1.0 / 30.0)
	t.eq(s.time_sec, 200)
	t.eq(s.rng_states["arrivals"], ref.state, "exactly one draw per step")
	t.eq(s.rng_states["purchases"], Seeds.PURCHASES)
	t.eq(s.rng_states["visuals"], Seeds.VISUALS)


func test_paused_setup_and_closing_change_nothing(t, _tree) -> void:
	var s := _state()
	var runner := SimulationRunner.new(s)
	var before := s.snapshot()
	t.eq(runner.process_frame(10.0), 0, "SETUP")
	s.business_state = GameState.OPEN
	s.speed_setting = 0
	t.eq(runner.process_frame(10.0), 0, "OPEN but paused")
	t.eq(s.snapshot()["rng_states"], before["rng_states"])
	t.eq(s.time_sec, 0)
	s.speed_setting = 1
	s.business_state = GameState.CLOSING
	runner.process_frame(5.0)
	t.eq(s.visit_stats, {"potential": 0, "entered": 0, "lost": 0}, "closing admits nobody")
	t.eq(s.rng_states["arrivals"], Seeds.ARRIVALS, "and draws nothing")
	t.ok(s.time_sec > 0, "closing time still passes")


func test_full_store_loses_visitors_and_empty_store_does_not_crash(t, _tree) -> void:
	var s := _state()
	s.balance["base_potential_visitors_per_day"] = 1.0e9   # p = 1 every step
	for i in 30:
		s.customers.append({"customer_id": "x%d" % i, "phase": "QUEUE", "reservation_id": "", "queue_slot": -1, "tile": Vector2i(1, 1)})
	var runner := _open(s)
	runner.process_frame(1.0 / 3.0)   
	t.eq(s.visit_stats["potential"], 10)
	t.eq(s.visit_stats["lost"], 10, "cap of 30 reached: every wish is lost")
	t.eq(s.visit_stats["entered"], 0)
	t.eq(s.arrival_queue.size(), 0)
	var e := _state()
	e.balance["base_potential_visitors_per_day"] = 1.0e9
	_open(e).process_frame(1.0 / 3.0)
	t.eq(e.visit_stats["entered"], 10, "no products at all still works")
	t.eq(e.next_customer_seq, 10, "ten customers were created and numbered in order")
	t.eq(e.visit_stats["potential"], e.visit_stats["entered"] + e.visit_stats["lost"], "counters add up")


func test_zero_base_demand_never_draws_a_visitor(t, _tree) -> void:
	var s := _state()
	s.balance["base_potential_visitors_per_day"] = 0
	var runner := _open(s, 4)
	for i in 20:
		runner.process_frame(1.0)
	t.eq(s.visit_stats["potential"], 0)
	t.ok(s.rng_states["arrivals"] != Seeds.ARRIVALS, "p = 0 still consumes the draw")


func test_stocked_categories_count_distinct_shelf_categories(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = cmds.execute({"command_id": "a", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	t.eq(DemandGenerator.stocked_category_count(s), 0)
	cmds.execute({"command_id": "b", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 5})
	t.eq(DemandGenerator.stocked_category_count(s), 0, "backroom stock does not count")
	cmds.execute({"command_id": "c", "kind": &"RESTOCK", "instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 2})
	t.eq(DemandGenerator.stocked_category_count(s), 1)
	cmds.execute({"command_id": "d", "kind": &"RESTOCK", "instance_id": shelf, "slot_id": "row1", "sku_id": "rice_001", "qty": 2})
	t.eq(DemandGenerator.stocked_category_count(s), 1, "same category twice is still one")
