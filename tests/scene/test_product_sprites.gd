extends RefCounted
## Product shape manifest and overlay-plan contract.


func test_product_manifest_loads_all_visuals(t, _tree) -> void:
	var products := ProductSprites.new()
	t.eq(products.visual_count(), 24, "24 product visual IDs")
	var e := products.entry("drink_001_package", 0)
	t.ok(not e.is_empty(), "known product visual loads")
	t.eq(e["shape_id"], "bottle_500", "drink uses bottle shape")
	t.ok(e["texture"] != null, "product texture loads")
	t.ok(products.entry("unknown_product", 0).is_empty(), "unknown product falls back")


func test_product_overlay_plan_follows_lod(t, _tree) -> void:
	var fixtures := FixtureSprites.new()
	var products := ProductSprites.new()
	var entry := fixtures.rotation_entry("shelf_general", 0)
	var empty := ProductOverlayPlan.build(entry, "snack_001_package", 0, 20, 1.0, products)
	t.eq(empty["items"].size(), 0, "empty row has no products")
	var low := ProductOverlayPlan.build(entry, "snack_001_package", 5, 20, 1.0, products)
	t.eq(low["items"].size(), 2, "low row has two products")
	var medium := ProductOverlayPlan.build(entry, "snack_001_package", 10, 20, 1.0, products)
	# zoom 1.0 is the "few" LOD, which caps visible items at 4 (ShelfDisplay, test_shelf_display.gd).
	t.eq(medium["items"].size(), 4, "few LOD at zoom 1.0 caps the medium row at four products")
	var full := ProductOverlayPlan.build(entry, "snack_001_package", 20, 20, 2.0, products, 3)
	t.eq(full["items"].size(), 8, "near full row has eight products")
	var far := ProductOverlayPlan.build(entry, "snack_001_package", 20, 20, 0.5, products)
	t.eq(far["lod"], "bar", "far row uses bar LOD")
	t.eq(far["items"].size(), 0, "far row does not draw individual products")
