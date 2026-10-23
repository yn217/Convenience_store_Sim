extends RefCounted
## Issue #18: start/close buttons and the next-day advertising selector.


func test_start_needs_a_register_then_opens(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var bc: BusinessController = main.get_node("BusinessController")
	t.ok(not bc._start.disabled)
	t.ok(bc._close.disabled, "nothing to close yet")
	var r := bc.start_business()
	t.eq(r.code, &"MISSING_REGISTER")
	t.eq(bc._status.text, CommandMessages.text(&"MISSING_REGISTER", &"missing_register"))
	t.eq(app.state.business_state, GameState.SETUP)
	app.run_command({"command_id": "u1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	app.run_command({"command_id": "u2", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	app.run_command({"command_id": "u3", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 5})
	app.run_command({"command_id": "u4", "kind": &"RESTOCK", "instance_id": "fx_0001", "slot_id": "row0", "sku_id": "rice_001", "qty": 5})
	# Pick the 2,000-yen tier through the selector.
	var idx := -1
	for i in bc._ad.item_count:
		if bc._ad.get_item_metadata(i) == 2000:
			idx = i
	bc._ad.select(idx)
	t.ok(bc.set_next_day_ad(2000).ok)
	t.ok(bc._ad_info.text.contains("今日の広告: なし"), "today is not changed by tomorrow's choice")
	t.ok(bc._ad_info.text.contains("¥2,000"))
	t.ok(bc.start_business().ok)
	t.eq(app.state.business_state, GameState.OPEN)
	t.ok(bc._start.disabled)
	t.ok(not bc._close.disabled)
	t.ok(bc._ad_info.text.contains("今日の広告: ¥2,000"))
	t.ok(bc.request_close().ok)
	t.eq(app.state.business_state, GameState.CLOSING)
	t.eq(bc.set_next_day_ad(777).code, &"INVALID_OPERATION")
	t.eq(bc._status.text, CommandMessages.text(&"INVALID_OPERATION", &"ad_tier_invalid"))
	main.queue_free()
	await tree.process_frame
