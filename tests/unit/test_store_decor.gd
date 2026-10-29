extends RefCounted
## Issue #110: storefront and exterior decoration layout. Which tiles get which prop, and that nothing lands on
## the walkable floor or the entrance. The prop loader and the sync cache are covered at the end.

const W := 16
const H := 12
const ENTR := [Vector2i(0, 5), Vector2i(0, 6)]          ## west door: the storefront-wall tests below use it
const SOUTH_ENTR := [Vector2i(8, 11), Vector2i(9, 11)]  ## the new-game door (south wall)


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
	var canopy_names := StoreDecor.canopy_items(W, H, SOUTH_ENTR).filter(func(it): return it["kind"] == &"text" and it["text"] == StoreDecor.NAME)
	t.eq(canopy_names.size(), 1, "the observe canopy repeats the storefront name once")
	t.eq(canopy_names[0]["font_px"], 32, "the storefront name is sized for fascia readability")


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


func test_low_front_glass_reflections_stay_inside_closed_panes(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, SOUTH_ENTR, {})
	var reflections := items.filter(func(it): return it.get("role", &"") == &"glass_reflection")
	t.ok(not reflections.is_empty(), "cut-away shopfront glazing catches subtle reflected light")
	for reflection in reflections:
		for point in reflection["points"]:
			t.ok(point.z > StoreDecor.SILL_H and point.z < StoreDecor.NEAR_FRAME_TOP, "reflection stays on the pane above the sill")
			t.ok(point.x <= 7.5 or point.x >= 9.5, "reflection at x=%0.2f does not cross the south entrance opening" % point.x)


func test_near_entrance_uses_recessed_sliding_leaves_with_clear_center(t, _tree) -> void:
	var items := StoreDecor.wall_items(W, H, SOUTH_ENTR, {})
	var leaves := items.filter(func(it): return it.get("role", &"") == &"door_leaf_glass")
	var safety_bands := items.filter(func(it): return it.get("role", &"") == &"door_safety_band")
	t.eq(leaves.size(), 2, "the near entrance has two transparent sliding leaves")
	t.eq(safety_bands.size(), 2, "each leaf has one subtle visibility band")
	var spans: Array[Vector2] = []
	for leaf in leaves:
		var lo := INF
		var hi := -INF
		var min_z := INF
		var max_z := -INF
		for point in leaf["points"]:
			lo = minf(lo, point.x)
			hi = maxf(hi, point.x)
			min_z = minf(min_z, point.z)
			max_z = maxf(max_z, point.z)
		spans.append(Vector2(lo, hi))
		t.ok(min_z >= 0.079 and max_z < StoreDecor.NEAR_FRAME_TOP, "glass leaves stay within the entrance frame")
	spans.sort_custom(func(a, b): return a.x < b.x)
	t.ok(spans[1].x - spans[0].y >= 0.69, "the central customer route stays visibly clear")


func test_observe_canopy_adds_transparent_full_height_glazing(t, _tree) -> void:
	var items := StoreDecor.canopy_items(W, H, SOUTH_ENTR)
	var panes := items.filter(func(it): return it.get("role", &"") == &"glazing_pane")
	var reflections := items.filter(func(it): return it.get("role", &"") == &"glazing_reflection")
	t.eq(panes.size(), W - SOUTH_ENTR.size(), "every closed frontage tile receives a glass pane")
	t.ok(not reflections.is_empty(), "some panes catch a subtle reflection")
	for pane in panes:
		var min_z := INF
		var max_z := -INF
		for point in pane["points"]:
			min_z = minf(min_z, point.z)
			max_z = maxf(max_z, point.z)
		t.ok(min_z > StoreDecor.SILL_H and max_z == 2.25, "transparent glazing reaches close to the fascia")
		t.ok(float(pane["color"].a) < 0.1, "interior remains legible through the glass")


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
		if it["kind"] == &"sprite":
			t.ok(not _inside_floor(it, W, H), "exterior %s stands outside the store" % it["id"])
		elif it["kind"] == &"poly":
			for p in it["points"]:
				t.ok(p.x <= -0.5 or p.x >= W - 0.5 or p.y <= -0.5 or p.y >= H - 0.5, "markings stay outside walkable floor")


func test_exterior_has_the_street_furniture(t, _tree) -> void:
	# Default door on the south wall: the whole street set is placed in front of the storefront.
	var items := StoreDecor.exterior_items(W, H, SOUTH_ENTR)
	for id in ["open_a_board", "vending_painted_v1", "trash_recycle_bins", "bicycle_rack_painted_v1", "bench_painted_v1", "nobori_banner_obento", "street_lamp", "flower_planter_painted_v1"]:
		t.ok(_sprites(items, id).size() > 0, "%s is placed" % id)
	t.eq(_sprites(items, "green_street_tree_v1").size() + _sprites(items, "cherry_tree_painted_v1").size(), 0, "temporary individual trees are replaced by the combined backdrop")
	t.eq(_sprites(items, "parked_car_blue").size() + _sprites(items, "parked_car_red").size(), 0, "legacy side-view cars are not used")


