extends RefCounted
## Issue #24: overlays (layout / info), see-through help and picking of overlapping objects.

const Seeds := preload("res://tests/support/test_seeds.gd")


func _fixtures() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))


func _world(tree, fixtures: Array, customers: Array = [], stock: Dictionary = {}) -> Node2D:
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = _fixtures()
	world.apply_snapshot({
		"store_width": 20, "store_height": 12, "revision": 1, "entrance_tiles": [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i],
		"fixtures": fixtures, "customers": customers, "shelf_stock": stock, "speed_setting": 0,
	})
	return world


func _inst(id: String, type_id: String, x: int, y: int, r: int = 0) -> Dictionary:
	return {"instance_id": id, "type_id": type_id, "x": x, "y": y, "rotation": r, "enabled": true}


func test_access_cells_follow_rotation(t, _tree) -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 5), Vector2i(4, 6)]
	t.eq(OverlayModel.access_cells(cells, ["E"], 0, 20, 12), [Vector2i(5, 5), Vector2i(5, 6)] as Array[Vector2i])
	var turned: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 5)]
	t.eq(OverlayModel.access_cells(turned, ["E"], 1, 20, 12), [Vector2i(4, 6), Vector2i(5, 6)] as Array[Vector2i], "E turned once faces S")
	var edge: Array[Vector2i] = [Vector2i(19, 5), Vector2i(19, 6)]
	t.eq(OverlayModel.access_cells(edge, ["E"], 0, 20, 12).size(), 0, "tiles outside the store are not access tiles")
	var ice: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
	t.eq(OverlayModel.access_cells(ice, ["N", "E", "S", "W"], 0, 20, 12).size(), 8, "2x2 case reachable from all four sides")


func test_stock_status_has_icon_and_word(t, _tree) -> void:
	var fx := _fixtures()
	var shelf := fx.get_type("shelf_general")
	t.eq(OverlayModel.stock_status(shelf, {})["text"], "売切")
	t.eq(OverlayModel.stock_status(shelf, {})["icon"], "×")
	t.eq(OverlayModel.stock_status(shelf, {"row0": 2})["level"], "low")
	t.ok(OverlayModel.stock_status(shelf, {"row0": 2})["text"].begins_with("残少"))
	t.eq(OverlayModel.stock_status(shelf, {"row0": 12, "row1": 12})["level"], "ok")
	t.eq(OverlayModel.stock_status(fx.get_type("register_basic"), {})["text"], "レジ")
	for level in ["empty", "low", "ok"]:
		t.ok(OverlayLayer.LEVEL_COLOR.has(level))


func test_mode_switch_keeps_selection_ghost_and_state(t, tree) -> void:
	var world := _world(tree, [_inst("a", "shelf_general", 4, 5)])
	world.select_screen(world.projection.tile_center(Vector2i(4, 5)))
	var cells: Array[Vector2i] = [Vector2i(8, 8)]
	world.set_ghost(cells, [] as Array[Vector2i], false)
	var before := {"tile": world.selected_tile, "ghost": world._ghost.duplicate(), "fixtures": world.fixtures.duplicate(true), "rev": world.revision, "mode": world.mode}
	var seen: Array = []
	world.overlay_changed.connect(func(m): seen.append(m))
	for i in 7:
		world.cycle_overlay_mode()
		await tree.process_frame
	t.eq(seen.size(), 7)
	t.eq(world.overlay_mode, OverlayModel.Mode.LAYOUT, "7 steps of a 3-cycle")
	t.eq(world.selected_tile, before["tile"])
	t.eq(world._ghost, before["ghost"])
	t.eq(world.fixtures, before["fixtures"])
	t.eq(world.revision, before["rev"])
	t.eq(world.mode, before["mode"])
	world.set_overlay_mode(OverlayModel.Mode.NORMAL)
	t.eq(world.overlay_mode, OverlayModel.Mode.NORMAL)
	world.queue_free()
	await tree.process_frame


func test_all_overlay_modes_draw_at_every_zoom(t, tree) -> void:
	var world := _world(tree, [_inst("a", "shelf_general", 4, 5), _inst("b", "fridge_drink", 8, 5, 1), _inst("c", "freezer_ice", 11, 2), _inst("d", "register_basic", 3, 9)],
			[{"customer_id": "cust_000001", "tile": Vector2i(6, 6), "phase": "QUEUE"}], {"a": {"row0": 1}})
	for mode in [OverlayModel.Mode.LAYOUT, OverlayModel.Mode.INFO, OverlayModel.Mode.NORMAL]:
		world.set_overlay_mode(mode)
		for zoom in [0.5, 1.0, 2.0]:
			world.projection.set_zoom(zoom)
			world.get_node("OverlayLayer").queue_redraw()
			await tree.process_frame
	t.ok(true, "no draw errors")
	world.queue_free()
	await tree.process_frame


