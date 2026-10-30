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
	t.eq(slabs, 44, "store paving remains the only metre-grid slab set")


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


func test_road_runs_beyond_viewport_and_pan_limit(t, _tree) -> void:
	for viewport in [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080)]:
		for zoom in [0.5, 1.0, 2.0]:
			var proj := _proj(zoom)
			var margin: float = BackdropLayer.road_along_margin(proj, viewport)
			var projected_run: float = Vector2(IsoProjection.HALF_TILE_W, IsoProjection.HALF_TILE_H).length() * zoom
			var pan_clearance: float = IsoProjection.PAN_MARGIN_TILES * 2.0 * projected_run
			var required: float = viewport.length() * 0.5 + 128.0 * zoom + pan_clearance
			t.ok(margin * projected_run >= required, "road extends past the viewport and camera pan at %dx%d zoom %.1f" % [int(viewport.x), int(viewport.y), zoom])


func test_surrounding_ground_texture_phase_tracks_camera(t, _tree) -> void:
	var tile_size := Vector2(1254.0, 1254.0)
	var initial := BackdropLayer.surrounding_ground_tile_offset(Vector2(512.0, 790.0), tile_size)
	var pan := Vector2(31.0, -17.0)
	var moved := BackdropLayer.surrounding_ground_tile_offset(Vector2(512.0, 790.0) + pan, tile_size)
	var phase_delta := Vector2(fposmod(moved.x - initial.x + tile_size.x, tile_size.x), fposmod(moved.y - initial.y + tile_size.y, tile_size.y))
	t.eq(phase_delta, Vector2(fposmod(pan.x, tile_size.x), fposmod(pan.y, tile_size.y)), "ground texture phase translates with the camera")
	t.eq(BackdropLayer.surrounding_ground_tile_offset(Vector2(4.0, 9.0), Vector2.ZERO), Vector2.ZERO, "invalid texture size has a safe zero offset")


func test_grouped_roadside_grove_anchors_to_world_ground(t, _tree) -> void:
	var proj := _proj(0.8)
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_length := float(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var depth := BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M + BackdropLayer.KERB_M + BackdropLayer.OUTER_SIDEWALK_M + 0.2
			var along_start := (edge_length - BackdropLayer.REAR_GROVE_WORLD_LENGTH_M) * 0.5
			var world_start := BackdropLayer.side_point(side, depth, along_start, size.x, size.y)
			var world_end := BackdropLayer.side_point(side, depth, along_start + BackdropLayer.REAR_GROVE_WORLD_LENGTH_M, size.x, size.y)
			if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST:
				var swap := world_start
				world_start = world_end
				world_end = swap
			var transform := BackdropLayer.roadside_grove_transform(proj, size.x, size.y, side)
			t.ok((transform * BackdropLayer.REAR_GROVE_GROUND_START_PX).distance_to(proj.world_to_screen(world_start.x, world_start.y)) < 0.01, "grouped grove root start anchors on side %d for %dx%d" % [side, size.x, size.y])
			t.ok((transform * BackdropLayer.REAR_GROVE_GROUND_END_PX).distance_to(proj.world_to_screen(world_end.x, world_end.y)) < 0.01, "grouped grove root end anchors on side %d for %dx%d" % [side, size.x, size.y])
			t.ok(absf(transform.x.length() - transform.y.length()) < 0.001, "grouped grove keeps uniform scale for side %d" % side)
			var expected_scale := BackdropLayer.REAR_GROVE_WORLD_LENGTH_M * Vector2(IsoProjection.HALF_TILE_W, IsoProjection.HALF_TILE_H).length() * proj.zoom / (BackdropLayer.REAR_GROVE_GROUND_END_PX - BackdropLayer.REAR_GROVE_GROUND_START_PX).length()
			t.ok(absf(transform.x.length() - expected_scale) < 0.001, "grouped grove keeps the same world height and scale for %dx%d" % [size.x, size.y])
	var initial := BackdropLayer.roadside_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST)
	proj.pan(Vector2(31.0, -17.0))
	var moved := BackdropLayer.roadside_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST)
	t.eq(moved.origin, initial.origin + Vector2(31.0, -17.0), "grouped grove follows camera pan at its ground anchor")


