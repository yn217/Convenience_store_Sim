extends RefCounted
## Pure helpers of the shelf product sprites: facing, size from dimensions_m, LOD, stock state, variation.


func test_direction_follows_fixture_rotation(t, _tree) -> void:
	for r in 4:
		t.eq(ProductSprites.direction_for(r, 0, false), r, "asymmetric shape faces the fixture rotation %d" % r)
		t.eq(ProductSprites.direction_for(r, 1, false), r, "asymmetric shape ignores the facing variant")
	t.eq(ProductSprites.direction_for(5, 0, false), 1, "rotation wraps modulo 4")
	t.eq(ProductSprites.direction_for(-1, 0, false), 3, "negative rotation wraps")


func test_symmetric_shape_alternates_between_opposite_facings(t, _tree) -> void:
	t.eq(ProductSprites.direction_for(0, 0, true), 0, "symmetric variant 0 faces the rotation")
	t.eq(ProductSprites.direction_for(0, 1, true), 2, "symmetric variant 1 faces the opposite side")
	t.eq(ProductSprites.direction_for(3, 1, true), 1, "opposite side wraps modulo 4")
	t.eq(ProductSprites.direction_for(1, 2, true), 1, "variant is taken modulo 2")


func test_screen_size_follows_height_in_metres(t, _tree) -> void:
	var bottle := {"size": Vector2(40, 130), "height_m": 0.225}
	var onigiri := {"size": Vector2(60, 60), "height_m": 0.095}
	var b := ProductSprites.screen_size(bottle, 1.0)
	var o := ProductSprites.screen_size(onigiri, 1.0)
	t.ok(b.y > o.y * 2.0, "500 ml bottle is more than twice the onigiri height")
	t.ok(absf(b.y - 0.225 * ProductSprites.ITEM_SCALE * IsoProjection.Z_PX_PER_M) < 0.01, "drawn height is height_m scaled to pixels")
	t.ok(absf(b.x / b.y - 40.0 / 130.0) < 0.001, "uniform scale keeps the crop aspect ratio")
	t.ok(absf(ProductSprites.screen_size(bottle, 2.0).y - b.y * 2.0) < 0.01, "size grows linearly with zoom")
	t.ok(ProductSprites.screen_size({"size": Vector2.ZERO, "height_m": 0.1}, 1.0) == Vector2.ZERO, "empty crop has no size")


func test_sprite_lod_bands(t, _tree) -> void:
	t.eq(ProductSprites.sprite_lod(0.5), "bar", "far zoom is the bar LOD")
	t.eq(ProductSprites.sprite_lod(0.8), "small", "between the bar cut-off and 0.9 uses small sprites")
	t.eq(ProductSprites.sprite_lod(0.9), "full", "0.9 and above uses full sprites")
	t.eq(ProductSprites.sprite_lod(2.0), "full", "close zoom uses full sprites")


func test_stock_state_matches_shelf_counts(t, _tree) -> void:
	t.eq(ProductSprites.stock_state(0, 12), "empty", "no stock is the empty picture")
	t.eq(ProductSprites.stock_state(2, 12), "low", "one sixth of a row is low")
	t.eq(ProductSprites.stock_state(6, 12), "medium", "half a row is medium")
	t.eq(ProductSprites.stock_state(12, 12), "full", "a full row is full")
	t.eq(ProductSprites.stock_state(9, 0), "empty", "a row without capacity is empty")


func test_variation_is_deterministic_and_bounded(t, _tree) -> void:
	for i in 8:
		t.eq(ProductSprites.variant_for("shelf_a_slot", i), ProductSprites.variant_for("shelf_a_slot", i), "variant is stable")
		var j := ProductSprites.jitter_px("shelf_a_slot", i)
		t.ok(j >= -1.0 and j <= 1.0, "jitter stays within one pixel")
		t.eq(j, ProductSprites.jitter_px("shelf_a_slot", i), "jitter is stable across calls")
	var seen := {}
	for i in 8:
		seen[ProductSprites.variant_for("shelf_a_slot", i)] = true
	t.eq(seen.size(), 2, "consecutive items alternate between two facings")
	var rice := {}
	for sku in ["rice_001", "rice_002", "rice_003"]:
		rice[ProductSprites.tint_for(sku, "rice_ball")] = true
	t.eq(rice.size(), 3, "the three SKUs of one category get three different tints")
	t.eq(ProductSprites.tint_for("rice_001", "rice_ball"), ProductSprites.tint_for("rice_001", "rice_ball"), "tint is stable per SKU")
	t.ok(ProductSprites.tint_for("dessert_001", "dessert") != ProductSprites.tint_for("noodle_001", "instant_noodle"), "cups of different categories differ in tint")
	t.eq(ProductSprites.tint_for("x", "unknown_category"), ProductSprites.tint_for("x", ""), "unknown category falls back to a neutral tint")


func test_manifest_sprite_cache_returns_same_texture(t, _tree) -> void:
	var products := ProductSprites.new()
	var a := products.sprite("drink_001_package", 1)
	var b := products.sprite("drink_001_package", 1)
	t.ok(not a.is_empty(), "known visual gives a sprite")
	t.ok(a["texture"] == b["texture"], "repeated lookup reuses the cached texture")
	t.eq(a["shape_id"], "bottle_500", "drink uses the bottle shape")
	t.ok(a["size"].y > 0.0 and float(a["height_m"]) > 0.0, "crop size and height are loaded")
	t.ok(products.sprite("unknown_product", 0).is_empty(), "unknown visual has no sprite")
