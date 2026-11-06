extends RefCounted
## Issue #117 v2: the simulation itself walks at the shown pace (no presentation lag). Customers walk
## customer_walk_tiles_per_game_second, look over a shelf before taking an item, join the line in the order they
## reach it, and the drawn figure stays within a few tenths of a tile of the simulation (so a click while paused
## shows where the customer really is).

const Paths := preload("res://tests/scenario/test_customer_paths.gd")
const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const FRAME := 1.0 / 60.0


## FakeWorld with the simulation's walking speed, as StoreWorld gets it from the snapshot.
class PaceWorld extends "res://tests/scenario/test_customer_paths.gd".FakeWorld:
	var walk_tiles_per_game_second := 0.0


func _balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))


func test_the_balance_sets_a_calm_exact_pace(t, _tree) -> void:
	var b := _balance()
	var walk := float(b["customer_walk_tiles_per_game_second"])
	t.eq(walk * GameClock.GAME_SECONDS_PER_REAL_SECOND, 1.40625, "about 1.4 tiles per real second at x1")
	var per_step := walk * GameClock.STEP_GAME_SECONDS
	t.eq(per_step * 64.0, 3.0, "a step is 3/64 tile: exact in binary, so saves round-trip the progress")
	t.ok(int(b["reservation_hold_game_seconds"]) >= 1800, "a reservation outlasts a slow visit")
	t.ok(int(b["queue_patience_game_seconds"]) >= 300, "patience covers a few checkouts")


func test_browse_time_is_fixed_per_customer_and_shelf(t, _tree) -> void:
	var b := _balance()
	var seen := {}
	for i in 40:
		var sec := CustomerAI.browse_seconds(b, "cust_%05d" % i, "fx_0003")
		t.ok(sec >= int(b["browse_min_game_seconds"]) and sec <= int(b["browse_max_game_seconds"]), "within the balance range: %d" % sec)
		t.eq(sec, CustomerAI.browse_seconds(b, "cust_%05d" % i, "fx_0003"), "the same customer and shelf give the same time")
		seen[sec] = true
	t.ok(seen.size() > 5, "customers differ")
	t.eq(CustomerAI.browse_seconds({}, "a", "b"), 0, "no browse keys = no browsing (old tests)")


## One customer on the lab layout: it browses at the shelf (no reservation yet), then reserves, and the whole visit
## takes minutes, not seconds.
func test_a_customer_browses_before_taking_an_item(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var runner := SimulationRunner.new(s)
	s.next_customer_seq += 1
	s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
	var browse_steps := 0
	var reserved_at := -1
	var gone_at := -1
	var entered_at := s.time_sec
	for i in 3000:
		runner._run_step()
		if s.customers.is_empty():
			gone_at = s.time_sec
			break
		var c: Dictionary = s.customers[0]
		if int(c.get("browse_left", -1)) > 0:
			browse_steps += 1
			t.ok((c["reservation_ids"] as Array).is_empty() or reserved_at >= 0, "nothing new is reserved while browsing")
		if reserved_at < 0 and not (c["reservation_ids"] as Array).is_empty():
			reserved_at = s.time_sec
	t.ok(browse_steps * int(GameClock.STEP_GAME_SECONDS) >= int(s.balance["browse_min_game_seconds"]) - 2, "browsed at least the minimum: %d steps" % browse_steps)
	t.ok(reserved_at > 0, "then took the item")
	t.ok(gone_at - entered_at >= 600, "a visit lasts minutes of game time: %d s" % (gone_at - entered_at))
	t.eq(int(s.visit_stats["purchased"]), 1, "and paid")


## A customer far from the register walks to the line without a slot and takes one on arrival: the line is in the
## order people reach it, and a far walker never blocks those already standing.
func test_far_customers_take_a_slot_only_at_the_line(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var runner := SimulationRunner.new(s)
	for i in 6:
		s.next_customer_seq += 1
		s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
		for k in 30:
			runner._run_step()
	var ai: CustomerAI = runner._customers
	var tail_cells: Array = ai._register_plan(s)["queue_cells"]
	var tail: Vector2i = tail_cells[tail_cells.size() - 1]
	var walkers := 0
	for i in 2500:
		runner._run_step()
		for c in s.customers:
			if c["phase"] == "WALK_REGISTER" and int(c["queue_slot"]) < 0:
				walkers += 1
			if c["phase"] == "WALK_REGISTER" and int(c["queue_slot"]) >= 0:
				var d := absi(c["tile"].x - tail.x) + absi(c["tile"].y - tail.y)
				t.ok(d <= CustomerAI.JOIN_RADIUS + 1, "a slot is only taken near the line (%s, %d tiles away)" % [c["customer_id"], d])
	t.ok(walkers > 0, "customers walked to the line without a slot")
	t.eq(int(s.rate_stats["abandoned"]), 0, "nobody gave up behind an absent slot holder")
	t.ok(int(s.visit_stats["purchased"]) >= 4, "most of them paid: %d" % int(s.visit_stats["purchased"]))


## The figure follows the simulation closely at every speed, and stands still while paused.
func test_the_figure_stays_with_the_simulation(t, _tree) -> void:
	for speed in [1, 2, 4]:
		var p = Paths.new()
		var s: GameState = p._store(t, speed)
		s.speed_setting = speed
		var runner := SimulationRunner.new(s)
		var clock := GameClock.new()
		var pres: Presenter = Presenter.new()
		var world := PaceWorld.new()
		world.walk_tiles_per_game_second = float(s.balance["customer_walk_tiles_per_game_second"])
		world.speed_setting = speed
		world.fixtures = s.grid.to_save()["fixture_instances"]
		world.fixture_catalog = s.fixtures
		world.product_catalog = s.products
		pres._world = world
		var worst := 0.0
		var worst_in_line := 0.0
		var step_no := 0
		for frame in 3600 / speed:
			var steps := clock.advance(FRAME, speed)
			for i in steps:
				step_no += 1
				if step_no % 40 == 0:
					s.next_customer_seq += 1
					s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
				runner._run_step()
			world.customers = s._customer_views()
			pres._sync_customers(FRAME * speed)
			for c in world.customers:
				if pres._pos.has(c["customer_id"]):
					var lag := (pres._pos[c["customer_id"]] as Vector2).distance_to(Presenter.target_pos(c))
					if c["phase"] in ["WALK_REGISTER", "QUEUE", "CHECKOUT"]:   # stepping up in the line, faster than the walking pace
						worst_in_line = maxf(worst_in_line, lag)
					else:
						worst = maxf(worst, lag)
		t.ok(worst < 0.5, "x%d: the figure trails the simulation by at most %.2f tiles" % [speed, worst])
		t.ok(worst_in_line < 1.0, "x%d: and by %.2f tiles while stepping up in the line" % [speed, worst_in_line])
		# paused: no game time passes, nothing moves
		var before := pres._pos.duplicate()
		world.speed_setting = 0
		for i in 120:
			pres._sync_customers(0.0)
		t.eq(pres._pos, before, "x%d: paused, every figure stands where it was" % speed)
		world.free()
