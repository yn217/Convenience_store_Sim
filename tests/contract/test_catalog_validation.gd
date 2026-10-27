extends RefCounted
## Issue #3: valid/invalid table-driven catalog tests + semantic checks on the real masters.

const PRODUCTS := "res://data/products/mvp_v1.json"
const FIXTURES := "res://data/fixtures/mvp_v1.json"


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _product(over: Dictionary = {}) -> Dictionary:
	var p := {
		"schema_version": 1, "sku_id": "tea_001", "display_name": "お茶", "category": "drink",
		"purchase_cost_yen": 75, "default_sell_price_yen": 120, "expires_after_seconds": null,
		"demand_weight": 1.0, "visual_id": "tea_001_package", "slot_units": 1,
	}
	p.merge(over, true)
	return p


func _fixture(over: Dictionary = {}) -> Dictionary:
	var f := {
		"schema_version": 1, "type_id": "shelf_test", "display_name": "棚",
		"footprint": {"w": 1, "h": 2}, "dimensions_m": {"width": 0.92, "depth": 1.92, "height": 1.5},
		"placement_cost_yen": 1000, "electricity_cost_yen_per_day": 0, "capacity_units": 10,
		"allowed_categories": ["drink"], "access_edges": ["E"], "visual_id": "shelf_test_a",
		"shelf_slots": [
			{"slot_id": "row0", "capacity_units": 4, "allowed_categories": ["drink"]},
			{"slot_id": "row1", "capacity_units": 6, "allowed_categories": ["drink"]},
		],
	}
	f.merge(over, true)
	return f


func test_real_masters_load_and_cross_reference(t, _tree) -> void:
	var products := ProductCatalog.from_json_text(_text(PRODUCTS))
	var fixtures := FixtureCatalog.from_json_text(_text(FIXTURES))
	t.eq(products.errors, [] as Array[String], "products errors")
	t.eq(fixtures.errors, [] as Array[String], "fixtures errors")
	t.eq(products.skus.size(), 44, "44 SKUs (33 + 2 volume-up onigiri, #137, + 3 capsule series, #139, + 6 goods and hygiene, #133)")
	t.eq(fixtures.types.size(), 21, "21 fixture types (3 capsule machines, #139; the goods shelf, #133)")
	t.eq(fixtures.product_errors(products), [] as Array[String], "every SKU has a compatible slot")
	var cats := {}
	for s in products.skus.values():
		cats[s["category"]] = int(cats.get(s["category"], 0)) + 1
	t.eq(cats.size(), 14, "14 categories (bento, daily fresh, coffee: #147; capsule toys: #139; daily goods, hygiene: #133)")
	for c in cats:
		t.eq(cats[c], 5 if c == "rice_ball" else 3, "3 SKUs in %s (+2 volume-up onigiri, #137)" % c)


func test_product_invalid_table(t, _tree) -> void:
	var cases := [
		["negative cost", _product({"purchase_cost_yen": -1}), "purchase_cost_yen: negative"],
		["fractional cost", _product({"purchase_cost_yen": 7.5}), "purchase_cost_yen: not_integer"],
		["zero price", _product({"default_sell_price_yen": 0}), "default_sell_price_yen: below_minimum"],
		["negative price", _product({"default_sell_price_yen": -10}), "default_sell_price_yen: below_minimum"],
		["unknown category", _product({"category": "frozen_pizza"}), "category: unknown_category"],
		["zero slot units", _product({"slot_units": 0}), "slot_units: below_minimum"],
		["bad id", _product({"sku_id": "Tea 1"}), "sku_id: invalid_id"],
		["bad expiry", _product({"expires_after_seconds": 0}), "expires_after_seconds: below_minimum"],
		["negative demand", _product({"demand_weight": -0.1}), "demand_weight: negative"],
		["future version", _product({"schema_version": 2}), "schema_version: unsupported_schema_version"],
		["bool as int", _product({"slot_units": true}), "slot_units: not_integer"],
	]
	for c in cases:
		var cat := ProductCatalog.from_array([c[1]])
		t.ok(not cat.is_valid(), c[0] + " rejected")
		t.ok(cat.errors.any(func(e): return e.ends_with(c[2])), "%s -> %s (got %s)" % [c[0], c[2], str(cat.errors)])
		t.eq(cat.skus.size(), 0, c[0] + " not registered")


