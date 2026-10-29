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


func test_continuous_area_surface_keeps_entry_overlays(t, _tree) -> void:
	var items := BackdropLayer.layout_items(_proj(), 16, 12, [Vector2i(0, 5), Vector2i(0, 6)], Vector2(1280, 720))
	t.eq(_count(items, BackdropLayer.PAVE), 1, "one broad paving underlay remains below the generated surface")
	t.eq(_count(items, BackdropLayer.MAT), 2, "one door mat per entrance tile")
	t.eq(_count(items, BackdropLayer.ROAD), 1, "one road strip on the entrance side")
	var arrows := items.filter(func(it): return it.get("purpose", &"") == &"road_direction_arrow")
	t.eq(arrows.size(), 2, "two opposing lane arrows are painted on the road")
	for arrow in arrows:
		t.eq(arrow["points"].size(), 7, "direction arrow has a closed polygon head and stem")
		t.eq(arrow["color"], BackdropLayer.ROAD_LINE, "road arrows use the existing road-marking color")


func test_road_direction_arrows_follow_each_isometric_side(t, _tree) -> void:
	var proj := _proj(1.25)
	for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
		var forward := BackdropLayer.road_direction_arrow_points(proj, side, 20, 16, 7.0, 8.0, 1.0)
		var reverse := BackdropLayer.road_direction_arrow_points(proj, side, 20, 16, 7.0, 8.0, -1.0)
		var forward_tip_world := BackdropLayer.side_point(side, 7.0, 8.65, 20, 16)
		var reverse_tip_world := BackdropLayer.side_point(side, 7.0, 7.35, 20, 16)
		t.eq(forward.size(), 7, "forward arrow is built on side %d" % side)
		t.eq(reverse.size(), 7, "reverse arrow is built on side %d" % side)
		t.ok(forward[4].distance_to(proj.world_to_screen(forward_tip_world.x, forward_tip_world.y)) < 0.01, "forward tip points along side %d" % side)
		t.ok(reverse[4].distance_to(proj.world_to_screen(reverse_tip_world.x, reverse_tip_world.y)) < 0.01, "reverse tip points along side %d" % side)


func test_two_lane_arrows_exist_for_all_supported_store_sizes(t, _tree) -> void:
	var proj := _proj()
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var mid_x := int(size.x / 2)
			var mid_y := int(size.y / 2)
			var entrances: Array[Vector2i] = []
			match side:
				BackdropLayer.SIDE_WEST:
					entrances = [Vector2i(0, mid_y), Vector2i(0, mid_y + 1)]
				BackdropLayer.SIDE_NORTH:
					entrances = [Vector2i(mid_x, 0), Vector2i(mid_x + 1, 0)]
				BackdropLayer.SIDE_EAST:
					entrances = [Vector2i(size.x - 1, mid_y), Vector2i(size.x - 1, mid_y + 1)]
				_:
					entrances = [Vector2i(mid_x, size.y - 1), Vector2i(mid_x + 1, size.y - 1)]
			var items := BackdropLayer.layout_items(proj, size.x, size.y, entrances, Vector2(1600, 900))
			var arrows := items.filter(func(it): return it.get("purpose", &"") == &"road_direction_arrow")
			t.eq(arrows.size(), 2, "two lane arrows exist for %dx%d on side %d" % [size.x, size.y, side])


func test_slabs_only_outside_the_store(t, _tree) -> void:
	var items := BackdropLayer.layout_items(_proj(), 4, 3, [], Vector2(1280, 720))
	t.eq(_count(items, BackdropLayer.PAVE), 1, "exterior paving is one continuous surface without a metre grid")


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


