extends RefCounted
## Issue #113: checkout-area dressing (RegisterDecor), scoped down: queue markings and the floor sticker on the queue
## cells, and counter-top items inside the register's top face. The clerk tile behind the register stays free.
## Covers all four rotations.

const W := 12
const H := 10
const ENTR := [Vector2i(0, 9)]   ## a south-west door: the registers below are reachable from it
const REG := "register_basic"


func _catalog() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))


func _fixture(id: String, type_id: String, x: int, y: int, rot: int, enabled: bool = true) -> Dictionary:
	return {"instance_id": id, "type_id": type_id, "x": x, "y": y, "rotation": rot, "enabled": enabled}


func _plans(fixtures: Array, w: int = W, h: int = H) -> Array:
	return RegisterDecor.register_plans(w, h, ENTR, fixtures, _catalog())


func _polys(items: Array) -> Array:
	return items.filter(func(it): return it["kind"] == &"poly")


func _in_store(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func _centre(points: Array) -> Vector2:
	var s := Vector2.ZERO
	for p in points:
		s += Vector2(p.x, p.y)
	return s / points.size()


func _cell_of(g: Vector2) -> Vector2i:
	return Vector2i(roundi(g.x), roundi(g.y))


func test_no_register_no_decor(t, _tree) -> void:
	var cat := _catalog()
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_FLOOR, W, H, ENTR, [], cat).size(), 0, "no queue marks without a register")
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_TOP, W, H, ENTR, [], cat).size(), 0, "no counter items without a register")
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_TOP, W, H, ENTR, [_fixture("r", REG, 5, 4, 0)], null).size(), 0, "no decor without a catalog")


func test_disabled_register_gets_no_decor(t, _tree) -> void:
	t.eq(_plans([_fixture("r", REG, 5, 4, 0, false)]).size(), 0, "a switched-off register is not dressed")


func test_plan_is_derived_from_the_rotated_access_edge(t, _tree) -> void:
	# The register's access edge is E; rotation r turns it N, E, S, W (rotate_edge). The back is the opposite side.
	var expected := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	for rot in 4:
		var plans := _plans([_fixture("r", REG, 5, 4, rot)])
		t.eq(plans.size(), 1, "one plan for rotation %d" % rot)
		var p: Dictionary = plans[0]
		t.eq(p["access"], expected[rot], "access normal for rotation %d" % rot)
		t.eq(p["back"], -expected[rot], "back is opposite the access for rotation %d" % rot)
		t.ok(p["cells"].has(p["queue"][0] - p["access"]) if not p["queue"].is_empty() else false,
			"the queue head is the cell in front of the footprint for rotation %d" % rot)


func test_clerk_tile_behind_the_register_stays_free(t, _tree) -> void:
	# The tile directly behind the register (the clerk's cashier position, #104) gets no decor.
	var cat := _catalog()
	for rot in 4:
		var fixtures := [_fixture("r", REG, 5, 4, rot)]
		var p: Dictionary = _plans(fixtures)[0]
		var behind: Vector2i = p["cells"][0] + p["back"]
		t.ok(_in_store(behind, W, H), "the tile behind is on the floor (rotation %d)" % rot)
		for it in RegisterDecor.layer_items(StoreDecor.LAYER_REG_FLOOR, W, H, ENTR, fixtures, cat) + RegisterDecor.layer_items(StoreDecor.LAYER_REG_TOP, W, H, ENTR, fixtures, cat):
			var pts: Array = it["points"] if it["kind"] == &"poly" else [it["at"]]
			t.ok(_cell_of(_centre(pts)) != behind, "nothing on the clerk tile for rotation %d" % rot)


func test_queue_marks_sit_on_the_queue_cells(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var queue: Array = plans[0]["queue"]
	t.ok(queue.size() >= 1, "the register forms a queue line")
	var marks := _polys(RegisterDecor.floor_items(plans)).filter(func(it): return it["color"] == RegisterDecor.MARK_COLOR)
	t.eq(marks.size(), queue.size() * 4, "four bars per queue cell")
	var seen := {}
	for m in marks:
		var c := _cell_of(_centre(m["points"]))
		t.ok(queue.has(c), "mark centre %s is a queue cell" % str(c))
		seen[c] = true
	t.eq(seen.size(), queue.size(), "every queue cell gets a mark")


func test_sticker_with_footprint_icon_on_the_first_queue_cell(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var queue: Array = plans[0]["queue"]
	var floor := RegisterDecor.floor_items(plans)
	t.eq(floor.filter(func(it): return it["kind"] == &"text").size(), 0, "no text on the floor sticker")
	var stickers := _polys(floor).filter(func(it): return it["color"] == RegisterDecor.SIGN_FILL)
	t.eq(stickers.size(), 1, "one sticker per line")
	t.eq(_cell_of(_centre(stickers[0]["points"])), queue[0], "the sticker lies on the first queue cell only")
	t.ok(absf(stickers[0]["points"][1].x - stickers[0]["points"][0].x - 0.6) < 1e-6, "the sticker is 0.6 tile wide")
	var icons := _polys(floor).filter(func(it): return it["color"] == RegisterDecor.SIGN_ICON)
	t.eq(icons.size(), 2, "two footprint marks on the sticker")
	for ic in icons:
		t.eq(_cell_of(_centre(ic["points"])), queue[0], "the footprint mark lies on the sticker cell")


func test_counter_top_items_stay_on_the_top_face(t, _tree) -> void:
	# Register at (5,4), rotation 0: the top face is x in [4.5, 5.5], y in [3.5, 5.5] (one tile across, two along).
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var top: float = plans[0]["top"]
	var items := RegisterDecor.top_items(plans)
	t.eq(items.size(), RegisterDecor.TOP_BOXES.size() * 3, "three faces per counter-top box")
	for it in items:
		for p in it["points"]:
			t.ok(p.z >= top - 1e-6, "counter items rise from the register top")
			t.ok(p.x >= 4.5 - 1e-6 and p.x <= 5.5 + 1e-6 and p.y >= 3.5 - 1e-6 and p.y <= 5.5 + 1e-6, "counter items stay on the top face")


func test_layouts_are_deterministic(t, _tree) -> void:
	var fixtures := [_fixture("r", REG, 5, 4, 1), _fixture("r2", REG, 8, 6, 3)]
	var cat := _catalog()
	for which in [StoreDecor.LAYER_REG_FLOOR, StoreDecor.LAYER_REG_TOP]:
		var a := RegisterDecor.layer_items(which, W, H, ENTR, fixtures, cat)
		var b := RegisterDecor.layer_items(which, W, H, ENTR, fixtures, cat)
		t.ok(a == b, "layer %d gives the same items twice" % which)
	t.eq(RegisterDecor.register_plans(W, H, ENTR, fixtures, cat).size(), 2, "both registers are planned")
