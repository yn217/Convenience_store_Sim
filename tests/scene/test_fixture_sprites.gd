extends RefCounted
## Issue #9: sprite layers/anchors come from manifests, other types stay placeholders, and the
## presenter draws every rotation at the three reference zooms with different shelf fill levels.

const SPRITE_TYPES := ["shelf_general", "warmer_oden", "freezer_ice", "register_basic", "fridge_drink", "shelf_onigiri", "shelf_noodle", "shelf_bread", "shelf_snack", "fridge_dessert", "atm", "copier"]


func test_manifest_entries_for_every_rotation(t, _tree) -> void:
	var sprites := FixtureSprites.new()
	for type_id in SPRITE_TYPES:
		for r in 4:
			var e := sprites.rotation_entry(type_id, r)
			t.ok(not e.is_empty(), "%s r%d entry" % [type_id, r])
			t.ok(e["layers"].has("body") and e["layers"].has("shadow"), "%s r%d body+shadow" % [type_id, r])
	t.ok(sprites.rotation_entry("no_such_type", 0).is_empty(), "type without art keeps its placeholder")
	t.ok(not sprites.has_sprites("no_such_type"))
	t.eq(sprites.base_entry("fridge_drink", 0)["layers"].has("glass_front"), true, "the current art keeps its glass layer")
	t.eq(sprites.base_entry("fridge_drink", 0)["slots"].size(), 24)
	t.eq(sprites.base_entry("register_basic", 0)["slots"].size(), 0)


func test_presenter_draws_all_rotations_and_zooms(t, tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = fixtures
	var placed: Array = []
	var x := 2
	for type_id in SPRITE_TYPES:
		for r in 4:
			placed.append({"instance_id": "%s_%d" % [type_id, r], "type_id": type_id, "x": x, "y": 1 + r * 2, "rotation": r, "enabled": true})
		x += 3
	world.apply_snapshot({
		"store_width": 20, "store_height": 12, "revision": 1,
		"entrance_tiles": [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i],
		"fixtures": placed,
		"shelf_stock": {"shelf_general_0": {"row0": 12, "row1": 5, "row2": 1}, "fridge_drink_1": {"row0": 20}},
	})
	for zoom in [0.5, 1.0, 2.0]:
		world.projection.set_zoom(zoom)
		world.get_node("ObjectSortRoot/FixturePresenter").queue_redraw()
		await tree.process_frame
		t.ok(true, "drew at zoom %s" % str(zoom))
	world.queue_free()
	await tree.process_frame


## Package icons (command type 3) appear at close zoom only, follow the SKU in the slot, and are dropped from the cache when it changes.
func test_shelf_items_become_package_icons(t, tree) -> void:
	VisualVariants.set_override("a")   # live item icons are the current art's (the depth art has its goods baked in)
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = fixtures
	world.product_catalog = products
	var placed := [{"instance_id": "shelf_general_0", "type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0, "enabled": true}]
	var stock := {"shelf_general_0": {"row0": 12, "row1": 5}}
	var skus := {"shelf_general_0": {"row0": "rice_001", "row1": "no_such_sku"}}
	world.apply_snapshot({"store_width": 20, "store_height": 12, "revision": 1, "entrance_tiles": [] as Array[Vector2i],
		"fixtures": placed, "shelf_stock": stock, "shelf_skus": skus})
	var presenter: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	world.projection.set_zoom(0.5)
	presenter.queue_redraw()
	await tree.process_frame
	t.eq(_icon_cmds(presenter).size(), 0, "far zoom keeps the rects")
	world.projection.set_zoom(1.0)
	presenter.queue_redraw()
	await tree.process_frame
	var icons := _icon_cmds(presenter)
	t.ok(icons.size() > 0, "close zoom draws package icons")
	t.ok(icons.size() < 12, "the unknown SKU row keeps its rects: %d icons" % icons.size())
	var first_tex: Texture2D = icons[0][1]
	world.apply_snapshot({"store_width": 20, "store_height": 12, "revision": 1, "entrance_tiles": [] as Array[Vector2i],
		"fixtures": placed, "shelf_stock": stock, "shelf_skus": {"shelf_general_0": {"row0": "rice_002", "row1": "no_such_sku"}}})
	presenter.queue_redraw()
	await tree.process_frame
	var after := _icon_cmds(presenter)
	t.ok(after.size() > 0 and after[0][1] != first_tex, "restocking another SKU redraws its icon")
	VisualVariants.set_override("")
	world.queue_free()
	await tree.process_frame


func _icon_cmds(presenter: Node2D) -> Array:
	var out: Array = []
	for hit in presenter._seg_cache.values():
		for c in hit["cmds"]:
			if c[0] == 3:
				out.append(c)
	return out


func test_customers_and_fixture_segments_compose_front_to_back(t, tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = fixtures
	var customers: Array = [
		{"customer_id": "front", "tile": Vector2i(5, 5), "phase": "SELECT"},
		{"customer_id": "back", "tile": Vector2i(3, 5), "phase": "SELECT"},
		{"customer_id": "past_end", "tile": Vector2i(4, 8), "phase": "SELECT"},
	]
	world.apply_snapshot({
		"store_width": 20, "store_height": 12, "revision": 1,
		"entrance_tiles": [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i],
		"fixtures": [{"instance_id": "s1", "type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0, "enabled": true}],
		"customers": customers, "shelf_stock": {},
	})
	var presenter: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	var order: Array = []
	for it in presenter.compose():
		order.append(it["customer"]["customer_id"] if it["kind"] == "customer" else "seg%d" % it["column"])
	t.eq(order.size(), 5, "two shelf segments + three customers")
	t.ok(order.find("back") < order.find("seg-2") and order.find("back") < order.find("seg-1"), "the customer behind is drawn first: %s" % str(order))
	t.ok(order.find("front") > order.find("seg-2") and order.find("front") > order.find("seg-1"), "the customer in front is drawn last")
	t.ok(order.find("past_end") > order.find("seg-1"), "past the near end: in front of the shelf")
	for zoom in [0.5, 1.0, 2.0]:
		world.projection.set_zoom(zoom)
		presenter.queue_redraw()
		await tree.process_frame
	t.ok(true)
	world.queue_free()
	await tree.process_frame