func test_product_missing_unknown_and_duplicate(t, _tree) -> void:
	var missing := _product()
	missing.erase("category")
	t.ok(not ProductCatalog.from_array([missing]).is_valid(), "missing field")
	t.ok(not ProductCatalog.from_array([_product({"extra": 1})]).is_valid(), "unknown field")
	var dup := ProductCatalog.from_array([_product(), _product({"display_name": "別"})])
	t.ok(dup.errors.any(func(e): return e.ends_with("sku_id: duplicate_id")), "duplicate id")
	t.eq(dup.skus.size(), 1, "first kept, duplicate rejected")
	t.ok(ProductCatalog.from_array({}).errors.size() == 1, "root must be array")
	t.ok(not ProductCatalog.from_json_text("{oops").is_valid(), "invalid json")


func test_product_future_version_is_flagged(t, _tree) -> void:
	var cat := ProductCatalog.from_array([_product({"schema_version": 2})])
	t.ok(cat.future_schema_version, "future schema_version identified")
	t.ok(not ProductCatalog.from_array([_product()]).future_schema_version, "v1 is current")


func test_float_integers_from_json_are_accepted(t, _tree) -> void:
	var cat := ProductCatalog.from_json_text(JSON.stringify([_product()]))
	t.ok(cat.is_valid(), "JSON round trip valid")
	t.eq(typeof(cat.get_sku("tea_001")["purchase_cost_yen"]), TYPE_INT, "money normalized to int")


func test_fixture_invalid_table(t, _tree) -> void:
	var slot_ok := {"slot_id": "row0", "capacity_units": 10, "allowed_categories": ["drink"]}
	var cases := [
		["capacity not sum", _fixture({"capacity_units": 11}), "capacity_units: not_sum_of_slots"],
		["too wide for footprint", _fixture({"dimensions_m": {"width": 0.95, "depth": 1.92, "height": 1.5}}), "dimensions_m: exceeds_footprint"],
		["too deep for footprint", _fixture({"dimensions_m": {"width": 0.92, "depth": 1.95, "height": 1.5}}), "dimensions_m: exceeds_footprint"],
		["negative cost", _fixture({"placement_cost_yen": -1}), "placement_cost_yen: negative"],
		["unknown category", _fixture({"allowed_categories": ["pizza"]}), "unknown_category"],
		["slot category outside fixture", _fixture({"allowed_categories": ["snack"]}), "not_in_fixture_categories"],
		["duplicate slot id", _fixture({"shelf_slots": [slot_ok, slot_ok], "capacity_units": 20}), "slot_id: duplicate_id"],
		["unknown edge", _fixture({"access_edges": ["X"]}), "access_edges: unknown_edge"],
		["zero footprint", _fixture({"footprint": {"w": 0, "h": 2}}), "footprint: invalid"],
		["future version", _fixture({"schema_version": 3}), "schema_version: unsupported_schema_version"],
	]
	for c in cases:
		var cat := FixtureCatalog.from_array([c[1]])
		t.ok(not cat.is_valid(), c[0] + " rejected")
		t.ok(cat.errors.any(func(e): return e.ends_with(c[2])), "%s -> %s (got %s)" % [c[0], c[2], str(cat.errors)])
		t.eq(cat.types.size(), 0, c[0] + " not registered")
	t.ok(FixtureCatalog.from_array([_fixture(), _fixture()]).errors.any(func(e): return e.ends_with("type_id: duplicate_id")), "duplicate type id")
	t.ok(FixtureCatalog.from_array([_fixture()]).is_valid(), "baseline fixture valid")


func test_product_without_compatible_slot_is_reported(t, _tree) -> void:
	var fixtures := FixtureCatalog.from_array([_fixture()])
	var products := ProductCatalog.from_array([_product({"category": "snack", "sku_id": "snk_x"}), _product({"slot_units": 7, "sku_id": "big_x"})])
	var errs := fixtures.product_errors(products)
	t.eq(errs.size(), 2, "snack has no fixture; slot_units 7 exceeds largest slot (6)")


func test_real_fixture_golden_values(t, _tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(_text(FIXTURES))
	var fridge := fixtures.get_type("fridge_drink")
	t.eq(fridge["footprint"], {"w": 1, "h": 2}, "fridge footprint")
	t.eq(fridge["access_edges"], ["E"], "1x2 fridge access E")
	t.eq(fixtures.get_type("freezer_ice")["footprint"], {"w": 2, "h": 2}, "ice 2x2")
	t.eq(fixtures.get_type("register_basic")["capacity_units"], 0, "register has no stock capacity")