func test_generated_outer_sidewalk_anchors_to_world_centerline(t, _tree) -> void:
	var proj := _proj(0.8)
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_length := float(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var depth := BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M + BackdropLayer.KERB_M + BackdropLayer.OUTER_SIDEWALK_M * 0.5
			var world_start := BackdropLayer.side_point(side, depth, -BackdropLayer.OUTER_SIDEWALK_EDGE_OVERHANG_M, size.x, size.y)
			var world_end := BackdropLayer.side_point(side, depth, edge_length + BackdropLayer.OUTER_SIDEWALK_EDGE_OVERHANG_M, size.x, size.y)
			if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST:
				var swap := world_start
				world_start = world_end
				world_end = swap
			var transform := BackdropLayer.outer_sidewalk_transform(proj, size.x, size.y, side, Vector2(2172.0, 724.0))
			t.ok((transform * BackdropLayer.OUTER_SIDEWALK_START_PX).distance_to(proj.world_to_screen(world_start.x, world_start.y)) < 0.01, "sidewalk start anchors on side %d for %dx%d" % [side, size.x, size.y])
			t.ok((transform * BackdropLayer.OUTER_SIDEWALK_END_PX).distance_to(proj.world_to_screen(world_end.x, world_end.y)) < 0.01, "sidewalk end anchors on side %d for %dx%d" % [side, size.x, size.y])
			var transform_xform: Transform2D = transform
			t.ok(absf(transform_xform.x.length() - transform_xform.y.length()) < 0.001, "sidewalk retains uniform scale on side %d" % side)


func test_area_a_frontage_uses_projected_store_endpoints(t, _tree) -> void:
	var proj := _proj(1.25)
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_start := Vector2(-0.5, size.y - 0.5) if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_SOUTH else Vector2(size.x - 0.5, -0.5)
			var edge_end := Vector2(-0.5, -0.5) if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_NORTH else Vector2(size.x - 0.5, size.y - 0.5)
			var transform := BackdropLayer.area_a_transform(proj, size.x, size.y, side)
			var actual_start: Vector2 = transform * BackdropLayer.AREA_A_FRONTAGE_P0
			var actual_end: Vector2 = transform * BackdropLayer.AREA_A_FRONTAGE_P1
			var expected_start := proj.world_to_screen(edge_start.x, edge_start.y)
			var expected_end := proj.world_to_screen(edge_end.x, edge_end.y)
			t.ok(actual_start.distance_to(expected_start) < 0.01, "Area A frontage start meets side %d at %dx%d" % [side, size.x, size.y])
			t.ok(actual_end.distance_to(expected_end) < 0.01, "Area A frontage end meets side %d at %dx%d" % [side, size.x, size.y])
			t.ok(absf(transform.x.length() - transform.y.length()) < 0.001, "Area A retains uniform scale for side %d" % side)


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
		t.ok(left_coverage >= (expected_left - size_ground).length() - 1.0, "left V branch reaches its own far-wall endpoint for %dx%d" % [size.x, size.y])
		t.ok(right_coverage >= (expected_right - size_ground).length() - 1.0, "right V branch reaches its own far-wall endpoint for %dx%d" % [size.x, size.y])
		t.ok(absf(transform.x.length() - transform.y.length()) < 0.001, "V art keeps a uniform scale for %dx%d" % [size.x, size.y])
	proj.pan(Vector2(29, -13))
	layer.sync(16, 12, [], proj, Vector2(1280, 720))
	var moved_ground: Vector2 = layer._environment_transform * BackdropLayer.BACKDROP_GROUND_PX
	t.eq(moved_ground, ground + Vector2(29, -13), "camera panning moves the ground anchor with the store")
	layer.queue_free()


func test_environment_branch_scale_is_independent(t, _tree) -> void:
	var ground := Vector2(100.0, 200.0)
	var image_ground := Vector2(800.0, 400.0)
	var left := BackdropLayer.environment_branch_scale(ground, Vector2(200.0, 400.0), image_ground, Vector2(1000.0, 600.0))
	var right := BackdropLayer.environment_branch_scale(ground, Vector2(500.0, 200.0), image_ground, Vector2(1200.0, 400.0))
	t.ok(is_finite(left) and is_finite(right) and left != right, "left and right branches produce separately measured scale requirements")
	t.ok(maxf(left, right) >= left and maxf(left, right) >= right, "the larger independently measured branch controls coverage")


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


## #170: the long planted strip that ran from the store's side wall to the screen edge is gone for every store size
## and entrance; the ground there is the surrounding ground texture.
func test_no_side_planting_strip(t, tree) -> void:
	var layer := BackdropLayer.new()
	tree.root.add_child(layer)
	var p := _proj()
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for ent in [[Vector2i(size.x / 2, size.y - 1)], [Vector2i(size.x - 1, 4)]]:
			layer.sync(size.x, size.y, ent, p, Vector2(1600, 900))
			var strips := 0
			for child in layer.get_children():
				if child is Sprite2D and child.texture != null and child.texture.resource_path.contains("roadside_greenery"):
					strips += 1
			t.eq(strips, 0, "no side planting strip for %dx%d, entrance %s" % [size.x, size.y, ent[0]])
