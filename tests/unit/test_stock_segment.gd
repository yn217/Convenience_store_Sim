extends RefCounted
## StockLot/segment validation (Issue #3 + 10_TEST_VECTORS §D invariants).


func _setup() -> Dictionary:
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var entrances: Array[Vector2i] = [Vector2i(0, 5)]
	var grid := StoreGrid.create("s", 16, 12, entrances)
	grid.add_instance({"instance_id": "fridge1", "type_id": "fridge_drink", "x": 6, "y": 2, "rotation": 0, "enabled": true}, fixtures)
	return {"p": products, "f": fixtures, "g": grid}


func _drink_sku(p: ProductCatalog) -> String:
	for id in p.skus:
		if p.skus[id]["category"] == "drink":
			return id
	return ""


func _seg(sku: String, over: Dictionary = {}) -> Dictionary:
	var s := {
		"segment_id": "seg1", "lot_id": "lot1", "sku_id": sku, "unit_cost_yen": 75,
		"expires_at_sec": null, "physical_qty": 10, "reserved_qty": 0,
		"location": {"kind": "BACKROOM"},
	}
	s.merge(over, true)
	return s


func test_valid_segments(t, _tree) -> void:
	var c := _setup()
	var sku := _drink_sku(c["p"])
	var shelf := _seg(sku, {"segment_id": "seg2", "physical_qty": 6, "location": {"kind": "FIXTURE", "fixture_id": "fridge1", "slot_id": "row0"}})
	var errs := StockSegment.list_errors([_seg(sku), shelf], c["p"], c["f"], c["g"])
	t.eq(errs, [] as Array[String], "backroom + shelf segments valid")


func test_invalid_table(t, _tree) -> void:
	var c := _setup()
	var sku := _drink_sku(c["p"])
	var cases := [
		["negative qty", _seg(sku, {"physical_qty": -1}), "physical_qty: negative"],
		["negative cost", _seg(sku, {"unit_cost_yen": -5}), "unit_cost_yen: negative"],
		["fractional qty", _seg(sku, {"physical_qty": 2.5}), "physical_qty: not_integer"],
		["reserved > physical", _seg(sku, {"reserved_qty": 11}), "reserved_qty: exceeds_physical"],
		["unknown sku", _seg("ghost_sku"), "sku_id: unknown_sku"],
		["negative expiry", _seg(sku, {"expires_at_sec": -1}), "expires_at_sec: negative"],
		["unknown location kind", _seg(sku, {"location": {"kind": "TRUCK"}}), "location.kind: unknown_kind"],
		["backroom with slot", _seg(sku, {"location": {"kind": "BACKROOM", "slot_id": "row0"}}), "location: backroom_has_slot"],
		["fixture without slot", _seg(sku, {"location": {"kind": "FIXTURE", "fixture_id": "fridge1"}}), "location: fixture_slot_missing"],
		["unknown fixture", _seg(sku, {"location": {"kind": "FIXTURE", "fixture_id": "zzz", "slot_id": "row0"}}), "location.fixture_id: unknown_fixture_instance"],
		["unknown slot", _seg(sku, {"location": {"kind": "FIXTURE", "fixture_id": "fridge1", "slot_id": "row99"}}), "location.slot_id: unknown_slot"],
	]
	for case in cases:
		var errs := StockSegment.segment_errors(case[1], c["p"], c["f"], c["g"], "seg")
		t.ok(errs.any(func(e): return e.ends_with(case[2])), "%s -> %s (got %s)" % [case[0], case[2], str(errs)])


func test_incompatible_category_on_shelf(t, _tree) -> void:
	var c := _setup()
	var snack := ""
	for id in c["p"].skus:
		if c["p"].skus[id]["category"] == "snack":
			snack = id
	var seg := _seg(snack, {"location": {"kind": "FIXTURE", "fixture_id": "fridge1", "slot_id": "row0"}})
	var errs := StockSegment.segment_errors(seg, c["p"], c["f"], c["g"], "seg")
	t.ok(errs.any(func(e): return e.ends_with("location: incompatible_category")), "snack in drink fridge rejected")


func test_list_level_invariants(t, _tree) -> void:
	var c := _setup()
	var sku := _drink_sku(c["p"])
	var slot := {"kind": "FIXTURE", "fixture_id": "fridge1", "slot_id": "row0"}
	var dup := StockSegment.list_errors([_seg(sku), _seg(sku)], c["p"], c["f"], c["g"])
	t.ok(dup.any(func(e): return e.ends_with("segment_id: duplicate_id")), "duplicate segment id")
	var row_cap := int(c["f"].get_type("fridge_drink")["shelf_slots"][0]["capacity_units"])
	var over := StockSegment.list_errors([_seg(sku, {"physical_qty": row_cap + 1, "location": slot})], c["p"], c["f"], c["g"])
	t.ok(over.any(func(e): return e.ends_with("slot_capacity_exceeded")), "slot capacity exceeded")
	var other := ""
	for id in c["p"].skus:
		if c["p"].skus[id]["category"] == "drink" and id != sku:
			other = id
			break
	var mixed := StockSegment.list_errors([
		_seg(sku, {"physical_qty": 1, "location": slot}),
		_seg(other, {"segment_id": "seg2", "lot_id": "lot2", "physical_qty": 1, "location": slot}),
	], c["p"], c["f"], c["g"])
	t.ok(mixed.any(func(e): return e.ends_with("slot_holds_multiple_skus")), "1 slot = 1 SKU")
