extends RefCounted
## Issue #113: checkout-area dressing (RegisterDecor). The back counter and its appliances stay behind the register and
## never on a walkable cell, the tile behind the register stays free, queue markings and the sticker sit on the queue
## cells, and the counter-top items stay on the register. Covers all four rotations.

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


func _sprites(items: Array) -> Array:
	return items.filter(func(it): return it["kind"] == &"sprite")


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


## Every back-side draw position of one register: the appliance ground points and the counter box centres.
func _back_positions(p: Dictionary, w: int, h: int) -> Array:
	var out: Array = []
	for s in _sprites(RegisterDecor.appliance_items([p], w, h)):
		out.append(Vector2(s["x"], s["y"]))
	var counter := _polys(RegisterDecor.back_items([p], w, h))
	for i in range(0, counter.size(), 3):
		out.append(_centre(counter[i]["points"]))
	return out


func test_no_register_no_decor(t, _tree) -> void:
	var cat := _catalog()
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_BACK, W, H, ENTR, [], cat).size(), 0, "no counter without a register")
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_FLOOR, W, H, ENTR, [], cat).size(), 0, "no queue marks without a register")
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_TOP, W, H, ENTR, [], cat).size(), 0, "no counter items without a register")
	t.eq(RegisterDecor.layer_items(StoreDecor.LAYER_REG_TOP, W, H, ENTR, [_fixture("r", REG, 5, 4, 0)], null).size(), 0, "no decor without a catalog")


func test_disabled_register_gets_no_decor(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0, false)])
	t.eq(plans.size(), 0, "a switched-off register is not dressed")


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


func test_back_counter_is_behind_the_register_for_every_rotation(t, _tree) -> void:
	for rot in 4:
		var plans := _plans([_fixture("r", REG, 5, 4, rot)])
		var p: Dictionary = plans[0]
		t.eq(_sprites(RegisterDecor.appliance_items(plans, W, H)).size(), RegisterDecor.BACK_APPLIANCES.size(), "three appliances for rotation %d" % rot)
		t.eq(_polys(RegisterDecor.back_items(plans, W, H)).size(), 3, "one counter box (top and two faces) for rotation %d" % rot)
		var centre := _centre(_cells_points(p["cells"]))
		for g in _back_positions(p, W, H):
			t.ok((g - centre).dot(Vector2(p["back"])) > 0.0, "back item stands behind the register (rotation %d)" % rot)


func test_back_items_never_land_on_a_walkable_cell(t, _tree) -> void:
	# A register in the middle of the floor (strip mode), one against the west wall (wall mode), and one with a shelf
	# right behind it (strip mode, the shelf is not walkable). Every back item must be off the store or on a fixture cell.
	var layouts := [
		[_fixture("r", REG, 5, 4, 0)],
		[_fixture("r", REG, 0, 4, 0)],
		[_fixture("r", REG, 0, 4, 2)],
		[_fixture("r", REG, 5, 4, 1)],
		[_fixture("r", REG, 5, 4, 0), _fixture("s", "shelf_general", 4, 4, 0)],
	]
	var cat := _catalog()
	for fixtures in layouts:
		var occupied := StoreDecor.occupied_cells(fixtures, cat)
		for g in _back_positions(_plans(fixtures)[0], W, H):
			var c := _cell_of(g)
			t.ok(not _in_store(c, W, H) or occupied.has(c), "back item at %s is off the walkable floor" % str(c))


func test_clerk_tile_behind_the_register_stays_free(t, _tree) -> void:
	# Strip mode: the tile directly behind the register (the clerk's cashier position, #104) gets nothing.
	for rot in 4:
		var p: Dictionary = _plans([_fixture("r", REG, 5, 4, rot)])[0]
		var behind: Vector2i = p["cells"][0] + p["back"]
		t.ok(_in_store(behind, W, H), "the tile behind is on the floor (rotation %d)" % rot)
		for g in _back_positions(p, W, H):
			t.ok(_cell_of(g) != behind, "nothing on the clerk tile for rotation %d" % rot)


func test_wall_register_puts_the_counter_on_the_wall_line(t, _tree) -> void:
	var p: Dictionary = _plans([_fixture("r", REG, 0, 4, 0)])[0]
	for g in _back_positions(p, W, H):
		t.ok(not _in_store(_cell_of(g), W, H), "the counter and appliances stand off the store against the west wall")
	var box := _polys(RegisterDecor.back_items([p], W, H))
	for pt in box[0]["points"]:
		t.ok(pt.x <= 0.0 + 1e-6, "the counter box stays on the wall side of the front edge of the store")


func test_counter_is_a_box_with_a_top_and_front_faces(t, _tree) -> void:
	var p: Dictionary = _plans([_fixture("r", REG, 5, 4, 0)])[0]
	var faces := _polys(RegisterDecor.back_items([p], W, H))
	t.eq(faces.size(), 3, "top plus two front faces")
	var top := -INF
	for pt in faces[1]["points"]:
		top = maxf(top, pt.z)
	t.ok(absf(top - RegisterDecor.COUNTER_H) < 1e-6, "the front face rises to the counter height")
	t.ok(faces[0]["color"] == RegisterDecor.COUNTER_SHADES[0], "the top face uses the top shade")


