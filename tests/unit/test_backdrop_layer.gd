extends RefCounted
## Street backdrop around the store: pure geometry (entrance side, paving, apron, mats) and the cache key.


func _proj(zoom: float = 1.0) -> IsoProjection:
	var p := IsoProjection.new()
	p.origin = Vector2(900, 200)
	p.set_zoom(zoom)
	return p


func _count(items: Array, color: Color) -> int:
	var n := 0
	for it in items:
		if it["kind"] == &"poly" and it["color"] == color:
			n += 1
	return n


func _all_finite(items: Array) -> bool:
	for it in items:
		if it.has("points"):
			for pt in it["points"]:
				if not (is_finite(pt.x) and is_finite(pt.y)):
					return false
		if it.has("pos") and not (is_finite(it["pos"].x) and is_finite(it["pos"].y)):
			return false
	return true


func test_no_backdrop_for_empty_store(t, _tree) -> void:
	var items := BackdropLayer.layout_items(_proj(), 0, 0, [], Vector2(1280, 720))
	t.eq(items.size(), 0, "no street without a floor")


func test_entrance_side_detection(t, _tree) -> void:
	t.eq(BackdropLayer.entrance_side(16, 12, [Vector2i(0, 5), Vector2i(0, 6)]), BackdropLayer.SIDE_WEST, "x = 0 is the west side")
	t.eq(BackdropLayer.entrance_side(16, 12, [Vector2i(3, 0)]), BackdropLayer.SIDE_NORTH, "y = 0 is the north side")
	t.eq(BackdropLayer.entrance_side(16, 12, [Vector2i(15, 4)]), BackdropLayer.SIDE_EAST, "x = W - 1 is the east side")
	t.eq(BackdropLayer.entrance_side(16, 12, [Vector2i(4, 11)]), BackdropLayer.SIDE_SOUTH, "y = H - 1 is the south side")
	t.eq(BackdropLayer.entrance_side(16, 12, []), BackdropLayer.SIDE_WEST, "west when there is no entrance")


func test_entrance_span_covers_entrance_tiles(t, _tree) -> void:
	var span := BackdropLayer.entrance_span(BackdropLayer.SIDE_WEST, 16, 12, [Vector2i(0, 5), Vector2i(0, 6)])
	t.ok(absf(span.x - 4.5) < 1e-6 and absf(span.y - 6.5) < 1e-6, "span runs from 4.5 to 6.5 along the west edge")


func test_side_point_moves_outward(t, _tree) -> void:
	var w := BackdropLayer.side_point(BackdropLayer.SIDE_WEST, 1.0, 5.0, 16, 12)
	t.ok(absf(w.x - (-1.5)) < 1e-6 and absf(w.y - 5.0) < 1e-6, "one metre west of the west edge")
	var s := BackdropLayer.side_point(BackdropLayer.SIDE_SOUTH, 2.0, 3.0, 16, 12)
	t.ok(absf(s.x - 3.0) < 1e-6 and absf(s.y - 13.5) < 1e-6, "two metres south of the south edge")


func test_paving_ring_and_apron_colours_present(t, _tree) -> void:
	var items := BackdropLayer.layout_items(_proj(), 16, 12, [Vector2i(0, 5), Vector2i(0, 6)], Vector2(1280, 720))
	t.ok(_count(items, BackdropLayer.PAVE) + _count(items, BackdropLayer.PAVE_ALT) > 0, "paving slabs are drawn")
	t.eq(_count(items, BackdropLayer.APRON), 1, "one apron on the entrance side")
	t.eq(_count(items, BackdropLayer.MAT), 2, "one door mat per entrance tile")
	t.eq(_count(items, BackdropLayer.ROAD), 1, "one road strip on the entrance side")


func test_slabs_only_outside_the_store(t, _tree) -> void:
	var items := BackdropLayer.layout_items(_proj(), 4, 3, [], Vector2(1280, 720))
	# Ring of width 2 around a 4x3 footprint: (4 + 4) * (3 + 4) - 4 * 3 = 44 slabs, each a pale paving colour.
	var slabs := _count(items, BackdropLayer.PAVE) + _count(items, BackdropLayer.PAVE_ALT)
	t.eq(slabs, 44, "one slab per tile in the paving ring and none under the store")


