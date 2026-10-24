extends RefCounted
## Issue #117: the motion presentation is read-only. The same fixed-seed run of the real simulation, once with the
## presenter driven every frame at x1, x2 and x4 (pace, facing, idle selection, ghosts) and once with no presenter,
## must end with identical cash, ledger, purchases, customers and RNG states.

const Paths := preload("res://tests/scenario/test_customer_paths.gd")
const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const FRAME := 1.0 / 60.0
const RUN_UNTIL_SEC := 1800
const ARRIVE_EVERY_STEPS := 4


func _run(t, speed: int, presentation: bool) -> Dictionary:
	var helper = Paths.new()
	var s: GameState = helper._store(t, speed)
	var runner := SimulationRunner.new(s)
	var clock := GameClock.new()
	var fake = Paths.FakeWorld.new()
	var pres: Presenter = Presenter.new()
	fake.speed_setting = speed
	fake.fixtures = s.grid.to_save()["fixture_instances"]
	fake.fixture_catalog = s.fixtures
	fake.product_catalog = s.products
	pres._world = fake
	var step_no := 0
	var frames := 0
	var max_on_screen := 0
	while s.time_sec < RUN_UNTIL_SEC and frames < 200000:
		frames += 1
		for i in clock.advance(FRAME, speed):
			step_no += 1
			if step_no % ARRIVE_EVERY_STEPS == 0:
				s.next_customer_seq += 1
				s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
			runner._run_step()
			s.take_events()
		if presentation:
			fake.customers = s._customer_views()
			pres._sync_customers(FRAME * speed)
			pres.anim_time += FRAME * speed
			for c in s.customers:
				pres.customer_view(c)
			var ordered: Array = pres.compose()
			max_on_screen = maxi(max_on_screen, ordered.size())
	var customers: Array = []
	for c in s.customers:
		customers.append([c["customer_id"], c["tile"], c["phase"], c.get("fixture_id", ""), c.get("register_id", "")])
	return {
		"cash": s.ledger.cash_yen,
		"ledger": s.ledger.transactions.size(),
		"purchased": int(s.visit_stats.get("purchased", 0)),
		"rng": s.rng_states.duplicate(true),
		"customers": customers,
		"time": s.time_sec,
		"on_screen_max": max_on_screen,
	}


func test_presentation_leaves_the_simulation_unchanged(t, _tree) -> void:
	for speed in [1, 2, 4]:
		var off := _run(t, speed, false)
		var on := _run(t, speed, true)
		t.ok(int(off["purchased"]) > 0, "x%d: the run sells something (purchased %d)" % [speed, int(off["purchased"])])
		t.eq(on["cash"], off["cash"], "x%d: cash identical with the presentation on" % speed)
		t.eq(on["ledger"], off["ledger"], "x%d: ledger rows identical" % speed)
		t.eq(on["purchased"], off["purchased"], "x%d: purchases identical" % speed)
		t.eq(on["rng"], off["rng"], "x%d: RNG states identical" % speed)
		t.eq(on["customers"], off["customers"], "x%d: customers (id, tile, phase, fixture, register) identical" % speed)
		t.eq(on["time"], off["time"], "x%d: game time identical" % speed)
		t.ok(int(on["on_screen_max"]) > 0, "x%d: the presenter drew customers" % speed)
