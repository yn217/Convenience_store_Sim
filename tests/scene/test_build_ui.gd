extends RefCounted
## Issue #6 through the real UI path: palette -> ghost -> click -> command -> snapshot -> views.

const NO_TILE := Vector2i(-1, -1)
const PATH_WORLD := "Layout/MainArea/StoreViewport/SubViewport/StoreWorld"


func _boot(tree) -> Dictionary:
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	tree.root.add_child(holder)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	holder.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	var world: Node2D = main.get_node(PATH_WORLD)
	return {
		"holder": holder, "main": main, "world": world, "ctl": world.get_node("InputController"),
		"bc": main.get_node("BuildController"), "app": main.get_node("AppRoot"),
	}


func _end(tree, r: Dictionary) -> void:
	r["holder"].queue_free()
	await tree.process_frame


func _btn(pos: Vector2, index: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = index
	e.pressed = pressed
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	return e


func _hover(r: Dictionary, tile: Vector2i) -> void:
	r["ctl"].handle_event(_motion(r["world"].projection.tile_center(tile)))


func _click(r: Dictionary, tile: Vector2i) -> void:
	var p: Vector2 = r["world"].projection.tile_center(tile)
	r["ctl"].handle_event(_motion(p))
	r["ctl"].handle_event(_btn(p, MOUSE_BUTTON_LEFT, true))
	r["ctl"].handle_event(_btn(p, MOUSE_BUTTON_LEFT, false))


func _status(r: Dictionary) -> String:
	return (r["main"].get_node("Layout/MainArea/BuildPalette/Body/StatusLabel") as Label).text


func _preview(r: Dictionary) -> String:
	return (r["main"].get_node("Layout/MainArea/BuildPalette/Body/PreviewLabel") as Label).text


func test_palette_lists_all_fixture_types(t, tree) -> void:
	var r := await _boot(tree)
	var list: GridContainer = r["main"].find_child("TypeList", true, false)
	t.eq(list.get_child_count(), 10, "10 fixture types in the catalog")
	var price := (list.get_child(0) as Button).find_child("Price", true, false) as Label
	t.ok(price != null and price.text == "¥90,000", "price shown: " + (price.text if price != null else "missing"))
	t.eq(r["main"].get_node("Layout/MainArea/BuildPalette").offset_right - r["main"].get_node("Layout/MainArea/BuildPalette").offset_left, 380.0, "catalog is a 380 px floating window")
	await _end(tree, r)


func test_place_flow_ghost_rotate_commit(t, tree) -> void:
	var r := await _boot(tree)
	var world: Node2D = r["world"]
	var bc: Node = r["bc"]
	var state: GameState = r["app"].state
	bc._catalog_view.card("shelf_general").pressed.emit()
	t.eq(bc.mode, 1, "PLACE mode")
	t.eq(world.mode, 1, "world knows the mode")
	_hover(r, Vector2i(5, 5))
	t.eq(world._ghost["cells"], [Vector2i(5, 5), Vector2i(5, 6)] as Array[Vector2i], "ghost shows the 1x2 footprint")
	t.eq(world._ghost["access"], [Vector2i(6, 5), Vector2i(6, 6)] as Array[Vector2i], "ghost shows the E-side access tiles")
	t.ok(world._ghost["valid"], "valid placement is green")
	t.ok(_preview(r).contains("設置できます") and _preview(r).contains("¥40,000"), "cost shown: " + _preview(r))
	t.eq(state.cash_yen, 500000, "preview spends nothing")
	r["ctl"].handle_event(_key(KEY_R))
	t.eq(bc.preview_rotation, 1, "R rotates the preview")
	t.eq(world._ghost["cells"], [Vector2i(5, 5), Vector2i(6, 5)] as Array[Vector2i], "ghost became 2x1")
	t.eq(world._ghost["access"], [Vector2i(5, 6), Vector2i(6, 6)] as Array[Vector2i], "front moved to the S side")
	_click(r, Vector2i(5, 5))
	t.eq(state.grid.instances.size(), 1, "click commits")
	t.eq(state.cash_yen, 460000)
	t.eq(_status(r), "設置しました")
	t.eq(world.fixtures.size(), 1, "world got the new snapshot")
	t.ok((r["main"].get_node("Layout/TopHUD").find_child("CashLabel", true, false) as Label).text.contains("¥460,000"), "HUD updated")
	t.eq(bc.mode, 1, "stays in PLACE mode for the next fixture")
	await _end(tree, r)


func test_invalid_placement_is_red_with_reason_and_refused(t, tree) -> void:
	var r := await _boot(tree)
	var world: Node2D = r["world"]
	var state: GameState = r["app"].state
	r["bc"]._catalog_view.card("shelf_general").pressed.emit()
	_click(r, Vector2i(5, 5))
	_hover(r, Vector2i(5, 6))
	t.ok(not world._ghost["valid"], "overlap is red")
	t.ok(_preview(r).contains("重なる"), "reason in text, not colour only: " + _preview(r))
	_click(r, Vector2i(5, 6))
	t.eq(state.grid.instances.size(), 1, "refused at commit")
	t.ok(_status(r).contains("重なる"))
	_hover(r, Vector2i(0, 5))
	t.ok(_preview(r).contains("入口"), "entrance reason: " + _preview(r))
	_hover(r, Vector2i(15, 11))
	t.ok(_preview(r).contains("外"), "outside reason: " + _preview(r))
	r["ctl"].handle_event(_key(KEY_ESCAPE))
	t.eq(r["bc"].mode, 0, "Esc cancels placement")
	t.eq(world.mode, 0)
	t.eq(world._ghost, {}, "ghost removed")
	await _end(tree, r)


func test_not_enough_cash_is_refused(t, tree) -> void:
	var r := await _boot(tree)
	var state: GameState = r["app"].state
	state.ledger.cash_yen = 30000
	r["app"]._publish_snapshot()
	r["bc"]._catalog_view.card("shelf_general").pressed.emit()
	_hover(r, Vector2i(5, 5))
	t.ok(_preview(r).contains("資金"), "cash reason: " + _preview(r))
	_click(r, Vector2i(5, 5))
	t.eq(state.grid.instances.size(), 0)
	t.eq(state.cash_yen, 30000)
	await _end(tree, r)


func test_move_rotate_remove_undo_redo_through_the_inspector(t, tree) -> void:
	var r := await _boot(tree)
	var main: Control = r["main"]
	var bc: Node = r["bc"]
	var state: GameState = r["app"].state
	bc._catalog_view.card("shelf_general").pressed.emit()
	_click(r, Vector2i(5, 5))
	r["ctl"].handle_event(_key(KEY_ESCAPE))
	_click(r, Vector2i(5, 6))       # observe mode: select the second cell of the shelf
	t.eq(bc.selected_fixture_id, "fx_0001", "clicking any occupied cell selects the fixture")
	var label := main.find_child("FixtureLabel", true, false) as Label
	t.ok(label.text.contains("位置 (5, 5)") and label.text.contains("アクセス面 E"), "inspector: " + label.text)
	t.ok(not (main.find_child("MoveButton", true, false) as Button).disabled, "move enabled in SETUP")
	# Move
	main.find_child("MoveButton", true, false).pressed.emit()
	t.eq(bc.mode, 2, "MOVE mode")
	_hover(r, Vector2i(9, 3))
	t.ok(_preview(r).contains("移動できます"), _preview(r))
	var cash: int = state.cash_yen
	_click(r, Vector2i(9, 3))
	t.eq(state.grid.instances["fx_0001"]["x"], 9, "moved")
	t.eq(state.cash_yen, cash, "moving is free")
	t.eq(bc.mode, 0, "MOVE mode ends after commit")
	# Rotate in place
	_click(r, Vector2i(9, 3))
	main.find_child("RotateButton", true, false).pressed.emit()
	t.eq(state.grid.instances["fx_0001"]["rotation"], 1, "rotate button turns it 90°")
	# Undo x3 via buttons, redo x3
	var undo := main.get_node("Layout/MainArea/BuildPalette/Body/UndoRow/UndoButton") as Button
	var redo := main.get_node("Layout/MainArea/BuildPalette/Body/UndoRow/RedoButton") as Button
	t.ok(not undo.disabled and redo.disabled, "undo available, redo not yet")
	undo.pressed.emit()
	undo.pressed.emit()
	t.eq(state.grid.instances["fx_0001"]["x"], 5, "undo move and rotate")
	undo.pressed.emit()
	t.eq(state.grid.instances.size(), 0, "undo place")
	t.eq(state.cash_yen, 500000, "cash fully refunded")
	t.ok(undo.disabled and not redo.disabled, "buttons follow history")
	redo.pressed.emit()
	redo.pressed.emit()
	redo.pressed.emit()
	t.eq(state.grid.instances["fx_0001"]["x"], 9)
	t.eq(state.grid.instances["fx_0001"]["rotation"], 1)
	t.eq(state.cash_yen, 460000, "bought again once")
	# Remove with confirmation
	_click(r, Vector2i(9, 3))
	main.find_child("RemoveButton", true, false).pressed.emit()
	t.ok(main.get_node("RemoveDialog").visible, "removal asks for confirmation")
	t.eq(state.grid.instances.size(), 1, "nothing removed before confirming")
	main.get_node("RemoveDialog").confirmed.emit()
	t.eq(state.grid.instances.size(), 0, "removed after confirming")
	t.eq(state.cash_yen, 460000, "no refund on removal")
	r["ctl"].handle_event(_key(KEY_Z, true))
	t.eq(state.grid.instances.size(), 1, "Ctrl+Z undoes the removal")
	r["ctl"].handle_event(_key(KEY_Y, true))
	t.eq(state.grid.instances.size(), 0, "Ctrl+Y redoes it")
	main.get_node("RemoveDialog").hide()
	await _end(tree, r)


func test_construction_is_locked_outside_setup(t, tree) -> void:
	var r := await _boot(tree)
	var state: GameState = r["app"].state
	var bc: Node = r["bc"]
	bc._catalog_view.card("shelf_general").pressed.emit()
	t.eq(bc.mode, 1)
	state.business_state = GameState.OPEN
	state.speed_setting = 0     # OPEN + pause: still no construction
	r["app"]._publish_snapshot()
	t.eq(bc.mode, 0, "an open store leaves the build mode")
	t.ok(bc._catalog_view.card("shelf_general").disabled, "palette disabled")
	bc._catalog_view.card("shelf_general").pressed.emit()
	t.eq(bc.mode, 0, "cannot re-enter")
	t.ok(_status(r).contains("準備中") or _status(r).contains("営業を終了"), "tells the player why: " + _status(r))
	_click(r, Vector2i(5, 5))
	t.eq(state.grid.instances.size(), 0, "no placement while open")
	await _end(tree, r)


func test_keyboard_reaches_the_store_through_the_window(t, tree) -> void:
	var r := await _boot(tree)
	var bc: Node = r["bc"]
	bc._catalog_view.card("shelf_general").pressed.emit()
	var k := _key(KEY_R)
	tree.root.push_input(k, true)
	await tree.process_frame
	t.eq(bc.preview_rotation, 1, "R pressed in the window rotates the preview")
	tree.root.push_input(_key(KEY_ESCAPE), true)
	await tree.process_frame
	t.eq(bc.mode, 0, "Esc pressed in the window cancels")
	await _end(tree, r)


func _put(state: GameState, id: String, type_id: String, x: int, y: int) -> void:
	state.grid.add_instance({"instance_id": id, "type_id": type_id, "x": x, "y": y, "rotation": 0, "enabled": true}, state.fixtures)


func test_corridor_block_is_red_with_a_reason(t, tree) -> void:
	var r := await _boot(tree)
	var state: GameState = r["app"].state
	var world: Node2D = r["world"]
	for p in [["w1", 8, 0], ["w2", 8, 2], ["w3", 8, 8], ["w4", 8, 10], ["w5", 8, 4]]:
		_put(state, p[0], "freezer_ice", p[1], p[2])
	_put(state, "reg", "register_basic", 12, 5)
	r["app"]._publish_snapshot()
	r["bc"]._catalog_view.card("freezer_ice").pressed.emit()
	_hover(r, Vector2i(8, 6))
	t.ok(not world._ghost["valid"], "sealing the last gap is red")
	t.ok(_preview(r).contains("塞ぐ"), "reason in text: " + _preview(r))
	_click(r, Vector2i(8, 6))
	t.eq(state.grid.instances.size(), 6, "refused at commit")
	_hover(r, Vector2i(3, 2))
	t.ok(world._ghost["valid"], "somewhere harmless is fine")
	await _end(tree, r)


func test_register_preview_shows_its_queue(t, tree) -> void:
	var r := await _boot(tree)
	var world: Node2D = r["world"]
	r["bc"]._catalog_view.card("register_basic").pressed.emit()
	_hover(r, Vector2i(6, 4))
	t.eq(world._ghost["queue"], [Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)] as Array[Vector2i], "3-slot queue line")
	_hover(r, Vector2i(15, 4))
	t.ok(not world._ghost["valid"], "register facing the wall is refused")
	t.ok(_preview(r).contains("前が空いていない") or _preview(r).contains("待機列"), "reason: " + _preview(r))
	await _end(tree, r)