func test_overlapping_objects_can_be_picked_in_turn(t, tree) -> void:
	# A tall fridge at (6,5) hides the floor tile (5,4) behind it and a customer standing there.
	var world := _world(tree, [_inst("fr", "fridge_drink", 6, 5)], [{"customer_id": "cust_000002", "tile": Vector2i(5, 5), "phase": "QUEUE"}])
	var proj: IsoProjection = world.projection
	var on_sprite: Vector2 = proj.world_to_screen(6, 5, 1.2)   # the case's body, well above its own floor cell
	var cands: Array = world.pick_candidates(on_sprite)
	t.ok(cands.size() >= 2, "fixture and the floor behind it both answer: %s" % str(cands.map(func(c): return c["label"])))
	t.eq(cands[0]["kind"], "fixture", "frontmost first")
	t.eq(cands[cands.size() - 1]["kind"], "tile")
	world.primary_click(on_sprite)
	t.eq(world.selected_fixture_id(), "fr")
	var heard := {"labels": []}
	world.pick_candidates_changed.connect(func(l): heard["labels"] = l)
	world.primary_click(on_sprite)
	t.ok(world.selected_fixture_id() != "fr", "the second click moves on to the next object behind")
	var labels: Array = heard["labels"]
	t.ok(labels.size() >= 2 and labels.any(func(l): return l.begins_with("▶")), "the stack is listed")
	for i in cands.size() - 1:
		world.primary_click(on_sprite)
	t.eq(world.selected_fixture_id(), "fr", "it wraps around")
	world.queue_free()
	await tree.process_frame


func test_customer_is_selectable_and_cleared_when_gone(t, tree) -> void:
	var customer := {"customer_id": "cust_000003", "tile": Vector2i(10, 8), "phase": "WALK_SHELF", "next": Vector2i(10, 8), "progress": 0.0}
	var world := _world(tree, [], [customer])
	var point: Vector2 = world.projection.world_to_screen(10, 8, 0.8)
	world.primary_click(point)
	t.eq(world.selected_customer, "cust_000003")
	t.eq(world.selected_tile, World_NO_TILE, "a customer pick clears the tile selection")
	var snap := {"store_width": 20, "store_height": 12, "revision": 2, "entrance_tiles": [Vector2i(0, 5)] as Array[Vector2i], "fixtures": [], "customers": [], "shelf_stock": {}}
	world.apply_snapshot(snap)
	t.eq(world.selected_customer, "", "the customer left the store")
	world.queue_free()
	await tree.process_frame


const World_NO_TILE := Vector2i(-1, -1)


func test_things_in_front_of_the_selection_turn_see_through(t, tree) -> void:
	# fixture "front" at (7,5) is in front of "back" at (5,5) on screen; select the back one.
	var world := _world(tree, [_inst("back", "shelf_general", 5, 5), _inst("front", "fridge_drink", 6, 5)])
	var presenter: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	for it in presenter.compose():
		t.ok(not it.get("fade", false), "nothing is faded without a selection")
	world.select_screen(world.projection.tile_center(Vector2i(5, 5)))
	var faded := {}
	for it in presenter.compose():
		if it.get("fade", false):
			faded[it["inst"]["instance_id"]] = true
	t.ok(faded.has("front") and not faded.has("back"), "the case in front fades, the selected one stays solid: %s" % str(faded))
	world.queue_free()
	await tree.process_frame


func test_hidden_customer_gets_an_xray_copy(t, tree) -> void:
	var customers := [{"customer_id": "cust_000004", "tile": Vector2i(5, 5), "phase": "QUEUE"}, {"customer_id": "cust_000005", "tile": Vector2i(9, 9), "phase": "QUEUE"}]
	var world := _world(tree, [_inst("fr", "fridge_drink", 6, 5)], customers)
	var presenter: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	var hidden: Array = presenter.hidden_customers(presenter.compose())
	var ids := hidden.map(func(it): return it["customer"]["customer_id"])
	t.ok(ids.has("cust_000004"), "the one behind the case is hidden")
	t.ok(not ids.has("cust_000005"), "the one in the open is not")
	world.queue_free()
	await tree.process_frame


func test_sales_per_fixture_come_from_the_ledger(t, _tree) -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, _fixtures(), pr)
	t.ok(s.ledger.record("SALE", "s1", 150, s.day, 10, {"reservation_id": "r", "sku_id": "drink_001", "qty": 2, "fixture_id": "fx_0001"}, {"revenue": 300, "cogs": 150}))
	t.ok(s.ledger.record("SALE", "s2", 150, s.day, 20, {"reservation_id": "r2", "sku_id": "drink_001", "qty": 1, "fixture_id": "fx_0002"}, {"revenue": 150, "cogs": 75}))
	t.ok(s.ledger.record("SALE", "s3", 150, s.day, 30, {"reservation_id": "r3", "sku_id": "drink_001", "qty": 1, "fixture_id": "fx_0001"}, {"revenue": 150, "cogs": 75}))
	t.eq(s.fixture_sales_today(), {"fx_0001": 3, "fx_0002": 1})
	t.eq(s.snapshot()["fixture_sales"], {"fx_0001": 3, "fx_0002": 1})
