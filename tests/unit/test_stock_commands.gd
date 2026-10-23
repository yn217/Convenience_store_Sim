extends RefCounted
## Issue #11: ORDER_STOCK / RESTOCK with fixed values (03 §C, 08 §2).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "s%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _order(cmds: GameCommands, sku: Variant, qty: Variant) -> CommandResult:
	return _run(cmds, &"ORDER_STOCK", {"sku_id": sku, "qty": qty})


func _restock(cmds: GameCommands, id: String, slot: String, sku: String, qty: Variant) -> CommandResult:
	return _run(cmds, &"RESTOCK", {"instance_id": id, "slot_id": slot, "sku_id": sku, "qty": qty})


func _shelf(s: GameState, cmds: GameCommands, type_id: String) -> String:
	var r := _run(cmds, &"PLACE_FIXTURE", {"type_id": type_id, "x": 4, "y": 5, "rotation": 0})
	return r.data["instance_id"]


func _total(s: GameState, sku: String) -> int:
	var n := 0
	for seg in s.inventory_segments:
		if seg["sku_id"] == sku:
			n += seg["physical_qty"]
	return n


func test_order_debits_cash_and_fills_backroom(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var r := _order(cmds, "rice_001", 20)
	t.ok(r.ok)
	t.eq(r.data["cost_yen"], 2000)
	t.eq(s.cash_yen, 498000)
	t.eq(s.inventory_segments.size(), 1)
	var seg := s.inventory_segments[0]
	t.eq(seg["physical_qty"], 20)
	t.eq(seg["unit_cost_yen"], 100)
	t.eq(seg["expires_at_sec"], 86400)
	t.eq(seg["location"], {"kind": "BACKROOM"})
	t.eq(s.snapshot()["backroom_stock"], {"rice_001": 20})
	t.ok(r.event_ids[0].ends_with("STOCK_PURCHASED"))
	t.eq(StockSegment.segment_errors(seg, s.products, s.fixtures, s.grid, "seg"), [] as Array[String], "segment is schema-valid")


func test_order_rejections_change_nothing(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	for bad in [0, -1, 10000, 1.5, "5", null]:
		t.eq(_order(cmds, "rice_001", bad).message_key, &"qty_invalid", "qty %s" % str(bad))
	t.eq(_order(cmds, "nope", 1).message_key, &"sku_unknown")
	s.ledger.cash_yen = 99
	var r := _order(cmds, "rice_001", 1)
	t.eq(r.code, &"INSUFFICIENT_CASH")
	t.eq(s.cash_yen, 99)
	t.eq(s.inventory_segments.size(), 0)
	t.eq(s.revision, 0)


func test_order_restock_fill_then_overflow_fails(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _shelf(s, cmds, "shelf_onigiri")
	t.ok(_order(cmds, "rice_001", 30).ok)
	var cash := s.cash_yen
	var r := _restock(cmds, shelf, "row0", "rice_001", 5)
	t.ok(r.ok, "partial restock")
	t.eq(_total(s, "rice_001"), 30, "total conserved after split")
	t.eq(s.backroom_available("rice_001"), 25)
	t.eq(s.snapshot()["shelf_stock"][shelf]["row0"], 5)
	t.eq(s.snapshot()["shelf_skus"][shelf]["row0"], "rice_001")
	t.eq(s.cash_yen, cash, "restock moves no money")
	t.ok(_restock(cmds, shelf, "row0", "rice_001", 7).ok, "fill to capacity 12")
	t.eq(s.snapshot()["shelf_stock"][shelf]["row0"], 12)
	var before := s.inventory_segments.duplicate(true)
	var rev := s.revision
	var over := _restock(cmds, shelf, "row0", "rice_001", 1)
	t.eq(over.message_key, &"capacity_exceeded")
	t.eq(s.inventory_segments, before, "failed restock changes nothing")
	t.eq(s.revision, rev)
	t.eq(_total(s, "rice_001"), 30)


func test_restock_rejections(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _shelf(s, cmds, "shelf_onigiri")
	_order(cmds, "rice_001", 3)
	_order(cmds, "drink_001", 3)
	t.eq(_restock(cmds, shelf, "row0", "drink_001", 1).message_key, &"category_mismatch")
	t.eq(_restock(cmds, shelf, "row0", "rice_001", 4).message_key, &"not_enough_stock", "more than the backroom has")
	t.eq(_restock(cmds, shelf, "row0", "rice_001", 0).message_key, &"qty_invalid")
	t.eq(_restock(cmds, shelf, "row0", "rice_001", -2).message_key, &"qty_invalid")
	t.eq(_restock(cmds, shelf, "row9", "rice_001", 1).message_key, &"unknown_slot")
	t.eq(_restock(cmds, "fx_9999", "row0", "rice_001", 1).message_key, &"unknown_instance")
	t.ok(_restock(cmds, shelf, "row0", "rice_001", 1).ok)
	_order(cmds, "rice_002", 1)
	t.eq(_restock(cmds, shelf, "row0", "rice_002", 1).message_key, &"slot_other_sku", "one SKU per slot")
	t.eq(_total(s, "rice_001"), 3)


func test_restock_is_not_allowed_while_open(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _shelf(s, cmds, "shelf_onigiri")
	_order(cmds, "rice_001", 3)
	for st in [GameState.OPEN, GameState.CLOSING]:
		s.business_state = st
		t.eq(_restock(cmds, shelf, "row0", "rice_001", 1).code, &"NOT_IN_SETUP")
	t.ok(_order(cmds, "rice_001", 1).ok, "ordering still works while open")


func test_fefo_moves_earliest_expiry_first_and_keeps_lot_data(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _shelf(s, cmds, "shelf_onigiri")
	_order(cmds, "rice_001", 4)
	s.time_sec = 1000
	_order(cmds, "rice_001", 4)
	# Make the second lot expire earlier than the first.
	s.inventory_segments[1]["expires_at_sec"] = 500
	s.inventory_segments[1]["unit_cost_yen"] = 90
	t.ok(_restock(cmds, shelf, "row0", "rice_001", 6).ok)
	var on_shelf := 0
	var early_shelf := 0
	for seg in s.inventory_segments:
		if seg["location"]["kind"] == "FIXTURE":
			on_shelf += seg["physical_qty"]
			if seg["lot_id"] == "lot_0002":
				early_shelf += seg["physical_qty"]
				t.eq(seg["unit_cost_yen"], 90, "split keeps unit cost")
				t.eq(seg["expires_at_sec"], 500, "split keeps expiry")
	t.eq(on_shelf, 6)
	t.eq(early_shelf, 4, "the earlier-expiring lot goes first")
	t.eq(_total(s, "rice_001"), 8)


func test_reserved_units_are_not_moved(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf := _shelf(s, cmds, "shelf_onigiri")
	_order(cmds, "rice_001", 5)
	s.inventory_segments[0]["reserved_qty"] = 2
	s.reservations.append({"reservation_id": "r1", "customer_id": "c1", "segment_id": s.inventory_segments[0]["segment_id"], "qty": 2,
		"sell_unit_yen_snapshot": 150, "cost_unit_yen_snapshot": 100, "reservation_expires_at_sec": 60})
	t.eq(_restock(cmds, shelf, "row0", "rice_001", 4).message_key, &"not_enough_stock", "only 3 are available")
	t.ok(_restock(cmds, shelf, "row0", "rice_001", 3).ok)
	t.eq(s.inventory_segments[0]["physical_qty"], 2, "reserved units stay in the backroom")
	t.eq(s.inventory_segments[0]["reserved_qty"], 2)
	t.eq(_total(s, "rice_001"), 5)


func test_same_command_id_does_not_double_apply(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var c := {"command_id": "once", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 10}
	t.ok(cmds.execute(c).ok)
	t.eq(cmds.execute(c).code, &"ALREADY_APPLIED")
	t.eq(_total(s, "rice_001"), 10)
	t.eq(s.cash_yen, 499000)
