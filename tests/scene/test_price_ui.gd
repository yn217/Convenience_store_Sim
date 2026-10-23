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
	t.eq(pc._rows.size(), 24, "one row per SKU")
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
