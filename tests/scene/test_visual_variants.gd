extends RefCounted
## Visual variants in the presenter: a baked-products variant (painted FULL, issue #91) draws its sprite layers
## only, the base variant keeps the items on top, and the dev override toggle reloads the sprite entries.

const PresenterScript := preload("res://scripts/presentation/fixture_presenter.gd")


func _world(tree: SceneTree) -> Node2D:   # awaits a frame: the presenter's _ready must have run before compose()
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = fixtures
	world.apply_snapshot({
		"store_width": 20, "store_height": 12, "revision": 1,
		"entrance_tiles": [] as Array[Vector2i],
		"fixtures": [{"instance_id": "fridge_drink_0", "type_id": "fridge_drink", "x": 4, "y": 5, "rotation": 0, "enabled": true}],
		"shelf_stock": {"fridge_drink_0": {"row0": 20, "row1": 12}},
	})
	await tree.process_frame
	return world


func test_baked_entry_skips_item_drawing(t, tree) -> void:
	var world: Node2D = await _world(tree)
	var presenter: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	var it := {}
	for item in presenter.compose():
		if item["kind"] == "fixture" and item["inst"]["type_id"] == "fridge_drink":
			it = item
	t.ok(not it.is_empty(), "fridge_drink is composed")
	var proj: IsoProjection = world.projection
	proj.set_zoom(1.0)
	var ground := proj.world_to_screen(it["lo"].x, it["lo"].y)
	var stock: Dictionary = world.shelf_stock.get("fridge_drink_0", {})
	var skus: Dictionary = world.shelf_skus.get("fridge_drink_0", {})
	var entry: Dictionary = FixtureSprites.new().base_entry("fridge_drink", 0)
	t.ok(not entry.is_empty(), "base fridge_drink sprites load")
	t.ok(not bool(entry.get("baked", true)), "base variant is not baked")
	t.ok(PresenterScript.draws_products(entry), "base variant keeps the item drawing")

	var plain: Array = []
	presenter._emit_sprite(proj, it, entry, ground, stock, skus, plain)
	var baked_entry := entry.duplicate()
	baked_entry["baked"] = true
	t.ok(not PresenterScript.draws_products(baked_entry), "baked variant skips the item drawing")
	var baked: Array = []
	presenter._emit_sprite(proj, it, baked_entry, ground, stock, skus, baked)
	t.ok(baked.size() > 0, "baked variant still draws its layers")
	t.ok(baked.size() < plain.size(), "baked variant draws fewer commands: %d < %d" % [baked.size(), plain.size()])
	var only_layers := true
	for c in baked:
		if c[0] != 0:
			only_layers = false
	t.ok(only_layers, "baked variant draws texture layers only, no items, rects or price tags")
	world.queue_free()
	await tree.process_frame


func test_variant_switch_reloads_the_sprite_entries(t, tree) -> void:
	var sprites := FixtureSprites.new()
	var before := VisualVariants.generation
	t.ok(not sprites.refresh(), "nothing changed: no reload")
	VisualVariants.set_test_images(not VisualVariants.test_images())
	t.eq(VisualVariants.generation, before + 1, "the override change bumps the generation")
	t.ok(sprites.refresh(), "the sprites reload after the switch")
	t.ok(not sprites.refresh(), "and only once")
	VisualVariants.set_test_images(not VisualVariants.test_images())
	t.ok(sprites.refresh(), "switching back reloads again")
	t.eq(sprites.rotation_entry("fridge_drink", 0)["variant"], "depth_v1", "the approved depth art is in use (2026-11-14)")
	await tree.process_frame
