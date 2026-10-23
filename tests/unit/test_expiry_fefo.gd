extends RefCounted
## Issue #13: expiry sweep, FEFO sale, wastage booked once (03 §C/§E, 10 §H.3-4, §D.6, 09 §8.8).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "e%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## rice_001: cost 100, sell 150, shelf life 86400 s. Returns the shelf id.
func _stocked(s: GameState, cmds: GameCommands, ordered: int, on_shelf: int) -> String:
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": ordered})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": on_shelf})
	return shelf


func _sum(s: GameState, key: String) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		n += int(tx[key])
	return n


func _wastage(s: GameState) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "WASTAGE":
			n += int(tx["expense_delta_yen"])
	return n


func test_sell_three_then_two_expire_matches_the_golden_vector(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_stocked(s, cmds, 10, 5)
	var cash := s.cash_yen
	for i in 3:
		var res := InventoryService.reserve(s, "r%d" % i, "c%d" % i, "rice_001", 60)
		t.ok(not res.is_empty(), "reserve %d" % i)
		t.ok(InventoryService.complete_sale(s, "tx%d" % i, "r%d" % i)["ok"])
	t.eq(_sum(s, "revenue_delta_yen"), 450)
	t.eq(_sum(s, "cogs_delta_yen"), 300)
	t.eq(s.cash_yen, cash + 450)
	t.eq(s.snapshot()["shelf_stock"].values()[0]["row0"], 2, "2 left on the shelf")
	var cash_before_expiry := s.cash_yen
	s.time_sec = 86400
	var booked := InventoryService.sweep_expired(s)
	t.eq(booked.size(), 2, "shelf remainder + backroom remainder are separate segments")
	t.eq(_wastage(s), 700, "2 shelf + 5 backroom units at 100 yen")
	t.eq(s.cash_yen, cash_before_expiry, "wastage does not move cash")
	t.eq(_sum(s, "cogs_delta_yen"), 300, "wastage is not COGS")
	t.eq(s.inventory_segments.size(), 0)
	t.eq(InventoryService.sweep_expired(s).size(), 0, "second sweep books nothing")
	t.eq(_wastage(s), 700, "booked once")


func test_only_the_expired_lot_is_discarded(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 3})
	s.time_sec = 1000
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 4})
	s.time_sec = 86400
	InventoryService.sweep_expired(s)
	t.eq(s.inventory_segments.size(), 1, "second lot survives")
	t.eq(s.inventory_segments[0]["physical_qty"], 4)
	t.eq(_wastage(s), 300)


func test_fefo_sells_the_earliest_expiry_first_and_partial_sales_work(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _stocked(s, cmds, 2, 2)
	s.time_sec = 100
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 3})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 3})
	# Shelf: lot_0001 x2 (expires 86400), lot_0002 x3 (expires 86500). The first lot sells first.
	var lots: Array[String] = []
	for i in 4:
		var res := InventoryService.reserve(s, "r%d" % i, "c", "rice_001", 60)
		lots.append(_segment(s, res["segment_id"])["lot_id"])
		t.ok(InventoryService.complete_sale(s, "tx%d" % i, "r%d" % i)["ok"])
	t.eq(lots, ["lot_0001", "lot_0001", "lot_0002", "lot_0002"], "earliest lot first, then the next")
	t.eq(_segment_qty(s, "lot_0002", true), 1, "partial sale leaves one on the shelf")
	t.eq(_sum(s, "revenue_delta_yen"), 600)
	t.eq(_sum(s, "cogs_delta_yen"), 400)


func _segment(s: GameState, id: String) -> Dictionary:
	for seg in s.inventory_segments:
		if seg["segment_id"] == id:
			return seg
	return {}


func _segment_qty(s: GameState, lot: String, on_shelf: bool) -> int:
	var n := 0
	for seg in s.inventory_segments:
		if seg["lot_id"] == lot and (seg["location"]["kind"] == "FIXTURE") == on_shelf:
			n += seg["physical_qty"]
	return n


func test_expired_stock_cannot_be_reserved_and_no_expiry_never_expires(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_stocked(s, cmds, 4, 4)
	s.time_sec = 86399
	t.ok(not InventoryService.reserve(s, "ok", "c", "rice_001", 60).is_empty(), "one second before expiry")
	s.time_sec = 86400
	t.ok(InventoryService.reserve(s, "late", "c", "rice_001", 60).is_empty(), "at the expiry second nothing is reservable")
	var s2 := _state()
	var c2 := GameCommands.new(s2)
	_stocked(s2, c2, 2, 2)
	s2.inventory_segments[0]["expires_at_sec"] = null
	s2.time_sec = 10 * 86400
	t.eq(InventoryService.sweep_expired(s2).size(), 0, "no expiry, no wastage")
	t.ok(not InventoryService.reserve(s2, "r", "c", "rice_001", 60).is_empty(), "still sellable")


func test_checkout_in_the_expiry_step_sells_nothing_and_wastes_once(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_stocked(s, cmds, 3, 3)
	var res := InventoryService.reserve(s, "r1", "c1", "rice_001", 10000)
	t.ok(not res.is_empty())
	s.time_sec = 86400
	var out := InventoryService.complete_sale(s, "tx", "r1")
	t.ok(not out["ok"], "expired stock is not sold")
	t.eq(_sum(s, "revenue_delta_yen"), 0)
	InventoryService.sweep_expired(s)
	t.eq(s.reservations.size(), 0, "reservation released before discarding")
	t.eq(_wastage(s), 300, "all 3 shelf units, once")
	t.eq(InventoryService.complete_sale(s, "tx", "r1")["reason"], "unknown_reservation")
	InventoryService.sweep_expired(s)
	t.eq(_wastage(s), 300)


func test_duplicate_transaction_and_double_reservation(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_stocked(s, cmds, 1, 1)
	t.ok(not InventoryService.reserve(s, "a", "c1", "rice_001", 60).is_empty())
	t.ok(InventoryService.reserve(s, "b", "c2", "rice_001", 60).is_empty(), "the only unit is taken")
	t.ok(InventoryService.complete_sale(s, "tx", "a")["ok"])
	t.eq(InventoryService.complete_sale(s, "tx", "a")["reason"], "duplicate_transaction")
	t.eq(_sum(s, "revenue_delta_yen"), 150)


func test_same_expiry_lots_are_all_wasted_in_one_sweep(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 2})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 3})
	s.time_sec = 86400
	var booked := InventoryService.sweep_expired(s)
	t.eq(booked, ["wastage:seg_0001", "wastage:seg_0002"] as Array[String], "deterministic order")
	t.eq(_wastage(s), 500)


func test_runner_sweeps_when_time_passes_the_expiry(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_stocked(s, cmds, 2, 1)
	s.business_state = GameState.OPEN
	s.speed_setting = 4
	s.time_sec = 86400 - 2
	var runner := SimulationRunner.new(s)
	var steps := runner.process_frame(0.1)
	t.ok(steps > 0)
	t.eq(_wastage(s), 200, "expired during the step, booked by the tick")
	t.eq(s.inventory_segments.size(), 0)
