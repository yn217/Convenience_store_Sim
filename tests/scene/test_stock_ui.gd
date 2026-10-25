extends RefCounted
## Issue #11: order and restock panel drives the commands and surfaces rejections.


func test_parse_qty_text(t, _tree) -> void:
	t.eq(StockController.parse_qty_text("12"), 12)
	t.eq(StockController.parse_qty_text(" 9,999 "), 9999)
	for bad in ["", "abc", "-5", "+5", "1.5", "0", "10000", "１"]:
		t.ok(StockController.parse_qty_text(bad) < 1, "rejects '%s'" % bad)


func test_order_then_restock_through_the_panel(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var sc: StockController = main.get_node("StockController")
	var shelf: String = app.run_command({"command_id": "t_place", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	# onigiri shelf is the first SKU entry of the order list that is rice_ball: pick rice_001 explicitly.
	var idx := -1
	for i in sc._order_sku.item_count:
		if sc._order_sku.get_item_metadata(i) == "rice_001":
			idx = i
	sc._order_sku.select(idx)
	sc._order_qty.text = "-1"
	t.ok(not sc.submit_order().ok, "negative qty rejected")
	t.eq(sc._status.text, CommandMessages.text(&"INVALID_OPERATION", &"qty_invalid"))
	sc._order_qty.text = "15"
	t.ok(sc.submit_order().ok)
	t.eq(app.state.backroom_available("rice_001"), 15)
	t.ok(sc._backroom.text.contains("15"), "backroom label shows the stock")
	main.get_node("BuildController").selected_fixture_id = shelf
	sc._refresh()
	t.ok(sc._restock_box.visible, "restock controls for the selected shelf")
	t.ok(sc._restock_sku.item_count > 0)
	for i in sc._restock_sku.item_count:   # the onigiri shelf also takes bento (#147): pick the rice ball
		if sc._restock_sku.get_item_metadata(i) == "rice_001":
			sc._restock_sku.select(i)
	sc._restock_qty.text = "12"
	t.ok(sc.submit_restock().ok)
	t.eq(app.state.snapshot()["shelf_stock"][shelf]["row0"], 12)
	sc._restock_qty.text = "1"
	var r: CommandResult = sc.submit_restock()
	t.ok(not r.ok, "full shelf rejects more")
	t.eq(sc._status.text, CommandMessages.text(r.code, r.message_key))
	t.eq(app.state.backroom_available("rice_001"), 3)
	main.queue_free()
	await tree.process_frame
