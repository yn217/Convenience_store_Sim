extends RefCounted
## Issue #10: SET_PRICE (08 §2), price overrides never touch lots or snapshotted sales,
## and SKU <-> fixture slot category compatibility.

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _price(cmds: GameCommands, sku: Variant, price: Variant) -> CommandResult:
	_n += 1
	return cmds.execute({"command_id": "p%d" % _n, "kind": &"SET_PRICE", "sku_id": sku, "price_yen": price})


func test_price_change_updates_override_and_revision(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.eq(s.sell_price("rice_001"), 150, "default price")
	var r := _price(cmds, "rice_001", 180)
	t.ok(r.ok, "accepted")
	t.eq(r.new_revision, 1)
	t.eq(r.event_ids.size(), 1)
	t.ok(r.event_ids[0].ends_with("SKU_PRICE_CHANGED"))
	t.eq(s.sell_price("rice_001"), 180)
	t.eq(s.snapshot()["product_price_overrides"], {"rice_001": 180})
	t.eq(s.products.get_sku("rice_001")["default_sell_price_yen"], 150, "master untouched")
	_price(cmds, "rice_001", 150)
	t.eq(s.product_price_overrides.size(), 0, "returning to the default drops the override")


func test_invalid_prices_are_rejected_without_state_change(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	for bad in [0, -1, -500, 100000, 1.5, "200", null, true]:
		var r := _price(cmds, "rice_001", bad)
		t.ok(not r.ok, "rejects %s" % str(bad))
		t.eq(r.code, &"INVALID_OPERATION")
		t.eq(r.message_key, &"price_invalid", "message for %s" % str(bad))
	t.eq(_price(cmds, "no_such_sku", 100).message_key, &"sku_unknown")
	t.eq(_price(cmds, 5, 100).message_key, &"sku_unknown")
	t.eq(_price(cmds, "rice_001", 150).message_key, &"no_change", "same as current price")
	t.eq(s.revision, 0, "failures never change the revision")
	t.eq(s.product_price_overrides.size(), 0)


func test_same_command_id_is_idempotent(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var c := {"command_id": "dup", "kind": &"SET_PRICE", "sku_id": "rice_001", "price_yen": 170}
	t.ok(cmds.execute(c).ok)
	var again := cmds.execute(c)
	t.eq(again.code, &"ALREADY_APPLIED")
	t.eq(s.revision, 1)


func test_price_can_change_in_every_business_state(t, _tree) -> void:
	for st in [GameState.SETUP, GameState.OPEN, GameState.CLOSING]:
		var s := _state()
		s.business_state = st
		t.ok(_price(GameCommands.new(s), "drink_001", 200).ok, "state %s" % str(st))


func test_existing_lots_and_reservations_keep_their_snapshot(t, _tree) -> void:
	var s := _state()
	s.inventory_segments.append({
		"segment_id": "seg1", "lot_id": "lot1", "sku_id": "rice_001", "unit_cost_yen": 100,
		"expires_at_sec": 86400, "physical_qty": 5, "reserved_qty": 1, "location": {"kind": "BACKROOM"},
	})
	s.reservations.append({
		"reservation_id": "r1", "customer_id": "c1", "segment_id": "seg1", "qty": 1,
		"sell_unit_yen_snapshot": 150, "cost_unit_yen_snapshot": 100, "reservation_expires_at_sec": 60,
	})
	s.ledger.record("SALE", "sale_1", 150, 0, 10, {"sell_unit_yen": 150})
	var cash := s.cash_yen
	var rows: Array = s.ledger.transactions.duplicate(true)
	t.ok(_price(GameCommands.new(s), "rice_001", 400).ok)
	t.eq(s.inventory_segments[0]["unit_cost_yen"], 100, "lot cost unchanged")
	t.eq(s.reservations[0]["sell_unit_yen_snapshot"], 150, "reservation price snapshot unchanged")
	t.eq(s.cash_yen, cash, "no cash movement")
	t.eq(s.ledger.transactions, rows, "confirmed ledger rows unchanged")
	t.eq(s.sell_price("rice_001"), 400, "new sales use the new price")


func test_sku_fixture_slot_category_compatibility(t, _tree) -> void:
	var s := _state()
	var rice := s.products.get_sku("rice_001")
	var drink := s.products.get_sku("drink_001")
	t.ok(s.fixtures.slot_accepts("shelf_onigiri", "row0", rice))
	t.ok(not s.fixtures.slot_accepts("shelf_onigiri", "row0", drink), "drink not on the onigiri shelf")
	t.ok(s.fixtures.slot_accepts("fridge_drink", "row0", drink))
	t.ok(not s.fixtures.slot_accepts("fridge_drink", "row0", rice))
	t.ok(not s.fixtures.slot_accepts("fridge_drink", "row9", drink), "unknown slot")
	t.ok(not s.fixtures.slot_accepts("register_basic", "row0", drink), "register has no slots")
	for sku in s.products.skus.values():
		var found := false
		for type_id in s.fixtures.types:
			for slot in s.fixtures.get_type(type_id)["shelf_slots"]:
				found = found or s.fixtures.slot_accepts(type_id, slot["slot_id"], sku)
		t.ok(found, "%s has a home" % sku["sku_id"])