func test_vignette_and_ground_are_screen_space(t, _tree) -> void:
	var vp := Vector2(1280, 720)
	var items := BackdropLayer.layout_items(_proj(), 16, 12, [], vp)
	var grads := 0
	for it in items:
		if it["kind"] == &"gradient":
			grads += 1
	t.eq(grads, 4, "vignette is four gradient quads")
	t.ok(_all_finite(items), "every point is finite")
	t.eq(items[0]["points"][2], vp, "the ground fill covers the whole viewport")


func test_layout_is_deterministic_and_camera_dependent(t, _tree) -> void:
	var a := BackdropLayer.layout_items(_proj(1.0), 16, 12, [Vector2i(0, 5)], Vector2(1280, 720))
	var b := BackdropLayer.layout_items(_proj(1.0), 16, 12, [Vector2i(0, 5)], Vector2(1280, 720))
	t.eq(a.size(), b.size(), "same inputs give the same number of pieces")
	t.ok(a[10]["points"] == b[10]["points"], "same inputs give the same points")
	var c := BackdropLayer.layout_items(_proj(2.0), 16, 12, [Vector2i(0, 5)], Vector2(1280, 720))
	t.ok(a[10]["points"] != c[10]["points"], "zoom changes the screen geometry")


func test_combined_environment_tracks_the_projected_store_bounds(t, _tree) -> void:
	var proj := _proj(1.25)
	var rect := BackdropLayer.environment_rect(proj, 16, 12)
	var texture_size := Vector2(BackdropLayer.ExteriorBackdrop.get_size())
	var scale := rect.size.x / texture_size.x
	var image_apex := rect.position + BackdropLayer.BACKDROP_APEX_PX * scale
	var wall_apex := proj.world_to_screen(-0.5, -0.5, IsoProjection.WALL_HEIGHT_M - BackdropLayer.BACKDROP_WALL_OCCLUSION_M)
	t.ok(image_apex.distance_to(wall_apex) < 0.001, "the scenery apex follows the far-wall junction behind the wall")
	t.ok(absf(rect.size.y / texture_size.y - scale) < 0.001, "the background is scaled uniformly")
	t.ok(rect.size.x > proj.floor_bounds(16, 12).size.x, "the scenery reaches both far-wall ends")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/backgrounds/store_exterior_backdrop_v1/store_exterior_backdrop_v1.visual.json"))
	var measured_apex := Vector2(float(metadata["pivot_x"]), float(metadata["pivot_y"]))
	t.ok(measured_apex.distance_to(BackdropLayer.BACKDROP_APEX_PX) < 0.001, "the runtime anchor matches the packaged image")
	var slopes: Array = metadata["runtime_fit"]["edge_slopes"]
	t.ok(absf(float(slopes[0]) + 0.5) < 0.01 and absf(float(slopes[1]) - 0.5) < 0.01, "both scenery edges match the far-wall angles")
	proj.pan(Vector2(29, -13))
	var moved := BackdropLayer.environment_rect(proj, 16, 12)
	t.eq(moved.position, rect.position + Vector2(29, -13), "camera panning moves the scenery with the store")


func test_sync_caches_until_the_key_changes(t, _tree) -> void:
	var layer := BackdropLayer.new()
	var vp := Vector2(1280, 720)
	layer.sync(16, 12, [Vector2i(0, 5)], _proj(1.0), vp)
	var first: Array = layer._ops
	layer.sync(16, 12, [Vector2i(0, 5)], _proj(1.0), vp)
	t.ok(layer._ops == first, "an unchanged key keeps the cached pieces")
	layer.sync(16, 12, [Vector2i(0, 5)], _proj(2.0), vp)
	t.ok(layer._ops != first, "a camera change rebuilds the pieces")
	layer.free()