func test_surrounding_ground_mesh_batches_tiles_and_tracks_camera(t, _tree) -> void:
	var viewport := Vector2(1920, 1080)
	var tile_size := Vector2(512, 512)
	var first := BackdropLayer._build_surrounding_ground_mesh(Vector2(137, 82), viewport, tile_size)
	t.ok(first != null, "surrounding ground builds for a non-empty viewport")
	var arrays: Array = first.surface_get_arrays(0)
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	t.eq(vertices.size(), 90, "five by three screen tiles are batched into fifteen quads")
	t.eq(uvs.size(), vertices.size(), "each batched vertex keeps its tile UV")
	var tint_matches := true
	for color in colors:
		tint_matches = tint_matches and absf(color.a - BackdropLayer.SURROUNDING_GROUND_OPACITY) < 0.002
	t.ok(tint_matches, "batched ground uses the authored surrounding-ground opacity")
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		min_y = minf(min_y, vertex.y)
		max_x = maxf(max_x, vertex.x)
		max_y = maxf(max_y, vertex.y)
	t.ok(min_x <= 0.0 and min_y <= 0.0 and max_x >= viewport.x and max_y >= viewport.y, "batched quads fully cover the viewport")
	var panned := BackdropLayer._build_surrounding_ground_mesh(Vector2(147, 82), viewport, tile_size)
	var panned_vertices: PackedVector2Array = panned.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	t.ok(absf((panned_vertices[0].x - vertices[0].x) - 10.0) < 0.01, "tile mesh phase follows a ten-pixel pan")


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
			t.ok(absf(transform.y.x) < 0.001 and transform.y.y > 0.0, "grouped grove keeps trunks vertical for side %d" % side)
			var expected_scale := BackdropLayer.REAR_GROVE_WORLD_LENGTH_M * Vector2(IsoProjection.HALF_TILE_W, IsoProjection.HALF_TILE_H).length() * proj.zoom / (BackdropLayer.REAR_GROVE_GROUND_END_PX - BackdropLayer.REAR_GROVE_GROUND_START_PX).length()
			t.ok(absf(transform.y.length() - expected_scale) < 0.001, "grouped grove keeps the same world height for %dx%d" % [size.x, size.y])
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


