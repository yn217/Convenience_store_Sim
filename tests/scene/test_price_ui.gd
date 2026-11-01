extends RefCounted
## Issue #10: price editor in the inspector sends SET_PRICE and rejects malformed input.


func test_parse_price_text(t, _tree) -> void:
	t.eq(PriceController.parse_price_text("180"), 180)
	t.eq(PriceController.parse_price_text(" ¥1,200 "), 1200)
	for bad in ["", "abc", "-5", "+5", "1.5", "0", "1234567", "１２"]:
		t.ok(PriceController.parse_price_text(bad) < 1, "rejects '%s'" % bad)


func test_editing_a_price_changes_state_and_shows_errors(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var pc: Node = main.get_node("PriceController")
	var app: Node = main.get_node("AppRoot")
	t.eq(pc._rows.size(), 62, "one row per SKU")
	var edit: LineEdit = pc._rows["rice_001"]
	t.eq(edit.text, "150")
	edit.text = "175"
	t.ok(pc.submit("rice_001", edit).ok)
	t.eq(app.state.sell_price("rice_001"), 175)
	edit.text = "-3"
	var r: CommandResult = pc.submit("rice_001", edit)
	t.ok(not r.ok)
	t.eq(app.state.sell_price("rice_001"), 175, "bad input changes nothing")
	t.eq(edit.text, "175", "field restored to the real price")
	t.eq(pc._status.text, CommandMessages.text(&"INVALID_OPERATION", &"price_invalid"))
	main.queue_free()
	await tree.process_frame


## The mockup price rows' ▲ / ▼ move the shown price by ¥10 and its 粗利; nothing is sent until 変更.
func test_price_arrows_step_the_field(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var pc: Node = main.get_node("PriceController")
	var edit: LineEdit = pc.price_field("bake_001")
	var before := int(edit.text)
	pc.step_price("bake_001", 1)
	t.eq(int(edit.text), before + 10, "▲ adds ¥10")
	pc.step_price("bake_001", -1)
	pc.step_price("bake_001", -1)
	t.eq(int(edit.text), before - 10, "▼ takes ¥10 off")
	var cost := int(main.get_node("AppRoot").state.products.get_sku("bake_001")["purchase_cost_yen"])
	t.eq(pc._margins["bake_001"][0].text, GameHud.format_yen(before - 10 - cost), "粗利 follows")
	t.ok(int(main.get_node("AppRoot").state.sell_price("bake_001")) == before, "the price itself changes only with 変更")
	for i in 100:
		pc.step_price("bake_001", -1)
	t.eq(int(edit.text), 10, "never below ¥10")
	main.queue_free()
	await tree.process_frame
