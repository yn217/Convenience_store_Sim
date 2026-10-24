extends RefCounted
## Issue #110: storefront and exterior decoration layout. Which tiles get which prop, and that nothing lands on
## the walkable floor or the entrance. The prop loader and the sync cache are covered at the end.

const W := 16
const H := 12
const ENTR := [Vector2i(0, 5), Vector2i(0, 6)]


func _proj(zoom: float = 1.0) -> IsoProjection:
	var p := IsoProjection.new()
	p.origin = Vector2(1000, 200)
	p.set_zoom(zoom)
	return p


func _sprites(items: Array, id: String = "") -> Array:
	return items.filter(func(it): return it["kind"] == &"sprite" and (id == "" or it["id"] == id))


func _inside_floor(it: Dictionary, w: int, h: int) -> bool:
	return it["x"] > -0.5 and it["x"] < w - 0.5 and it["y"] > -0.5 and it["y"] < h - 0.5


func test_empty_store_has_no_items(t, _tree) -> void:
	t.eq(StoreDecor.wall_items(0, 0, [], {}).size(), 0, "no wall items without a floor")
	t.eq(StoreDecor.exterior_items(0, 0, []).size(), 0, "no exterior items without a floor")


func test_doors_on_the_entrance_tiles(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, ENTR, {})
	var doors := _sprites(items, "storefront_door")
	t.eq(doors.size(), 2, "one door per entrance tile")
	for d in doors:
		t.ok(absf(d["x"] + 1.0) < 1e-6, "door stands one tile outside the west wall")
		t.ok(d["y"] == 5.0 or d["y"] == 6.0, "door sits on an entrance row")


func test_windows_and_piers_fill_the_rest_of_the_front(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, ENTR, {})
	t.eq(_sprites(items, "storefront_window").size(), H - 2 - ENTR.size(), "glass on every other tile of the front")
	t.eq(_sprites(items, "storefront_wall").size(), 2, "storefront piers at both ends")


func test_fascia_and_store_name_above_the_glass(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, ENTR, {})
	var bands := items.filter(func(it): return it["kind"] == &"poly" and it["color"] == StoreDecor.FASCIA)
	t.eq(bands.size(), 1, "one fascia band over the front")
	for p in bands[0]["points"]:
		t.ok(absf(p.z - StoreDecor.FASCIA_Z0) < 1e-5 or absf(p.z - StoreDecor.FASCIA_Z1) < 1e-5, "fascia sits between the sign heights")
	var names := items.filter(func(it): return it["kind"] == &"text" and it["text"] == StoreDecor.NAME)
	t.eq(names.size(), 1, "the fictional store name is drawn once")


func test_cooler_row_on_the_back_wall_only(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, ENTR, {})
	var coolers := _sprites(items, "reachin_cooler_row")
	t.eq(coolers.size(), StoreDecor.COOLER_COUNT, "six reach-in coolers on the north back wall")
	for c in coolers:
		t.ok(absf(c["y"] - StoreDecor.WALL_OFFSET) < 1e-6, "coolers stand behind the north wall")
		t.ok(c["x"] >= StoreDecor.COOLER_START and c["x"] < W - 1, "coolers are not in the corners")
		t.ok(not _inside_floor(c, W, H), "coolers never stand on the floor")


func test_plants_skip_an_occupied_corner(t, _tree) -> void:
	var free := StoreDecor.wall_items(W, H, ENTR, {})
	t.eq(_sprites(free, "potted_plant_small").size(), 1, "small plant in the free west corner")
	t.eq(_sprites(free, "potted_plant_large").size(), 1, "large plant in the free east corner")
	var blocked := StoreDecor.wall_items(W, H, ENTR, {Vector2i(0, 0): true})
	t.eq(_sprites(blocked, "potted_plant_small").size(), 0, "no plant when a fixture stands in the corner")
	t.eq(_sprites(blocked, "potted_plant_large").size(), 1, "the other corner keeps its plant")


func test_entrance_on_north_moves_the_storefront(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, [Vector2i(3, 0)], {})
	var doors := _sprites(items, "storefront_door")
	t.eq(doors.size(), 1, "one door on the north wall")
	t.ok(absf(doors[0]["y"] + 1.0) < 1e-6 and doors[0]["x"] == 3.0, "door stands one tile outside north at x = 3")
	var coolers := _sprites(items, "reachin_cooler_row")
	t.eq(coolers.size(), StoreDecor.COOLER_COUNT, "coolers move to the west back wall")
	for c in coolers:
		t.ok(absf(c["x"] - StoreDecor.WALL_OFFSET) < 1e-6, "coolers stand behind the west wall")


