extends RefCounted
## Issue #147: bento, daily fresh (vegetables, tofu, milk) and counter coffee — products, the fixtures that hold
## them, the purposes that come for them (only when the store carries them), and their package icons.

const Run := preload("res://tests/support/basket_run.gd")
const NEW := ["bento", "daily_fresh", "coffee"]


func _catalogs() -> Array:
	return [FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json")),
		ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))]


func test_products_and_fixtures(t, _tree) -> void:
	var c := _catalogs()
	var fx: FixtureCatalog = c[0]
	var pr: ProductCatalog = c[1]
	t.ok(fx.errors.is_empty() and pr.errors.is_empty(), "the masters load: %s %s" % [fx.errors, pr.errors])
	for cat in NEW:
		var skus: Array = pr.skus.values().filter(func(s): return s["category"] == cat)
		t.eq(skus.size(), 3, "three %s SKUs" % cat)
		for s in skus:
			t.ok(int(s["default_sell_price_yen"]) > int(s["purchase_cost_yen"]), "%s sells above cost" % s["sku_id"])
	t.ok(fx.get_type("shelf_onigiri")["allowed_categories"].has("bento"), "bento goes on the onigiri shelf")
	t.ok(fx.get_type("fridge_daily")["allowed_categories"].has("daily_fresh"), "a chilled case for daily fresh")
	t.ok(fx.get_type("coffee_machine")["allowed_categories"].has("coffee"), "a coffee machine for counter coffee")
	t.ok(pr.get_sku("bento_001")["expires_after_seconds"] <= 43200, "a bento keeps half a day")


func test_purposes_need_their_goods(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var count := func(stocked: Array, hour: int, purpose: String, loc: String) -> int:
		var pick := Lcg32.new(77)
		var money := Lcg32.new(88)
		var n := 0
		for i in 2000:
			if VisitPurpose.draw(pick, money, hour, balance, loc, stocked)["purpose_id"] == purpose:
				n += 1
		return n
	var basic := ["bread", "drink", "rice_ball", "snack"]
	t.eq(int(count.call(basic, 8, "coffee_only", "office")), 0, "no coffee on the shelves: nobody comes just for coffee")
	t.ok(int(count.call(basic + ["coffee"], 8, "coffee_only", "office")) > 100, "with a coffee machine the office crowd comes for coffee")
	t.eq(int(count.call(basic, 17, "dinner_addon", "residential")), 0, "no daily fresh: no dinner shopping")
	t.ok(int(count.call(basic + ["daily_fresh"], 17, "dinner_addon", "residential")) > int(count.call(basic + ["daily_fresh"], 17, "dinner_addon", "office")), "dinner shopping is a residential thing")
	t.ok(int(count.call(basic, 15, "school_snack", "school")) > int(count.call(basic, 15, "school_snack", "office")), "after-school snacks by a school")


func test_lunch_boxes_sell_at_lunch_among_offices(t, _tree) -> void:
	var s := Run.new_state(200.0)
	var cmds := Run.place_layout(s)
	s.location_id = "office"
	# put bento in the onigiri shelves' last row
	var n := 0
	for id in s.grid.instances:
		if s.grid.instances[id]["type_id"] == "shelf_onigiri":
			n += 1
			cmds.execute({"command_id": "bo%d" % n, "kind": &"ORDER_STOCK", "sku_id": "bento_001", "qty": 12})
			cmds.execute({"command_id": "br%d" % n, "kind": &"RESTOCK", "instance_id": id, "slot_id": "row2", "sku_id": "bento_001", "qty": 12})
	var r := Run.run_days(s, cmds, 1)
	var bento := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["details"].get("sku_id", "")).begins_with("bento"):
			bento += int(tx["details"].get("qty", 1))
	t.ok(bento > 0, "bento sold: %d" % bento)


func test_package_icons(t, _tree) -> void:
	var pr: ProductCatalog = _catalogs()[1]
	for cat in NEW:
		var sku: Dictionary = pr.skus.values().filter(func(s): return s["category"] == cat)[0]
		var tex := ProductIcons.texture(sku, 32)
		t.ok(tex != null, "an icon for " + cat)
		if tex == null:
			continue
		var img := tex.get_image()
		var used := img.get_used_rect()
		t.ok(used.size.x > 10 and used.size.y > 10, "%s: the icon draws a shape (%s)" % [cat, used])
