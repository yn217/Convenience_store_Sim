extends RefCounted
## Issue #16: one customer at the till at a time, queue advance, 120 s timeout, no register.

const LegacyPace := preload("res://tests/support/legacy_pace.gd")

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = LegacyPace.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json")))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "q%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _store(qty: int, with_register: bool = true) -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	if with_register:
		_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": qty})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": qty})
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.balance["base_potential_visitors_per_day"] = 0
	# Every decision buys: price factor 2.0 -> p = 0.95 and a seed whose draws pass.
	for seed_value in range(1, 500):
		var r := Lcg32.new(seed_value)
		var a := r.uniform_0_1()
		var b := r.uniform_0_1()
		var r2 := Lcg32.new(r.state)
		var c := r2.uniform_0_1()
		var d := r2.uniform_0_1()
		var r3 := Lcg32.new(r2.state)
		var e := r3.uniform_0_1()
		var f := r3.uniform_0_1()
		if b < 0.8 and d < 0.8 and f < 0.8:
			s.rng_states["purchases"] = seed_value
			break
	return s


func _arrive(s: GameState, n: int = 1) -> void:
	for i in n:
		s.next_customer_seq += 1
		s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})


func _tick(s: GameState, ai: CustomerAI, n: int) -> void:
	for i in n:
		s.time_sec += 2
		ai.step(s)


func _phases(s: GameState) -> Dictionary:
	var out := {}
	for c in s.customers:
		out[c["phase"]] = int(out.get(c["phase"], 0)) + 1
	return out


func _revenue(s: GameState) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		n += int(tx["revenue_delta_yen"])
	return n


func test_one_customer_pays_and_leaves(t, _tree) -> void:
	var s := _store(5)
	var ai := CustomerAI.new()
	_arrive(s)
	_tick(s, ai, 120)
	t.eq(s.customers.size(), 0, "paid and walked out")
	t.eq(s.visit_stats["purchased"], 1)
	t.eq(_revenue(s), 150)
	t.eq(s.reservations.size(), 0)
	var left := 0
	for seg in s.inventory_segments:
		left += seg["physical_qty"]
	t.eq(left, 4, "one unit sold")


func test_only_one_customer_is_served_at_a_time(t, _tree) -> void:
	var s := _store(10)
	var ai := CustomerAI.new()
	_arrive(s, 3)
	var max_at_till := 0
	var served_order: Array[String] = []
	for i in 400:
		_tick(s, ai, 1)
		var at_till := 0
		for c in s.customers:
			if c["phase"] == "CHECKOUT":
				at_till += 1
				if not served_order.has(c["customer_id"]):
					served_order.append(c["customer_id"])
		max_at_till = maxi(max_at_till, at_till)
	t.eq(max_at_till, 1, "never two at the till")
	t.eq(served_order.size(), 3, "all three were served one after another")
	t.eq(s.visit_stats["purchased"], 3)
	t.eq(_revenue(s), 450)


func test_checkout_takes_thirty_game_seconds(t, _tree) -> void:
	# Issue #128: the checkout is 20 s + 8 s per item (was a flat 30 s). One item (basket forced to 1) takes 28 s.
	var s := _store(5)
	s.balance["basket_size_forced"] = 1
	var ai := CustomerAI.new()
	_arrive(s)
	var start := -1
	var done := -1
	for i in 200:
		_tick(s, ai, 1)
		if start < 0 and not s.customers.is_empty() and s.customers[0]["phase"] == "CHECKOUT":
			start = s.time_sec
		if done < 0 and s.visit_stats["purchased"] == 1:
			done = s.time_sec
	t.eq(done - start, 28, "20 + 8 game seconds from till to receipt for one item")


func test_waiting_past_the_timeout_releases_the_reservation(t, _tree) -> void:
	var s := _store(10)
	s.balance["checkout_base_game_seconds"] = 100000   # the first customer blocks the till
	var ai := CustomerAI.new()
	_arrive(s, 2)
	_tick(s, ai, 30)
	t.eq(s.reservations.size(), 2, "both hold a reservation while waiting")
	var timeout_outcomes := 0
	var counted := {}
	for i in 90:
		_tick(s, ai, 1)
		for c in s.customers:
			if c["outcome"] == "queue_timeout" and not counted.has(c["customer_id"]):
				counted[c["customer_id"]] = true
				timeout_outcomes += 1
				t.ok(s.time_sec >= 120, "not before 120 s")
				t.eq(s.reservations.size(), 1, "released at the moment of giving up")
	t.eq(timeout_outcomes, 1, "the waiting customer gave up")
	var reserved := 0
	for seg in s.inventory_segments:
		reserved += seg["reserved_qty"]
	t.eq(reserved, 1, "only the customer at the till keeps a unit")
	t.eq(_revenue(s), 0)


func test_zero_registers_means_customers_leave_without_buying(t, _tree) -> void:
	var s := _store(5, false)
	var ai := CustomerAI.new()
	_arrive(s, 2)
	_tick(s, ai, 120)
	t.eq(s.customers.size(), 0)
	t.eq(s.visit_stats["purchased"], 0)
	t.eq(s.reservations.size(), 0)
	t.eq(_revenue(s), 0)


func test_queue_advances_and_full_queue_waits(t, _tree) -> void:
	var s := _store(12)
	var ai := CustomerAI.new()
	_arrive(s, 14)
	var most_waiting := 0
	for i in 60:
		_tick(s, ai, 1)
		var ph := _phases(s)
		most_waiting = maxi(most_waiting, int(ph.get("WAIT_QUEUE", 0)))
		var in_line := s.customers.filter(func(c): return int(c["queue_slot"]) >= 0 or c["phase"] == "CHECKOUT").size()   # slot holders (a walker on its way to the line holds none, #117 v2)
		t.ok(in_line <= 3, "at most 3 queue slots are in use")
	t.ok(most_waiting >= 1, "with 14 customers and 3 slots somebody had to wait for a slot")


func test_stop_and_resume_do_not_change_the_checkout_clock(t, _tree) -> void:
	var s := _store(5)
	var runner := SimulationRunner.new(s)
	_arrive(s)
	for i in 60:
		runner.process_frame(1.0 / 30.0)
	var phase_before: String = s.customers[0]["phase"] if not s.customers.is_empty() else ""
	var time_before := s.time_sec
	s.speed_setting = 0
	for i in 100:
		runner.process_frame(1.0)
	t.eq(s.time_sec, time_before, "paused: no steps")
	t.eq(s.customers[0]["phase"] if not s.customers.is_empty() else "", phase_before)
	s.speed_setting = 1
	for i in 600:
		runner.process_frame(1.0 / 30.0)
	t.eq(s.visit_stats["purchased"], 1, "resumes and completes the sale once")


func test_two_registers_are_addressed_by_id(t, _tree) -> void:
	var s := _store(5)
	var ai := CustomerAI.new()
	var plan := ai._register_plan(s)
	t.ok(plan.has("register_id"), "plan names its register so more registers can be added")
	t.eq(plan["slots"], 3)
	t.eq(plan["queue_cells"][0], plan["service_cell"])