func test_entrance_on_east_is_a_low_front(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, [Vector2i(W - 1, 4)], {})
	t.eq(_sprites(items, "storefront_window").size(), 0, "no full-height glass on a near side")
	t.eq(_sprites(items, "storefront_door").size(), 0, "the near entrance stays open")
	var sills := items.filter(func(it): return it["kind"] == &"poly" and it["color"] == StoreDecor.SILL)
	t.ok(sills.size() > 0, "sill bands are drawn")
	for s in sills:
		var top := -INF
		for p in s["points"]:
			top = maxf(top, p.z)
		t.ok(top <= StoreDecor.SILL_H + 1e-6, "sills stay under the sill height")


func test_wall_items_never_land_on_the_floor(t, _tree) -> void:
	var layouts := [
		[W, H, ENTR], [W, H, [Vector2i(3, 0)]], [W, H, [Vector2i(W - 1, 4)]], [W, H, [Vector2i(5, H - 1)]], [5, 4, [Vector2i(0, 1)]],
	]
	for l in layouts:
		for it in StoreDecor.wall_items(l[0], l[1], l[2], {}):
			if it["kind"] == &"sprite":
				t.ok(not _inside_floor(it, l[0], l[1]), "wall prop %s stays off the floor" % it["id"])


func test_exterior_is_outside_the_store_and_deterministic(t, _tree) -> void:
	var a := StoreDecor.exterior_items(W, H, ENTR)
	var b := StoreDecor.exterior_items(W, H, ENTR)
	t.eq(a.size(), b.size(), "same inputs give the same number of items")
	t.ok(a == b, "same inputs give the same items")
	for it in a:
		t.ok(not _inside_floor(it, W, H), "exterior %s stands outside the store" % it["id"])


func test_exterior_has_the_street_furniture(t, _tree) -> void:
	var items := StoreDecor.exterior_items(W, H, ENTR)
	for id in ["open_a_board", "vending_machine", "trash_recycle_bins", "bicycle_stand", "bench", "nobori_banner_obento", "pole_sign", "street_lamp", "parking_lot_straight", "car_stop_bollard", "parked_car_blue", "cherry_tree_a", "flower_bed_planter", "potted_plant_large"]:
		t.ok(_sprites(items, id).size() > 0, "%s is placed" % id)
	t.eq(_sprites(items, "parked_car_blue").size() + _sprites(items, "parked_car_red").size(), 2, "two parked cars")


func test_parking_lot_is_on_the_side_after_the_entrance(t, _tree) -> void:
	# West entrance: the lot goes on the north side (y < -0.5), in front of the back wall and the store's paving.
	for it in _sprites(StoreDecor.exterior_items(W, H, ENTR), "parking_lot_straight"):
		t.ok(it["y"] < -0.5, "parking tiles lie north of the store")


func test_front_items_are_on_the_near_sides(t, _tree) -> void:
	for it in StoreDecor.exterior_items(W, H, ENTR):
		if it["front"]:
			t.ok(it["x"] >= W - 0.5 or it["y"] >= H - 0.5, "%s is drawn over the floor only on a near side" % it["id"])


func test_prop_loader_reads_the_manifest_and_skips_missing_props(t, _tree) -> void:
	var loader := PropSprites.new()
	var entry := loader.texture("storefront_wall")
	t.ok(not entry.is_empty(), "storefront_wall loads")
	t.ok(entry["anchor"] == Vector2(160, 210), "anchor is the ground point at the bottom centre")
	t.ok(entry["size"] == Vector2(320, 320), "canvas is 320 px")
	t.ok(entry["layers"].size() >= 1, "at least the body layer")
	t.ok(loader.texture("no_such_prop").is_empty(), "missing props return {} so they are skipped")
	t.ok(not PropSprites.is_available("no_such_prop"), "missing manifests are reported")


func test_sync_caches_until_the_key_changes(t, _tree) -> void:
	var decor := StoreDecor.new()
	decor.layer = StoreDecor.LAYER_WALL
	decor.sync(W, H, ENTR, [], null, _proj(), Vector2(1280, 720))
	var first := decor._ops.duplicate()
	t.ok(decor.op_count() > 0, "the wall layer builds draw ops")
	decor.sync(W, H, ENTR, [], null, _proj(), Vector2(1280, 720))
	t.ok(decor._ops == first, "an unchanged key keeps the cached ops")
	decor.sync(W, H, ENTR, [], null, _proj(1.6), Vector2(1280, 720))
	t.ok(decor._ops != first, "a camera change rebuilds the ops")
	decor.free()
