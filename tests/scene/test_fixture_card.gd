extends RefCounted
## The "選択中の什器" card follows the store selection and the snapshot.


func test_card_follows_selection(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var card: FixtureCard = main.get_node("FixtureCard")
	var world: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	t.eq(card._name.text, "未選択", "nothing selected at boot")
	app.state.ledger.cash_yen = 5000000
	var r: CommandResult = app.run_command({"command_id": "fc_place", "kind": &"PLACE_FIXTURE", "type_id": "shelf_general", "x": 3, "y": 2, "rotation": 0})
	t.ok(r.ok, "a shelf can be placed")
	var fid: String = app.state.grid.instances.keys()[0]
	app.state.ledger.record("SALE", "fc_sale", 500, app.state.day, app.state.time_sec,
			{"reservation_id": "x", "sku_id": "snack_001", "qty": 1, "fixture_id": fid}, {"revenue": 500, "cogs": 200})
	app._publish_snapshot()
	world.select_screen(world.projection.tile_center(Vector2i(3, 2)))
	await tree.process_frame
	t.eq(card._name.text, "汎用棚", "the selected shelf is named")
	t.eq(card._price.text, "¥40,000", "price tile")
	t.eq(card._size.text, "1×2", "size tile")
	t.eq(card._status.text, "設置中", "status chip: the store is still in setup")
	t.eq(card._category.text, "おかし・カップ麺・パン", "category chip: the shelf's allowed categories, in Japanese")
	t.ok(card._category.get_parent().visible, "the chip shows for a shelf")
	t.eq(card._rows[0]["value"].text, "0 / 48", "empty shelf: nothing stocked yet")
	t.eq(card._rows[1]["value"].text, "¥500", "today's sales of this shelf come from the ledger")
	t.eq(card._rows[1]["bar"].value, 1.0, "it is the whole store's sales today")
	t.eq(card._rows[2]["value"].text, "¥300", "gross profit = revenue - cost")
	t.ok(card._rows[0]["box"].visible and card._rows[2]["box"].visible)
	world.clear_selection()
	await tree.process_frame
	t.eq(card._name.text, "未選択", "clearing the selection shows the empty state")
	t.ok(not card._rows[0]["box"].visible, "rows hide when nothing is selected")
	main.queue_free()
	await tree.process_frame
