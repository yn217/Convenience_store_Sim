extends RefCounted
## Issue #9: fill levels of display rows (0 / 2 / 5 / 8 items) and zoom LOD caps.


func test_fill_steps_are_0_2_5_8(t, _tree) -> void:
	t.eq(ShelfDisplay.item_count(0, 12), 0)
	t.eq(ShelfDisplay.item_count(1, 12), 2)
	t.eq(ShelfDisplay.item_count(4, 12), 2)
	t.eq(ShelfDisplay.item_count(5, 12), 5)
	t.eq(ShelfDisplay.item_count(8, 12), 5)
	t.eq(ShelfDisplay.item_count(9, 12), 8)
	t.eq(ShelfDisplay.item_count(12, 12), 8)
	t.eq(ShelfDisplay.item_count(30, 12), 8, "over capacity is clamped")
	t.eq(ShelfDisplay.item_count(3, 0), 0, "zero capacity shows nothing")


func test_lod_caps_items_by_zoom(t, _tree) -> void:
	t.eq(ShelfDisplay.lod(0.5), "bar")
	t.eq(ShelfDisplay.lod(1.0), "few")
	t.eq(ShelfDisplay.lod(2.0), "full")
	t.eq(ShelfDisplay.visible_items(12, 12, 0.5), 0)
	t.eq(ShelfDisplay.visible_items(12, 12, 1.0), 4)
	t.eq(ShelfDisplay.visible_items(12, 12, 2.0), 8)
	t.eq(ShelfDisplay.visible_items(5, 12, 1.0), 4)
	t.eq(ShelfDisplay.visible_items(5, 12, 2.0), 5)
	t.eq(ShelfDisplay.visible_items(2, 12, 1.0), 2)


func test_fill_ratio(t, _tree) -> void:
	t.ok(absf(ShelfDisplay.fill_ratio(6, 12) - 0.5) < 1e-9)
	t.ok(absf(ShelfDisplay.fill_ratio(99, 12) - 1.0) < 1e-9)
	t.ok(absf(ShelfDisplay.fill_ratio(1, 0) - 0.0) < 1e-9)


func test_stock_by_slot_sums_fixture_segments_only(t, _tree) -> void:
	var segs := [
		{"location": {"kind": "FIXTURE", "fixture_id": "f1", "slot_id": "row0"}, "physical_qty": 3},
		{"location": {"kind": "FIXTURE", "fixture_id": "f1", "slot_id": "row0"}, "physical_qty": 4},
		{"location": {"kind": "FIXTURE", "fixture_id": "f1", "slot_id": "row1"}, "physical_qty": 1},
		{"location": {"kind": "BACKROOM"}, "physical_qty": 50},
	]
	var by := ShelfDisplay.stock_by_slot(segs)
	t.eq(by["f1"]["row0"], 7)
	t.eq(by["f1"]["row1"], 1)
	t.eq(by.size(), 1)
	t.eq(ShelfDisplay.stock_by_slot([]).size(), 0)
