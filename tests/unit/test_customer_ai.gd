extends RefCounted
## Issue #15: customer walks, shelf choice, reservation, register queue, leaving (03 §D, 09 §3).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "a%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## Shelf at (4,5), register at (8,5), `qty` rice balls on the shelf; the store is OPEN with no
## arrivals generated (the tests queue their own customers).
func _store(qty: int = 5) -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	if qty > 0:
		_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": qty})
		_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": qty})
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.balance["base_potential_visitors_per_day"] = 0
	return s


## A purchases seed whose buy decision (2nd draw) succeeds at the 0.80 base probability.
func _buying_seed() -> int:
	for seed_value in range(1, 200):
		var r := Lcg32.new(seed_value)
		r.next_state()
		if r.uniform_0_1() < 0.7:
			return seed_value
	return 1


func _declining_seed() -> int:
	for seed_value in range(1, 200):
		var r := Lcg32.new(seed_value)
		r.next_state()
		if r.uniform_0_1() >= 0.9:
			return seed_value
	return 1


func _arrive(s: GameState) -> void:
	s.next_customer_seq += 1
	s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})


func _steps(s: GameState, ai: CustomerAI, n: int, tiles: Array = []) -> void:
	for i in n:
		s.time_sec += 2
		ai.step(s)
		if not s.customers.is_empty():
			tiles.append(s.customers[0]["tile"])


func _reserved(s: GameState) -> int:
	var n := 0
	for seg in s.inventory_segments:
		n += int(seg["reserved_qty"])
	return n


func _physical(s: GameState) -> int:
	var n := 0
	for seg in s.inventory_segments:
		n += int(seg["physical_qty"])
	return n


func test_customer_walks_entrance_to_shelf_to_register(t, _tree) -> void:
	var s := _store()
	s.rng_states["purchases"] = _buying_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	var tiles: Array = []
	_steps(s, ai, 80, tiles)
	var c: Dictionary = s.customers[0]
	t.eq(c["phase"], "QUEUE", "ends waiting in the register queue")
	t.ok(tiles.has(Vector2i(5, 5)) or tiles.has(Vector2i(5, 6)), "stood on the shelf's access tile")
	t.eq(c["queue_slot"], 0)
	t.eq(_reserved(s), 1, "one unit reserved")
	t.eq(_physical(s), 5, "stock is not reduced before checkout")
	t.eq(s.reservations.size(), 1)
	var res: Dictionary = s.reservations[0]
	t.eq(res["sell_unit_yen_snapshot"], 150)
	t.eq(res["cost_unit_yen_snapshot"], 100)
	t.eq(res["customer_id"], "cust_00001")
	# every step moved at most one tile (0.6 tiles/s * 2 s = 1.2 tiles per step, carried over)
	for i in range(1, tiles.size()):
		t.ok((tiles[i] - tiles[i - 1]).abs().x + (tiles[i] - tiles[i - 1]).abs().y <= 2, "no teleporting")
	t.eq(s.snapshot()["customers"][0]["phase"], "QUEUE")


func test_walk_speed_is_point_six_tiles_per_second(t, _tree) -> void:
	var s := _store()
	s.rng_states["purchases"] = _buying_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	var tiles: Array = []
	_steps(s, ai, 10, tiles)
	# 10 steps = 20 s = 12 tiles budget, minus the SELECT step: the walker passed x = 5 by then.
	t.ok(s.customers[0]["tile"].x >= 4, "covered several tiles")
	t.ok(s.customers[0]["tile"].x <= 6, "but not more than the speed allows")


func test_buy_decision_can_decline_and_the_customer_leaves_without_a_reservation(t, _tree) -> void:
	var s := _store()
	s.rng_states["purchases"] = _declining_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	_steps(s, ai, 20)
	t.eq(s.customers.size(), 0, "walked back out through the entrance and was removed")
	t.eq(_reserved(s), 0)
	t.eq(s.reservations.size(), 0)
	t.eq(_physical(s), 5)


func test_no_stock_means_no_candidate_and_one_rng_draw(t, _tree) -> void:
	var s := _store(0)
	var ai := CustomerAI.new()
	_arrive(s)
	_steps(s, ai, 1)
	var ref := Lcg32.new(Seeds.PURCHASES)
	ref.next_state()
	t.eq(s.rng_states["purchases"], ref.state, "exactly one draw")
	t.eq(s.customers[0]["phase"], "EXIT")
	t.eq(s.customers[0]["outcome"], "no_candidate")
	_steps(s, ai, 20)
	t.eq(s.customers.size(), 0)