func test_urban_grove_panel_keeps_fixed_ground_endpoints(t, _tree) -> void:
	var proj := _proj(0.8)
	var texture := load("res://assets/generated/backgrounds/urban_grove_detailed_candidate_v1/urban_grove_detailed_candidate_v1.png") as Texture2D
	var compact_texture := load("res://assets/generated/backgrounds/urban_grove_detailed_candidate_v1/urban_grove_detailed_candidate_v1.png") as Texture2D
	var long20_texture := load("res://assets/generated/backgrounds/urban_grove_detailed_candidate_v1/urban_grove_detailed_candidate_v1.png") as Texture2D
	t.ok(texture != null and compact_texture != null and long20_texture != null, "generated urban grove panels import as runtime textures")
	var image_size := Vector2(texture.get_size())
	var compact_image_size := Vector2(compact_texture.get_size())
	var long20_image_size := Vector2(long20_texture.get_size())
	t.eq(image_size, Vector2(2172.0, 724.0), "long-panel ground anchors use the source image dimensions")
	t.eq(compact_image_size, Vector2(2172.0, 724.0), "compact-panel ground anchors use the generated image dimensions")
	t.eq(long20_image_size, Vector2(2172.0, 724.0), "20m panel ground anchors use the generated image dimensions")
	t.ok(BackdropLayer.URBAN_GROVE_SOURCE_START_PX.x >= 0.0 and BackdropLayer.URBAN_GROVE_SOURCE_END_PX.x < image_size.x, "long-panel ground anchors stay inside the image")
	t.ok(BackdropLayer.URBAN_GROVE_COMPACT_START_PX.x >= 0.0 and BackdropLayer.URBAN_GROVE_COMPACT_END_PX.x < compact_image_size.x and BackdropLayer.URBAN_GROVE_COMPACT_END_PX.y < compact_image_size.y, "compact-panel ground anchors stay inside the image")
	t.ok(BackdropLayer.URBAN_GROVE_20M_START_PX.x >= 0.0 and BackdropLayer.URBAN_GROVE_20M_END_PX.x < long20_image_size.x and BackdropLayer.URBAN_GROVE_20M_END_PX.y < long20_image_size.y, "20m ground anchors stay inside the image")
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_length := float(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var compact := edge_length <= BackdropLayer.URBAN_GROVE_COMPACT_WORLD_LENGTH_M
			var long20 := edge_length >= BackdropLayer.URBAN_GROVE_20M_WORLD_LENGTH_M
			var world_length := minf(edge_length, BackdropLayer.URBAN_GROVE_COMPACT_WORLD_LENGTH_M) if compact else BackdropLayer.URBAN_GROVE_20M_WORLD_LENGTH_M if long20 else BackdropLayer.URBAN_GROVE_LONG_WORLD_LENGTH_M
			var source_start := BackdropLayer.URBAN_GROVE_COMPACT_START_PX if compact else BackdropLayer.URBAN_GROVE_20M_START_PX if long20 else BackdropLayer.URBAN_GROVE_SOURCE_START_PX
			var source_end := BackdropLayer.URBAN_GROVE_COMPACT_END_PX if compact else BackdropLayer.URBAN_GROVE_20M_END_PX if long20 else BackdropLayer.URBAN_GROVE_SOURCE_END_PX
			var source_size := compact_image_size if compact else long20_image_size if long20 else image_size
			var along_start := (edge_length - world_length) * 0.5
			var depth := BackdropLayer.urban_grove_depth_m()
			var start := BackdropLayer.side_point(side, depth, along_start, size.x, size.y)
			var finish := BackdropLayer.side_point(side, depth, along_start + world_length, size.x, size.y)
			if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST:
				var swap := start
				start = finish
				finish = swap
			var transform := BackdropLayer.urban_grove_transform(proj, size.x, size.y, side, source_size)
			t.ok((transform * source_start).distance_to(proj.world_to_screen(start.x, start.y)) < 0.01, "urban grove first root stays on ground behind side %d for %dx%d" % [side, size.x, size.y])
			t.ok((transform * source_end).distance_to(proj.world_to_screen(finish.x, finish.y)) < 0.01, "urban grove last root stays on ground behind side %d for %dx%d" % [side, size.x, size.y])
			t.ok(absf(transform.y.x) < 0.001 and transform.y.y > 0.0, "urban grove keeps tree trunks vertical for side %d" % side)
			if long20:
				t.eq(world_length, edge_length, "20m grove reaches both projected wall endpoints on side %d" % side)
	var west := BackdropLayer.urban_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST, image_size)
	proj.pan(Vector2(31.0, -17.0))
	var moved := BackdropLayer.urban_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST, image_size)
	t.eq(moved.origin, west.origin + Vector2(31.0, -17.0), "urban grove roots follow camera pan at fixed world position")
	for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
		var pan_start_proj := _proj(0.8)
		var pan_end_proj := _proj(0.8)
		pan_end_proj.pan(Vector2(31.0, -17.0))
		var source_size := long20_image_size if (side == BackdropLayer.SIDE_NORTH or side == BackdropLayer.SIDE_SOUTH) else image_size
		var before := BackdropLayer.urban_grove_transform(pan_start_proj, 20, 16, side, source_size)
		var after := BackdropLayer.urban_grove_transform(pan_end_proj, 20, 16, side, source_size)
		t.ok(after.origin.distance_to(before.origin + Vector2(31.0, -17.0)) < 0.01, "full-length grove follows camera pan on side %d" % side)


func test_urban_grove_forms_a_three_side_band_around_the_entrance(t, _tree) -> void:
	for entrance in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
		var sides := BackdropLayer.urban_grove_sides(entrance)
		t.eq(sides.size(), 3, "perimeter planting spans the three non-road sides for entrance side %d" % entrance)
		t.ok(not sides.has(entrance), "planting keeps the entrance road side open for side %d" % entrance)
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			if side != entrance:
				t.ok(sides.has(side), "perimeter planting keeps side %d for entrance side %d" % [side, entrance])