func test_pole_sign_lists_store_services_on_separate_panels(t, _tree) -> void:
	var items := StoreDecor.exterior_items(W, H, SOUTH_ENTR)
	var sign_text := items.filter(func(it): return it["kind"] == &"text" and ["たばこ", "酒", "ATM"].has(it["text"]))
	t.eq(sign_text.map(func(it): return it["text"]), ["たばこ", "酒", "ATM"], "pole sign presents separate service panels in vertical order")
	for label in sign_text:
		t.eq(label["font_px"], 16, "service lettering is legible at full-scene camera fit")


func test_parking_lot_is_on_the_entrance_side(t, _tree) -> void:
	# Static parking lines and wheel stops belong to the combined Area A image; StoreDecor only places dynamic cars.
	for side in [ENTR, SOUTH_ENTR]:
		var items := StoreDecor.exterior_items(W, H, side)
		var markings := items.filter(func(it): return it.get("role", "") == "parking")
		var cars := items.filter(func(it): return it.get("role", "") == "parked_vehicle")
		t.eq(markings.size(), 0, "static parking paint is not redrawn over the combined background")
		t.eq(cars.size(), 1 if side == SOUTH_ENTR else 0, "a projected car remains separate from the background art")
		for car in cars:
			var depth: float = -0.5 - car["x"] if side == ENTR else car["y"] - (H - 0.5)
			var along: float = car["y"] if side == ENTR else car["x"]
			t.ok(depth >= 2.0 and depth <= 7.0, "parked car stays within the parking depth")
			t.ok(along < BackdropLayer.entrance_span(BackdropLayer.entrance_side(W, H, side), W, H, side).x, "parked car clears the doorway approach")


func test_outer_road_vehicle_tracks_entrance_side_without_blocking_crossing(t, _tree) -> void:
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_length := float(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var middle := int(edge_length / 2.0)
			var entrance: Vector2i
			match side:
				BackdropLayer.SIDE_WEST:
					entrance = Vector2i(0, middle)
				BackdropLayer.SIDE_NORTH:
					entrance = Vector2i(middle, 0)
				BackdropLayer.SIDE_EAST:
					entrance = Vector2i(size.x - 1, middle)
				_:
					entrance = Vector2i(middle, size.y - 1)
			var items := StoreDecor.exterior_items(size.x, size.y, [entrance])
			var cars := items.filter(func(it): return it.get("role", "") == "road_vehicle")
			t.eq(cars.size(), 1, "one outer-lane car exists for %dx%d side %d" % [size.x, size.y, side])
			var car: Dictionary = cars[0]
			t.eq(car["id"], "compact_car_painted_v2", "outer car uses the detailed compact model")
			t.eq(car["rot"], 0 if side == BackdropLayer.SIDE_NORTH or side == BackdropLayer.SIDE_SOUTH else 1, "car aligns to the road axis on side %d" % side)
			var depth := -0.5 - float(car["x"]) if side == BackdropLayer.SIDE_WEST else float(car["x"]) - (float(size.x) - 0.5) if side == BackdropLayer.SIDE_EAST else -0.5 - float(car["y"]) if side == BackdropLayer.SIDE_NORTH else float(car["y"]) - (float(size.y) - 0.5)
			var along := float(car["y"]) if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else float(car["x"])
			t.ok(depth >= BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M and depth <= BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M, "outer car sits on the road surface")
			t.ok(absf(along - float(middle)) > 2.4, "outer car body stays clear of the crosswalk approach")


func test_front_items_are_on_the_near_sides(t, _tree) -> void:
	var landscape_side := BackdropLayer.landscape_side(BackdropLayer.entrance_side(W, H, ENTR))
	for it in StoreDecor.exterior_items(W, H, ENTR):
		if it["front"] and it["kind"] == &"sprite":
			t.ok(it["x"] >= W - 0.5 or it["y"] >= H - 0.5, "%s is drawn over the floor only on a near side" % it["id"])
	var all_planters := _sprites(StoreDecor.exterior_items(W, H, ENTR), "flower_planter_painted_v1")
	t.eq(all_planters.size(), 5, "the selected combined side has no duplicate standalone planters")


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

func test_large_store_equipment_does_not_overlap_planter(t, _tree) -> void:
	var items := StoreDecor.exterior_items(20, 16, [Vector2i(8, 15)])
	var equipment := Vector2.ZERO
	var found := false
	for item in items:
		if item.get("id", "") == "exterior_hvac_v1":
			equipment = Vector2(item["x"], item["y"])
			found = true
	t.ok(found, "large store has exterior equipment")
	for item in items:
		if item.get("id", "") == "flower_planter_painted_v1":
			var point := Vector2(item["x"], item["y"])
			t.ok(point.distance_to(equipment) >= 1.5, "planters leave room around equipment")

func test_east_entrance_places_equipment_on_south_side(t, _tree) -> void:
	var items := StoreDecor.exterior_items(16, 12, [Vector2i(15, 5)])
	var found := false
	for item in items:
		if item.get("id", "") == "exterior_hvac_v1":
			found = true
			t.ok(float(item["y"]) > 11.5, "equipment remains outside the south wall")
			t.ok(item.get("mirror", false), "equipment is mirrored for the south side")
	t.ok(found, "east entrance still has equipment")
