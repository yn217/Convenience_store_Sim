extends RefCounted
## Issue #21: HUD figures and speed controls, shelf details in the inspector, distinct failure
## messages, 1920x1080 fit and click isolation of the panels.


func _boot(tree, size: Vector2 = Vector2(1920, 1080)) -> Array:
	var holder := Control.new()
	holder.size = size
	tree.root.add_child(holder)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	holder.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return [holder, main, main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld"), main.get_node("AppRoot")]


func _stock(app: Node) -> String:
	var shelf: String = app.run_command({"command_id": "i1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	app.run_command({"command_id": "i2", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	app.run_command({"command_id": "i3", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 8})
	app.run_command({"command_id": "i4", "kind": &"RESTOCK", "instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 5})
	return shelf


func test_hud_shows_real_sales_and_customers(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var app: Node = r[3]
	var row := main.get_node("Layout/TopHUD/Row")
	t.eq((row.get_node("SalesLabel") as Label).text, "本日の売上 ¥0", "no dash: a real zero")
	t.eq((row.get_node("CustomersLabel") as Label).text, "店内客 0")
	_stock(app)
	app.run_command({"command_id": "i5", "kind": &"START_BUSINESS"})
	for i in 2:
		InventoryService.reserve(app.state, "r%d" % i, "c%d" % i, "rice_001", 600)
		InventoryService.complete_sale(app.state, "tx%d" % i, "r%d" % i)
	app.state.customers.append({"customer_id": "x", "phase": "CHECKOUT", "checkout_left": 1000, "register_id": "z", "reservation_id": "", "queue_slot": -1, "tile": Vector2i(1, 1)})
	app._publish_snapshot()
	t.eq((row.get_node("SalesLabel") as Label).text, "本日の売上 ¥300")
	t.eq((row.get_node("ProfitLabel") as Label).text, "本日の粗利 ¥100", "300 revenue - 200 cost")
	t.eq((row.get_node("CustomersLabel") as Label).text, "店内客 1")
	r[0].queue_free()
	await tree.process_frame


func test_speed_buttons_and_p_key(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var world: Node2D = r[2]
	var app: Node = r[3]
	var hud: GameHud = main.get_node("Layout/TopHUD")
	t.eq(hud._speed_buttons.size(), 4)
	t.ok(hud._speed_buttons[0].button_pressed, "stopped in SETUP")
	t.ok(hud._speed_buttons[2].disabled, "no clock to speed up in SETUP")
	var builder := main.get_node("BuildController")
	hud.speed_requested.emit(2)
	t.eq(app.state.speed_setting, 0, "SETUP refuses a running speed")
	t.eq((builder._status_label as Label).text, CommandMessages.text(&"INVALID_OPERATION", &"speed_requires_business"))
	_stock(app)
	app.run_command({"command_id": "i5", "kind": &"START_BUSINESS"})
	t.eq(app.state.speed_setting, 1)
	t.ok(not hud._speed_buttons[4].disabled)
	hud.speed_requested.emit(4)
	t.eq(app.state.speed_setting, 4)
	t.ok(hud._speed_buttons[4].button_pressed and not hud._speed_buttons[1].button_pressed)
	world.pause_toggle_requested.emit()
	t.eq(app.state.speed_setting, 0, "P pauses")
	t.eq(app.state.business_state, GameState.OPEN, "a paused OPEN store is still open")
	t.eq(app.run_command({"command_id": "i6", "kind": &"PLACE_FIXTURE", "type_id": "shelf_general", "x": 10, "y": 8, "rotation": 0}).code, &"NOT_IN_SETUP", "pause does not allow construction")
	world.pause_toggle_requested.emit()
	t.eq(app.state.speed_setting, 4, "P resumes at the previous speed")
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	var seen := [0]
	world.pause_toggle_requested.connect(func(): seen[0] += 1)
	t.ok(world.get_node("InputController").handle_event(key))
	t.eq(seen[0], 1, "the P key reaches the world as a pause request")
	r[0].queue_free()
	await tree.process_frame


func test_selected_shelf_shows_stock_price_and_capacity(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var world: Node2D = r[2]
	var app: Node = r[3]
	_stock(app)
	world.select_screen(world.projection.tile_center(Vector2i(4, 5)))
	var text := (main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body/FixtureLabel") as Label).text
	t.ok(text.contains("おにぎり棚"), text)
	t.ok(text.contains("row0: 鮭おにぎり 5/12"), "what is on the slot and how full")
	t.ok(text.contains("売価 ¥150（原価 ¥100）"), "selling price against unit cost")
	t.ok(text.contains("row1: 空き（容量 12）"), "empty slots show their capacity")
	app.run_command({"command_id": "i9", "kind": &"SET_PRICE", "sku_id": "rice_001", "price_yen": 180})
	text = (main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body/FixtureLabel") as Label).text
	t.ok(text.contains("売価 ¥180"), "a price change shows up at once")
	r[0].queue_free()
	await tree.process_frame


func test_failures_are_told_apart(t, tree) -> void:
	var texts := {
		"cash": CommandMessages.text(&"INSUFFICIENT_CASH", &"not_enough_cash"),
		"overlap": CommandMessages.text(&"OCCUPIED", &"cell_occupied"),
		"entrance": CommandMessages.text(&"ENTRANCE_BLOCKED", &"blocks_entrance"),
		"unreachable": CommandMessages.text(&"UNREACHABLE_ACCESS", &"access_unreachable"),
		"stock": CommandMessages.text(&"INVALID_OPERATION", &"not_enough_stock"),
		"category": CommandMessages.text(&"INVALID_OPERATION", &"category_mismatch"),
		"capacity": CommandMessages.text(&"INVALID_OPERATION", &"capacity_exceeded"),
		"register": CommandMessages.text(&"MISSING_REGISTER", &"missing_register"),
		"nostock": CommandMessages.text(&"MISSING_STOCK", &"missing_stock"),
		"setup": CommandMessages.text(&"NOT_IN_SETUP", &"construction_needs_setup"),
	}
	var seen := {}
	for k in texts:
		t.ok(String(texts[k]).length() > 4, "%s has a message" % k)
		t.ok(not seen.has(texts[k]), "%s is worded differently from the others" % k)
		seen[texts[k]] = true


func test_everything_fits_1920x1080(t, tree) -> void:
	var r: Array = await _boot(tree, Vector2(1920, 1080))
	var main: Control = r[1]
	var inspector: Control = main.get_node("Layout/MainArea/FixtureInspector")
	var palette: Control = main.get_node("Layout/MainArea/BuildPalette")
	var area: Control = main.get_node("Layout/MainArea")
	t.ok(main.get_combined_minimum_size().y <= 1080.0, "the whole screen needs no more than 1080 px (%s)" % str(main.get_combined_minimum_size().y))
	t.ok(inspector.size.y <= 1080.0 - 64.0 + 1.0, "inspector height stays inside the window (%s)" % str(inspector.size.y))
	t.ok(inspector.get_node("Scroll").vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "long contents scroll instead of growing the window")
	t.ok(palette.get_combined_minimum_size().y <= area.size.y, "palette fits the height")
	t.eq(inspector.size.x, 320.0)
	t.eq(palette.size.x, 280.0)
	var hud: Control = main.get_node("Layout/TopHUD")
	t.ok(hud.get_combined_minimum_size().x <= 1920.0, "HUD labels and speed buttons fit one row")
	t.ok(main.get_node("Layout/MainArea/StoreViewport").size.x >= 1200.0, "the store view keeps most of the width")
	r[0].queue_free()
	await tree.process_frame


func test_panels_do_not_pass_clicks_to_the_store(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var world: Node2D = r[2]
	var app: Node = r[3]
	# A real click on the palette area never reaches the SubViewport's input controller.
	var palette: Control = main.get_node("Layout/MainArea/BuildPalette")
	var inside := palette.get_global_rect().get_center()
	var store: Control = main.get_node("Layout/MainArea/StoreViewport")
	t.ok(not store.get_global_rect().has_point(inside), "the palette lies outside the store view")
	var before: Vector2i = world.selected_tile
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = inside
	Input.parse_input_event(press)
	await tree.process_frame
	t.eq(world.selected_tile, before, "no tile was selected by a click on a panel")
	t.eq(app.state.grid.instances.size(), 0, "and nothing was placed")
	r[0].queue_free()
	await tree.process_frame