func test_area_a_frontage_uses_projected_store_endpoints(t, _tree) -> void:
	var proj := _proj(1.25)
	for size in [Vector2i(10, 10), Vector2i(12, 12), Vector2i(16, 16), Vector2i(20, 20)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge := BackdropLayer.area_a_world_endpoints(size.x, size.y, side)
			var panel := BackdropLayer.area_a_panel_profile(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var transform := BackdropLayer.area_a_transform_for_panel(proj, size.x, size.y, side, panel["frontage_p0"], panel["frontage_p1"])
			var actual_start: Vector2 = transform * panel["frontage_p0"]
			var actual_end: Vector2 = transform * panel["frontage_p1"]
			var expected_start := proj.world_to_screen(edge[0].x, edge[0].y)
			var expected_end := proj.world_to_screen(edge[1].x, edge[1].y)
			t.ok(actual_start.distance_to(expected_start) < 0.01, "Area A frontage start meets side %d at %dx%d" % [side, size.x, size.y])
			t.ok(actual_end.distance_to(expected_end) < 0.01, "Area A frontage end meets side %d at %dx%d" % [side, size.x, size.y])
			t.ok(absf(transform.x.length() - transform.y.length()) < 0.001, "Area A retains uniform scale for side %d" % side)
			t.ok(panel["world_length_m"] >= (size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x), "Area A panel profile covers the full edge length")
	var before := BackdropLayer.area_a_transform_for_panel(proj, 16, 12, BackdropLayer.SIDE_EAST, BackdropLayer.AREA_A_12M_FRONTAGE_P0, BackdropLayer.AREA_A_12M_FRONTAGE_P1)
	proj.pan(Vector2(31.0, -17.0))
	var after := BackdropLayer.area_a_transform_for_panel(proj, 16, 12, BackdropLayer.SIDE_EAST, BackdropLayer.AREA_A_12M_FRONTAGE_P0, BackdropLayer.AREA_A_12M_FRONTAGE_P1)
	t.eq(after.origin, before.origin + Vector2(31.0, -17.0), "Area A frontage follows camera pan")


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
		t.ok(absf(size_transform.x.length() - transform.x.length()) < 0.001, "tree art keeps one world scale across %dx%d" % [size.x, size.y])
		var tree_height_m := (BackdropLayer.BACKDROP_GROUND_PX.y - BackdropLayer.BACKDROP_TOP_Y_PX) * size_transform.y.length() / (IsoProjection.Z_PX_PER_M * proj.zoom)
		t.ok(tree_height_m > IsoProjection.WALL_HEIGHT_M, "canopy rises above the wall in world metres for %dx%d" % [size.x, size.y])
		if size != Vector2i(12, 10):
			var reference_height_m := (BackdropLayer.BACKDROP_GROUND_PX.y - BackdropLayer.BACKDROP_TOP_Y_PX) * transform.y.length() / (IsoProjection.Z_PX_PER_M * proj.zoom)
			t.ok(absf(tree_height_m - reference_height_m) < 0.001, "world tree height is identical across store sizes")
	var zoomed_proj := _proj(0.75)
	var zoomed_transform := BackdropLayer.environment_transform(zoomed_proj, 16, 12, Vector2(backdrop_texture.get_size()))
	var zoomed_tree_height_m := (BackdropLayer.BACKDROP_GROUND_PX.y - BackdropLayer.BACKDROP_TOP_Y_PX) * zoomed_transform.y.length() / (IsoProjection.Z_PX_PER_M * zoomed_proj.zoom)
	var expected_tree_height_m := (BackdropLayer.BACKDROP_GROUND_PX.y - BackdropLayer.BACKDROP_TOP_Y_PX) * transform.y.length() / (IsoProjection.Z_PX_PER_M * proj.zoom)
	t.ok(absf(zoomed_tree_height_m - expected_tree_height_m) < 0.001, "camera zoom changes pixel size without changing world tree height")
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