func test_queue_marks_sit_on_the_queue_cells(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var queue: Array = plans[0]["queue"]
	t.ok(queue.size() >= 1, "the register forms a queue line")
	var marks := RegisterDecor.floor_items(plans).filter(func(it): return it["kind"] == &"poly" and it["color"] == RegisterDecor.MARK_COLOR)
	t.eq(marks.size(), queue.size() * 4, "four bars per queue cell")
	var seen := {}
	for m in marks:
		var c := _cell_of(_centre(m["points"]))
		t.ok(queue.has(c), "mark centre %s is a queue cell" % str(c))
		seen[c] = true
	t.eq(seen.size(), queue.size(), "every queue cell gets a mark")


func test_sticker_and_label_only_on_the_first_queue_cell(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var queue: Array = plans[0]["queue"]
	var texts := RegisterDecor.floor_items(plans).filter(func(it): return it["kind"] == &"text")
	t.eq(texts.size(), 1, "one raised label per line")
	t.eq(texts[0]["text"], RegisterDecor.SIGN_TEXT, "the label reads the guidance text")
	var at: Vector3 = texts[0]["at"]
	t.eq(_cell_of(Vector2(at.x, at.y)), queue[0], "the label is on the head of the line")
	var stickers := _polys(RegisterDecor.floor_items(plans)).filter(func(it): return it["color"] == RegisterDecor.SIGN_FILL)
	t.eq(stickers.size(), 1, "one sticker")
	var c := _cell_of(_centre(stickers[0]["points"]))
	t.eq(c, queue[0], "the sticker lies on the first queue cell only")
	var size_x := absf(stickers[0]["points"][1].x - stickers[0]["points"][0].x)
	t.ok(absf(size_x - 0.6) < 1e-6, "the sticker is 0.6 tile wide")


func test_sign_is_not_on_a_fixture(t, _tree) -> void:
	var fixtures := [_fixture("r", REG, 5, 4, 0), _fixture("s", "shelf_general", 7, 4, 0)]
	var cat := _catalog()
	var occupied := StoreDecor.occupied_cells(fixtures, cat)
	for it in RegisterDecor.floor_items(_plans(fixtures)):
		if it["kind"] == &"text":
			var at: Vector3 = it["at"]
			t.ok(not occupied.has(_cell_of(Vector2(at.x, at.y))), "the label is not on a fixture")


func test_counter_top_items_stay_on_the_register(t, _tree) -> void:
	var plans := _plans([_fixture("r", REG, 5, 4, 0)])
	var top: float = plans[0]["top"]
	var items := RegisterDecor.top_items(plans)
	t.eq(items.size(), RegisterDecor.TOP_BOXES.size() * 3, "three faces per counter-top box")
	for it in items:
		for p in it["points"]:
			t.ok(p.z >= top - 1e-6, "counter items rise from the register top")
			t.ok(p.x >= 4.5 - 1e-6 and p.x <= 5.5 + 1e-6 and p.y >= 3.5 - 1e-6 and p.y <= 5.5 + 1e-6, "counter items stay within the register footprint")


func test_appliances_stand_on_the_counter_top(t, _tree) -> void:
	for s in _sprites(RegisterDecor.appliance_items(_plans([_fixture("r", REG, 5, 4, 0)]), W, H)):
		t.ok(absf(float(s["z"]) - RegisterDecor.COUNTER_H) < 1e-6, "%s stands at the counter height" % s["id"])


func test_layouts_are_deterministic(t, _tree) -> void:
	var fixtures := [_fixture("r", REG, 5, 4, 1), _fixture("r2", REG, 8, 6, 3)]
	var cat := _catalog()
	for which in [StoreDecor.LAYER_REG_BACK, StoreDecor.LAYER_REG_FLOOR, StoreDecor.LAYER_REG_TOP]:
		var a := RegisterDecor.layer_items(which, W, H, ENTR, fixtures, cat)
		var b := RegisterDecor.layer_items(which, W, H, ENTR, fixtures, cat)
		t.ok(a == b, "layer %d gives the same items twice" % which)
	t.eq(RegisterDecor.register_plans(W, H, ENTR, fixtures, cat).size(), 2, "both registers are planned")


func test_appliances_have_art_for_their_rotation(t, _tree) -> void:
	var loader := PropSprites.new()
	for rot in 4:
		for id in RegisterDecor.BACK_APPLIANCES:
			t.ok(not loader.texture(id, rot).is_empty(), "%s has art for rotation %d" % [id, rot])


func _cells_points(cells: Array) -> Array:
	var out: Array = []
	for c in cells:
		out.append(Vector3(c.x, c.y, 0.0))
	return out
