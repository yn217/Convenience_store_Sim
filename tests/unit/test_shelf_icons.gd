extends RefCounted
const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
## Shelf items become package icons only at close zoom, and a slot's SKU is looked up from the snapshot map.


func test_icons_only_at_close_zoom(t, _tree) -> void:
	t.ok(not Presenter.use_icons(0.5), "far: rects")
	t.ok(not Presenter.use_icons(0.89), "just under the threshold: rects")
	t.ok(Presenter.use_icons(0.9), "threshold: icons")
	t.ok(Presenter.use_icons(1.0), "default fit zoom: icons")
	t.ok(Presenter.use_icons(2.0), "near: icons")


func test_sku_lookup_in_slot(t, _tree) -> void:
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var per_slot := {"row0": "rice_001", "row1": "no_such_sku"}
	var sku := Presenter.sku_in_slot(per_slot, "row0", products)
	t.eq(sku.get("sku_id", ""), "rice_001", "known SKU in the slot")
	t.ok(Presenter.sku_in_slot(per_slot, "row1", products).is_empty(), "unknown SKU falls back to a rect")
	t.ok(Presenter.sku_in_slot(per_slot, "row2", products).is_empty(), "empty slot falls back to a rect")
	t.ok(Presenter.sku_in_slot(per_slot, "row0", null).is_empty(), "no catalog falls back to a rect")
