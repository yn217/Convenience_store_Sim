extends RefCounted
## Issue #18: advertising tiers, once-a-day charges, opening/closing, day boundary (08 §1, 03 §5).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	_n += 1
	var c := {"command_id": "b%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## A ready-to-open store: shelf + register + stock. Cash 500000 - 45000 - 90000 - 1000 (rice).
func _ready_store() -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 10})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 10})
	return s


func _expense(s: GameState, kind: String, day: int = -1) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == kind and (day < 0 or tx["day_index"] == day):
			n += int(tx["expense_delta_yen"])
	return n


func _rows(s: GameState, kind: String) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == kind:
			n += 1
	return n


func test_tiers_and_multipliers(t, _tree) -> void:
	var s := _state()
	var tiers: Array = s.balance["advertising_tiers"]
	var expect := {0: 1.0, 1000: 1.10, 2000: 1.18, 5000: 1.30, 10000: 1.40}
	for yen in expect:
		t.ok(absf(DemandModel.ad_multiplier(tiers, yen) - expect[yen]) < 1e-9, "tier %d" % yen)
	# gain per yen shrinks tier after tier (diminishing returns)
	var prev := 1.0e9
	var last_yen := 0
	var last_mult := 1.0
	for yen in [1000, 2000, 5000, 10000]:
		var gain := (DemandModel.ad_multiplier(tiers, yen) - last_mult) / float(yen - last_yen)
		t.ok(gain < prev, "marginal gain per yen falls at %d" % yen)
		prev = gain
		last_yen = yen
		last_mult = DemandModel.ad_multiplier(tiers, yen)
	t.eq(s.applied_ad_tier_yen, 0, "no advertising by default")
	t.eq(s.next_day_ad_yen, 0)


func test_set_next_day_ad_validates_and_moves_no_cash(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	for bad in [1, 500, -1000, 3000, 10001, 1.5, "1000", null]:
		t.eq(_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": bad}).message_key, &"ad_tier_invalid", "rejects %s" % str(bad))
	var cash := s.cash_yen
	t.ok(_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 5000}).ok)
	t.eq(s.next_day_ad_yen, 5000)
	t.eq(s.cash_yen, cash, "choosing a tier costs nothing yet")
	t.eq(s.applied_ad_tier_yen, 0, "and does not change today's traffic")
	s.ledger.cash_yen = 999
	var r := _run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 1000})
	t.eq(r.code, &"INSUFFICIENT_CASH", "a tier the cash cannot cover is refused")
	t.eq(s.next_day_ad_yen, 5000, "the earlier choice stays")


func test_start_charges_the_day_exactly_once(t, _tree) -> void:
	var s := _ready_store()
	var cmds := GameCommands.new(s)
	_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 2000})
	var cash := s.cash_yen
	var r := _run(cmds, &"START_BUSINESS")
	t.ok(r.ok)
	t.eq(s.business_state, GameState.OPEN)
	t.eq(s.speed_setting, 1)
	var electricity: int = 15 + 50   # onigiri shelf + register, per the fixture masters
	var shelf_cost: int = s.fixtures.get_type("shelf_onigiri")["electricity_cost_yen_per_day"]
	var reg_cost: int = s.fixtures.get_type("register_basic")["electricity_cost_yen_per_day"]
	electricity = shelf_cost + reg_cost
	t.eq(_expense(s, "AD", 0), 2000)
	t.eq(_expense(s, "DAILY_FIXED", 0), 1000)
	t.eq(_expense(s, "ELECTRICITY", 0), electricity)
	t.eq(s.cash_yen, cash - 2000 - 1000 - electricity)
	t.eq(s.applied_ad_tier_yen, 2000)
	# close, wait for the (empty) store to reach SETUP, open again the same day
	t.ok(_run(cmds, &"REQUEST_CLOSE").ok)
	SimulationRunner.new(s).process_frame(1.0)
	t.eq(s.business_state, GameState.SETUP)
	var after := s.cash_yen
	t.ok(_run(cmds, &"START_BUSINESS").ok)
	t.eq(s.cash_yen, after, "second start the same day charges nothing")
	t.eq(_rows(s, "AD"), 1)
	t.eq(_rows(s, "DAILY_FIXED"), 1)
	t.eq(_rows(s, "ELECTRICITY"), 1)


