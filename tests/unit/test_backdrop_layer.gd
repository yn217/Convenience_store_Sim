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
	var backdrop_texture := load("res://assets/generated/backgrounds/store_exterior_backdrop_v2/store_exterior_backdrop_v2.png") as Texture2D
	var layer := BackdropLayer.new()
	_tree.root.add_child(layer)
	layer.sync(16, 12, [], proj, Vector2(1280, 720))
	var transform: Transform2D = layer._environment_transform
	var ground := transform * BackdropLayer.BACKDROP_GROUND_PX
	t.ok(ground.distance_to(BackdropLayer.environment_ground_anchor(proj)) < 0.001, "planting base stays at the exterior ground anchor")
	t.ok(absf(transform.x.length() - transform.y.length()) < 0.001, "vegetation art keeps its proportions")
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		var size_transform := BackdropLayer.environment_transform(proj, size.x, size.y, Vector2(backdrop_texture.get_size()))
		var size_ground: Vector2 = size_transform * BackdropLayer.BACKDROP_GROUND_PX
		var left_endpoint: Vector2 = size_transform * BackdropLayer.BACKDROP_LEFT_END_PX
		var right_endpoint: Vector2 = size_transform * BackdropLayer.BACKDROP_RIGHT_END_PX
		var expected_left := proj.world_to_screen(-0.5 - BackdropLayer.BACKDROP_GROUND_OFFSET_M, float(size.y) - 0.5 + BackdropLayer.BACKDROP_GROUND_OFFSET_M)
		var expected_right := proj.world_to_screen(float(size.x) - 0.5 + BackdropLayer.BACKDROP_GROUND_OFFSET_M, -0.5 - BackdropLayer.BACKDROP_GROUND_OFFSET_M)
		var left_coverage := (left_endpoint - size_ground).dot(expected_left - size_ground) / (expected_left - size_ground).length()
		var right_coverage := (right_endpoint - size_ground).dot(expected_right - size_ground) / (expected_right - size_ground).length()
		t.ok(left_coverage >= (expected_left - size_ground).length() - 1.0, "left V endpoint covers %dx%d far wall" % [size.x, size.y])
		t.ok(right_coverage >= (expected_right - size_ground).length() - 1.0, "right V endpoint covers %dx%d far wall" % [size.x, size.y])
	proj.pan(Vector2(29, -13))
	layer.sync(16, 12, [], proj, Vector2(1280, 720))
	var moved_ground: Vector2 = layer._environment_transform * BackdropLayer.BACKDROP_GROUND_PX
	t.eq(moved_ground, ground + Vector2(29, -13), "camera panning moves the ground anchor with the store")
	layer.queue_free()


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

func test_roadside_tracks_entrance_and_camera(t, tree) -> void:
	var layer := BackdropLayer.new()
	tree.root.add_child(layer)
	var p := _proj()
	layer.sync(16, 12, [Vector2i(8, 11)], p, Vector2(1600, 900))
	var sprite: Sprite2D = layer._roadside_sprite
	var initial := sprite.position
	layer.sync(16, 12, [Vector2i(10, 11)], p, Vector2(1600, 900))
	t.ok(sprite.position.distance_to(initial + Vector2(128, 64)) < 0.01, "roadside placement follows a moved entrance")
	p.pan(Vector2(30, -10))
	layer.sync(16, 12, [Vector2i(10, 11)], p, Vector2(1600, 900))
	t.ok(sprite.position.distance_to(initial + Vector2(158, 54)) < 0.01, "roadside follows camera pan")
	layer.sync(16, 12, [Vector2i(0, 5)], p, Vector2(1600, 900))
	t.ok(sprite.scale.x < 0.0, "roadside mirrors to follow the other road angle")
	layer.queue_free()


func test_side_landscape_tracks_store_edge_and_camera(t, tree) -> void:
	var layer := BackdropLayer.new()
	tree.root.add_child(layer)
	var p := _proj()
	layer.sync(16, 12, [Vector2i(8, 11)], p, Vector2(1600, 900))
	var sprite: Sprite2D = layer._side_landscape_sprite
	t.ok(sprite.visible, "the combined sidewalk panel is shown for a supported store")
	var first := sprite.transform
	var east_corner := BackdropLayer.landscape_corner(BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_LANDSCAPE_DEPTH_M, 16, 12)
	t.eq(east_corner, Vector2(16.05, -0.5), "east strip root stays at the far wall with the requested setback")
	t.ok(first.x.x > 0.0, "the east-side panel follows the visible rear wall direction")
	var east_ground := BackdropLayer.SIDE_LANDSCAPE_GROUND_START_PX
	t.ok((first * east_ground).distance_to(p.world_to_screen(east_corner.x, east_corner.y)) < 0.01, "measured planter root is fixed behind the east wall at ground level")
	var shear := 0.5 - BackdropLayer.SIDE_LANDSCAPE_SOURCE_SLOPE
	var east_slope := BackdropLayer.SIDE_LANDSCAPE_SOURCE_SLOPE + shear
	t.ok(absf(east_slope - 0.5) < 0.001, "runtime shear aligns the east-side planted edge with the +0.5 wall slope")
	p.pan(Vector2(30, -10))
	layer.sync(16, 12, [Vector2i(8, 11)], p, Vector2(1600, 900))
	t.ok(sprite.transform.origin.distance_to(first.origin + Vector2(30, -10)) < 0.01, "the sidewalk panel follows camera panning")
	layer.sync(16, 12, [Vector2i(15, 4)], p, Vector2(1600, 900))
	t.ok(sprite.transform.x.x < 0.0, "the panel switches to the south side for an east entrance")
	var south_corner := BackdropLayer.landscape_corner(BackdropLayer.SIDE_SOUTH, BackdropLayer.SIDE_LANDSCAPE_DEPTH_M, 16, 12)
	t.eq(south_corner, Vector2(-0.5, 12.05), "south strip root stays at the far wall with the requested setback")
	t.ok((sprite.transform * BackdropLayer.SIDE_LANDSCAPE_GROUND_START_PX).distance_to(p.world_to_screen(south_corner.x, south_corner.y)) < 0.01, "mirrored planter root is fixed behind the south wall at ground level")
	var south_slope := -1.0 * (BackdropLayer.SIDE_LANDSCAPE_SOURCE_SLOPE + shear)
	t.ok(absf(south_slope + 0.5) < 0.001, "runtime shear aligns the south-side planted edge with the -0.5 wall slope")
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		t.eq(BackdropLayer.side_landscape_edge_length(BackdropLayer.SIDE_EAST, size.x, size.y), float(size.y) + BackdropLayer.SIDE_LANDSCAPE_OVERHANG_M, "east planting run reaches the full far edge for %dx%d" % [size.x, size.y])
		t.eq(BackdropLayer.side_landscape_edge_length(BackdropLayer.SIDE_SOUTH, size.x, size.y), float(size.x) + BackdropLayer.SIDE_LANDSCAPE_OVERHANG_M, "south planting run reaches the full far edge for %dx%d" % [size.x, size.y])
	layer.queue_free()
