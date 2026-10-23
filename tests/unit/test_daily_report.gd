extends RefCounted
## Issue #19: golden daily report from known transactions and costs (ledger is the only source).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	_n += 1
	var c := {"command_id": "d%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## Day 0 played by hand: open with a 1,000 yen ad, sell 3 of 10 rice balls (cost 100, price 150).
func _day_zero() -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 10})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 10})
	_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 1000})
	_run(cmds, &"START_BUSINESS")
	for i in 3:
		InventoryService.reserve(s, "r%d" % i, "c%d" % i, "rice_001", 600)
		InventoryService.complete_sale(s, "tx%d" % i, "r%d" % i)
	s.visit_stats = {"potential": 5, "entered": 4, "lost": 1, "purchased": 3}
	return s


func _cross_midnight(s: GameState) -> void:
	s.balance["base_potential_visitors_per_day"] = 0
	s.speed_setting = 1
	s.time_sec = 86400 - 2
	SimulationRunner.new(s).process_frame(1.0 / 30.0)


func test_golden_day_report(t, _tree) -> void:
	var s := _day_zero()
	var electricity: int = s.fixtures.get_type("shelf_onigiri")["electricity_cost_yen_per_day"] + s.fixtures.get_type("register_basic")["electricity_cost_yen_per_day"]
	_cross_midnight(s)
	t.eq(s.daily_reports.size(), 1)
	var r: Dictionary = s.daily_reports[0]
	t.eq(DailyReport.errors(r), [] as Array[String], "schema-shaped")
	t.eq(r["day_index"], 0)
	t.eq(r["revenue_yen"], 450)
	t.eq(r["cogs_yen"], 300)
	t.eq(r["gross_profit_yen"], 150)
	t.eq(r["wastage_yen"], 700, "the 7 unsold rice balls expire at midnight (100 yen each)")
	t.eq(r["advertising_yen"], 1000)
	t.eq(r["fixed_cost_yen"], 1000)
	t.eq(r["electricity_yen"], electricity)
	t.eq(r["operating_profit_yen"], 150 - 700 - 1000 - 1000 - electricity)
	# cash moved by fixtures and the order too, which accounting profit does not include
	var expected_cash_delta: int = -45000 - 90000 - 1000 - 1000 - 1000 - electricity + 450
	t.eq(r["net_cash_delta_yen"], expected_cash_delta)
	t.eq(r["cash_end_yen"], 500000 + expected_cash_delta, "cash balance at close, before day 1's costs")
	t.eq([r["potential_customers"], r["visitors"], r["purchasing_customers"], r["lost_customers"]], [5, 4, 3, 1])
	t.eq(r["units_sold"], 3)
	t.eq(r["store_reputation"], 50)
	t.ok(absf(DailyReport.gross_margin_percent(r) - 100.0 * 150.0 / 450.0) < 1e-9)
	t.eq(s.visit_stats, {"potential": 0, "entered": 0, "lost": 0, "purchased": 0}, "counters restart for the new day")
	t.eq(s.day, 1)


func test_zero_sales_day_has_no_division_by_zero(t, _tree) -> void:
	var s := _day_zero()
	_cross_midnight(s)
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.time_sec = 2 * 86400 - 2
	SimulationRunner.new(s).process_frame(1.0 / 30.0)
	t.eq(s.daily_reports.size(), 2)
	var d1: Dictionary = s.daily_reports[1]
	t.eq(d1["revenue_yen"], 0)
	t.eq(d1["units_sold"], 0)
	t.ok(DailyReport.gross_margin_percent(d1) == null, "no revenue -> no margin figure (shown as a dash)")
	t.eq(DailyReport.errors(d1), [] as Array[String])
	t.eq(d1["advertising_yen"], 1000, "day 1 carries the budget chosen on day 0")
	t.eq(d1["gross_profit_yen"], 0)
	t.ok(d1["operating_profit_yen"] < 0, "fixed costs still make a loss")


func test_closing_a_day_does_not_touch_history_and_is_once_only(t, _tree) -> void:
	var s := _day_zero()
	_cross_midnight(s)
	var first: Dictionary = s.daily_reports[0].duplicate(true)
	t.ok(not s.close_day_once(0), "day 0 is already closed")
	t.eq(s.daily_reports.size(), 1)
	for d in range(1, 9):
		t.ok(s.close_day_once(d))
	t.eq(s.daily_reports.size(), 9, "9 days of history kept (7 or more are needed)")
	t.eq(s.daily_reports[0], first, "earlier days are never rewritten")
	t.eq(s.snapshot()["daily_reports"].size(), 9)


func test_day_over_day_and_idle_closing(t, _tree) -> void:
	var s := _day_zero()
	_cross_midnight(s)
	t.ok(DailyReport.day_over_day(s.daily_reports, "revenue_yen") == null, "one day: nothing to compare with")
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.time_sec = 2 * 86400 - 2
	SimulationRunner.new(s).process_frame(1.0 / 30.0)
	t.eq(DailyReport.day_over_day(s.daily_reports, "revenue_yen"), -450)
	# SETUP never closes a day: the clock is stopped.
	var idle := _state()
	idle.time_sec = 86400 - 2
	t.eq(SimulationRunner.new(idle).process_frame(10.0), 0)
	t.eq(idle.daily_reports.size(), 0)


func test_report_validation_rejects_bad_records(t, _tree) -> void:
	var s := _day_zero()
	_cross_midnight(s)
	var bad: Dictionary = s.daily_reports[0].duplicate()
	bad.erase("revenue_yen")
	t.ok(not DailyReport.errors(bad).is_empty())
	bad = s.daily_reports[0].duplicate()
	bad["units_sold"] = -1
	t.ok(not DailyReport.errors(bad).is_empty())
	bad = s.daily_reports[0].duplicate()
	bad["store_reputation"] = 101
	t.ok(not DailyReport.errors(bad).is_empty())
	bad = s.daily_reports[0].duplicate()
	bad["cogs_yen"] = 1.5
	t.ok(not DailyReport.errors(bad).is_empty())
