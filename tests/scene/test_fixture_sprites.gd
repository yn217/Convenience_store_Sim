extends RefCounted
## Issue #9: sprite layers/anchors come from manifests, other types stay placeholders, and the
## presenter draws every rotation at the three reference zooms with different shelf fill levels.

const SPRITE_TYPES := ["shelf_general", "warmer_oden", "freezer_ice", "register_basic", "fridge_drink", "shelf_onigiri", "shelf_noodle", "shelf_bread", "shelf_snack", "fridge_dessert"]


func test_manifest_entries_for_every_rotation(t, _tree) -> void:
	var sprites := FixtureSprites.new()
	for type_id in SPRITE_TYPES:
		for r in 4:
			var e := sprites.rotation_entry(type_id, r)
			t.ok(not e.is_empty(), "%s r%d entry" % [type_id, r])
			t.ok(e["layers"].has("body") and e["layers"].has("shadow"), "%s r%d body+shadow" % [type_id, r])
	t.ok(sprites.rotation_entry("no_such_type", 0).is_empty(), "type without art keeps its placeholder")
	t.ok(not sprites.has_sprites("no_such_type"))
	t.eq(sprites.rotation_entry("fridge_drink", 0)["layers"].has("glass_front"), true)
	t.eq(sprites.rotation_entry("fridge_drink", 0)["slots"].size(), 24)
	t.eq(sprites.rotation_entry("register_basic", 0)["slots"].size(), 0)


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