func test_start_failures_change_nothing(t, _tree) -> void:
	var s := _ready_store()
	var cmds := GameCommands.new(s)
	_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 10000})
	s.ledger.cash_yen = 10500   # fixed 1000 + electricity + ad 10000 > cash
	var before_rev := s.revision
	var before_tx := s.ledger.transactions.size()
	var r := _run(cmds, &"START_BUSINESS")
	t.eq(r.code, &"INSUFFICIENT_CASH")
	t.eq(s.cash_yen, 10500)
	t.eq(s.business_state, GameState.SETUP)
	t.eq(s.ledger.transactions.size(), before_tx)
	t.eq(s.revision, before_rev)
	t.eq(s.unpaid_cost_yen, 0)
	var empty := _state()
	t.eq(_run(GameCommands.new(empty), &"START_BUSINESS").code, &"MISSING_REGISTER")
	var no_stock := _state()
	var c2 := GameCommands.new(no_stock)
	_run(c2, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	_run(c2, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	t.eq(_run(c2, &"START_BUSINESS").code, &"MISSING_STOCK")
	t.eq(no_stock.business_state, GameState.SETUP)


func test_request_close_and_return_to_setup(t, _tree) -> void:
	var s := _ready_store()
	var cmds := GameCommands.new(s)
	t.eq(_run(cmds, &"REQUEST_CLOSE").message_key, &"not_open", "nothing to close in SETUP")
	_run(cmds, &"START_BUSINESS")
	s.speed_setting = 0
	s.last_nonzero_speed = 2
	t.ok(_run(cmds, &"REQUEST_CLOSE").ok)
	t.eq(s.business_state, GameState.CLOSING)
	t.eq(s.speed_setting, 2, "resumes at the last non-zero speed")
	s.customers.append({"customer_id": "c1", "phase": "CHECKOUT", "checkout_left": 100000, "register_id": "x", "reservation_ids": [], "queue_slot": -1, "tile": Vector2i(1, 1)})
	var runner := SimulationRunner.new(s)
	runner.process_frame(1.0)
	t.eq(s.business_state, GameState.CLOSING, "a customer is still inside")
	s.customers.clear()
	runner.process_frame(1.0)
	t.eq(s.business_state, GameState.SETUP)
	t.eq(s.speed_setting, 0)


func test_new_day_charges_once_whatever_the_speed(t, _tree) -> void:
	var results: Array = []
	for speed in [1, 4]:
		var s := _ready_store()
		var cmds := GameCommands.new(s)
		_run(cmds, &"START_BUSINESS")   # day 0: ad 0
		_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 5000})
		s.speed_setting = speed
		s.time_sec = 86400 - 20
		var runner := SimulationRunner.new(s)
		var steps := 0
		while steps < 40:
			steps += runner.process_frame(1.0 / 15.0)
		t.eq(s.day, 1)
		t.eq(s.applied_ad_tier_yen, 5000, "the new budget applies from the new day")
		t.eq(_expense(s, "AD", 1), 5000)
		t.eq(_expense(s, "AD", 0), 0, "today's traffic was not bought retroactively")
		t.eq(_rows(s, "AD"), 2)
		t.eq(_rows(s, "DAILY_FIXED"), 2)
		var rows: Array = []
		for tx in s.ledger.transactions:
			rows.append([tx["event_type"], tx["day_index"], tx["cash_delta_yen"], tx["expense_delta_yen"]])
		results.append([s.cash_yen, rows])
	t.eq(results[0], results[1], "same ledger at 1x and 4x")


func test_cash_shortage_at_midnight_blocks_payment_without_negative_cash(t, _tree) -> void:
	var s := _ready_store()
	var cmds := GameCommands.new(s)
	_run(cmds, &"START_BUSINESS")
	_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 1000})
	s.ledger.cash_yen = 1200   # day 1 needs ad 1000 + fixed 1000 + electricity
	s.time_sec = 86400 - 2
	var runner := SimulationRunner.new(s)
	runner.process_frame(1.0)
	t.eq(s.business_state, GameState.PAYMENT_BLOCKED)
	t.eq(s.cash_yen, 0, "all cash paid out, never negative")
	var due := _expense(s, "AD", 1) + _expense(s, "DAILY_FIXED", 1) + _expense(s, "ELECTRICITY", 1)
	t.eq(due, 1000 + 1000 + 65, "the full cost is recognised")
	t.eq(s.unpaid_cost_yen, due - 1200, "the remainder is tracked as unpaid")
	var unpaid := s.unpaid_cost_yen
	runner.process_frame(5.0)
	t.eq(s.unpaid_cost_yen, unpaid, "blocked: nothing more is charged")
	t.eq(BusinessService.charge_day(s, 1, true), 0, "booking the same day again is a no-op")
	t.eq(s.unpaid_cost_yen, unpaid)


func test_more_advertising_brings_at_least_as_many_visitors_with_fixed_seeds(t, _tree) -> void:
	var counts: Array[int] = []
	for tier in [0, 1000, 2000, 5000, 10000]:
		var s := _ready_store()
		s.business_state = GameState.OPEN
		s.speed_setting = 4
		s.time_sec = 10 * 3600
		s.applied_ad_tier_yen = tier
		s.balance["base_potential_visitors_per_day"] = 2000
		s.balance["max_active_customers"] = 100000
		var runner := SimulationRunner.new(s)
		var steps := 0
		while steps < 10800:   # six game hours
			steps += runner.process_frame(1.0 / 4.0)
		counts.append(int(s.visit_stats["potential"]))
	for i in range(1, counts.size()):
		t.ok(counts[i] >= counts[i - 1], "tier %d did not lose visitors" % i)
	t.ok(counts[4] > counts[0], "the top tier clearly beats no advertising: %s" % str(counts))