func test_unreachable_shelf_is_not_a_candidate(t, _tree) -> void:
	var s := _store()
	# Wall in the shelf's access tiles (5,5) and (5,6) with other fixtures.
	for spec in [["blk1", 5, 4], ["blk2", 5, 6]]:
		s.grid.add_instance({"instance_id": spec[0], "type_id": "warmer_oden", "x": spec[1], "y": spec[2], "rotation": 0, "enabled": true}, s.fixtures)
	s.grid.add_instance({"instance_id": "blk3", "type_id": "warmer_oden", "x": 5, "y": 5, "rotation": 0, "enabled": true}, s.fixtures)
	var ai := CustomerAI.new()
	t.eq(ai.candidates(s).size(), 0, "no reachable access -> no candidate")
	_arrive(s)
	_steps(s, ai, 1)
	t.eq(s.customers[0]["outcome"], "no_candidate")


func test_two_customers_one_unit_only_one_reserves(t, _tree) -> void:
	var s := _store(1)
	s.rng_states["purchases"] = _buying_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	_arrive(s)
	_steps(s, ai, 60)
	t.eq(s.reservations.size(), 1, "the single unit is reserved once")
	t.eq(_reserved(s), 1)
	t.eq(_physical(s), 1)
	var in_queue := 0
	for c in s.customers:
		if c["phase"] == "QUEUE":
			in_queue += 1
	t.eq(in_queue, 1)


func test_two_customers_take_different_queue_slots(t, _tree) -> void:
	var s := _store(5)
	s.rng_states["purchases"] = _buying_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	_arrive(s)
	_steps(s, ai, 120)
	var slots := {}
	for c in s.customers:
		if c["phase"] == "QUEUE":
			slots[c["customer_id"]] = c["queue_slot"]
	t.eq(slots.size(), 2, "both reached the queue (if both chose to buy)")
	if slots.size() == 2:
		t.ok(slots["cust_00001"] != slots["cust_00002"], "different queue slots")
		t.eq(slots.values().duplicate().map(func(x): return int(x)).reduce(func(a, b): return a + b), 1, "slots 0 and 1 are used")
	t.eq(_reserved(s), 2)


func test_timed_out_reservation_makes_the_customer_leave_and_stock_stays(t, _tree) -> void:
	var s := _store()
	s.rng_states["purchases"] = _buying_seed()
	var ai := CustomerAI.new()
	_arrive(s)
	_steps(s, ai, 80)
	t.eq(s.customers[0]["phase"], "QUEUE")
	s.time_sec += CustomerAI.RESERVATION_HOLD_SEC
	t.eq(InventoryService.release_timed_out(s), 1)
	t.eq(_reserved(s), 0, "units available again")
	_steps(s, ai, 1)
	t.eq(s.customers[0]["phase"], "EXIT")
	t.eq(s.customers[0]["outcome"], "reservation_lost")
	_steps(s, ai, 40)
	t.eq(s.customers.size(), 0)
	t.eq(_physical(s), 5, "a customer who leaves never reduces stock")


func test_same_seeds_same_walks(t, _tree) -> void:
	var histories: Array = []
	for k in 2:
		var s := _store()
		var ai := CustomerAI.new()
		_arrive(s)
		_arrive(s)
		var tiles: Array = []
		for i in 100:
			s.time_sec += 2
			ai.step(s)
			for c in s.customers:
				tiles.append([c["customer_id"], c["tile"], c["phase"]])
		histories.append([tiles, s.rng_states.duplicate(), s.reservations.duplicate(true)])
	t.eq(histories[0], histories[1])


func test_price_factor_lowers_the_chance_to_buy(t, _tree) -> void:
	# 150 -> 500 yen: factor = 0.3 (clamped), p = 0.24. The same second draw that bought at 150 declines.
	var seed_value := 1
	for v in range(1, 400):
		var r := Lcg32.new(v)
		r.next_state()
		var u := r.uniform_0_1()
		if u > 0.3 and u < 0.7:
			seed_value = v
			break
	var cheap := _store()
	cheap.rng_states["purchases"] = seed_value
	var dear := _store()
	dear.rng_states["purchases"] = seed_value
	dear.product_price_overrides["rice_001"] = 500
	var ai1 := CustomerAI.new()
	var ai2 := CustomerAI.new()
	_arrive(cheap)
	_arrive(dear)
	_steps(cheap, ai1, 1)
	_steps(dear, ai2, 1)
	t.eq(cheap.customers[0]["phase"], "WALK_SHELF", "buys at the reference price")
	t.eq(dear.customers[0]["outcome"], "declined", "declines at a high price")
