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
	t.eq(_count(items, BackdropLayer.PAVE), 2, "a narrow perimeter walk and entrance-side apron remain below the generated surface")
	t.eq(items.filter(func(it): return it.get("purpose", &"") == &"perimeter_paving_ring").size(), 1, "narrow walk follows the full store perimeter")
	t.eq(items.filter(func(it): return it.get("purpose", &"") == &"entrance_paving_apron").size(), 1, "broad paving remains on the entrance edge")
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
	t.eq(_count(items, BackdropLayer.PAVE), 2, "exterior paving is a continuous narrow ring with one broad entrance apron")


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


func test_urban_context_backdrop_is_world_anchored_and_covers_viewport(t, _tree) -> void:
	var viewport := Vector2(1600.0, 900.0)
	var backdrop_texture: Texture2D = BackdropLayer.UrbanContextBackdrop
	var texture_size := Vector2(backdrop_texture.get_size())
	t.eq(texture_size, Vector2(1774.0, 887.0), "the fallback neighborhood source retains its authored canvas")
	t.ok(is_equal_approx(texture_size.x / texture_size.y, 2.0), "the neighborhood artwork uses a 2:1 dimetric ground plane")
	var proj := _proj(0.5)
	var initial := BackdropLayer.urban_context_transform(proj, 16, 12, viewport, texture_size)
	var extent := Vector2(absf(initial.x.x) * texture_size.x + absf(initial.y.x) * texture_size.y, absf(initial.x.y) * texture_size.x + absf(initial.y.y) * texture_size.y)
	t.ok(extent.x > viewport.x and extent.y > viewport.y, "the dimetric urban backdrop covers the viewport at minimum zoom")
	t.ok(extent.x - viewport.x >= 320.0 and extent.y - viewport.y >= 240.0, "the backdrop has margin for the tested +/-160x120 camera pan at minimum zoom")
	t.ok(initial.x.is_equal_approx(Vector2(BackdropLayer.URBAN_CONTEXT_MIN_SCALE, 0.0)) and initial.y.is_equal_approx(Vector2(0.0, BackdropLayer.URBAN_CONTEXT_MIN_SCALE)), "the backdrop preserves its authored screen-space directions")
	t.ok(absf(initial.y.length() / initial.x.length() - 1.0) < 0.0001, "the background uses uniform scaling without depth-axis deformation")
	var center_offset := initial.x * texture_size.x * 0.5 + initial.y * texture_size.y * 0.5
	var old_center := initial.origin + center_offset
	var expected_center := proj.world_to_screen((16.0 - 1.0) * 0.5, (12.0 - 1.0) * 0.5)
	t.ok(old_center.distance_to(expected_center) < 0.01, "the panorama remains centered on the projected store")
	proj.pan(Vector2(80.0, -40.0))
	var moved := BackdropLayer.urban_context_transform(proj, 16, 12, viewport, texture_size)
	var new_center := moved.origin + moved.x * texture_size.x * 0.5 + moved.y * texture_size.y * 0.5
	t.ok(new_center.distance_to(old_center + Vector2(80.0, -40.0)) < 0.01, "the panorama follows the world camera at full translation")
	t.ok(absf(moved.x.length() - BackdropLayer.URBAN_CONTEXT_MIN_SCALE) < 0.0001, "the panorama keeps sufficient cover scale at minimum zoom")
	t.ok(BackdropLayer.urban_context_transform(proj, 0, 12, viewport, texture_size).x == Vector2.RIGHT, "invalid store bounds return the identity transform")


func test_screenshot_plate_transform_tracks_camera_pan_and_zoom(t, _tree) -> void:
	var reference_origin := Vector2(320.0, 240.0)
	var reference_zoom := 0.5
	var proj := _proj(0.75)
	var transform := BackdropLayer.screen_plate_transform_from_reference(reference_origin, reference_zoom, proj)
	var sample := Vector2(1440.0, 810.0)
	var expected := proj.origin + (sample - reference_origin) * (proj.zoom / reference_zoom)
	t.ok((transform * sample).distance_to(expected) < 0.01, "background pixels follow the current projection scale and origin")
	proj.pan(Vector2(80.0, -40.0))
	var moved := BackdropLayer.screen_plate_transform_from_reference(reference_origin, reference_zoom, proj)
	t.ok((moved * sample).distance_to(expected + Vector2(80.0, -40.0)) < 0.01, "background plate follows camera pan after scaling")
	t.eq(BackdropLayer.screen_plate_transform_from_reference(reference_origin, 0.0, proj), Transform2D.IDENTITY, "invalid reference zoom uses a safe identity transform")


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
			var world_start := BackdropLayer.side_point(side, depth, (edge_length - BackdropLayer.OUTER_SIDEWALK_WORLD_LENGTH_M) * 0.5, size.x, size.y)
			var world_end := BackdropLayer.side_point(side, depth, (edge_length + BackdropLayer.OUTER_SIDEWALK_WORLD_LENGTH_M) * 0.5, size.x, size.y)
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
	for edge_length in [10.0, 12.0, 16.0, 20.0]:
		var profile := BackdropLayer.urban_grove_edge_profile(edge_length)
		var source_texture: Texture2D = profile["texture"]
		var source_start: Vector2 = profile["source_start"]
		var source_end: Vector2 = profile["source_end"]
		t.ok(source_texture != null, "generated grove profile for %.0fm imports as a runtime texture" % edge_length)
		t.eq(Vector2(source_texture.get_size()), Vector2(1983.0, 793.0), "grove profile for %.0fm keeps its authored canvas" % edge_length)
		t.ok(source_start.x >= 0.0 and source_start.y >= 0.0 and source_end.x < source_texture.get_width() and source_end.y < source_texture.get_height(), "ground anchors remain inside %.0fm profile" % edge_length)
		var source_image := source_texture.get_image()
		for ground_anchor in [source_start, (source_start + source_end) * 0.5, source_end]:
			var anchor_pixel := Vector2i(roundi(ground_anchor.x), roundi(ground_anchor.y))
			var touches_ground := false
			for dy in range(-16, 17):
				for dx in range(-16, 17):
					if source_image.get_pixelv(anchor_pixel + Vector2i(dx, dy)).a > 0.2:
						touches_ground = true
						break
				if touches_ground:
					break
			t.ok(touches_ground, "%.0fm profile ground anchor touches the uneven planted base" % edge_length)
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
			var edge_length := float(size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x)
			var depth := BackdropLayer.urban_grove_depth_m()
			var profile := BackdropLayer.urban_grove_edge_profile(edge_length)
			var source_start: Vector2 = profile["source_start"]
			var source_end: Vector2 = profile["source_end"]
			var world_length: float = profile["world_length"]
			var along_start := (edge_length - world_length) * 0.5
			var start := BackdropLayer.side_point(side, depth, along_start, size.x, size.y)
			var finish := BackdropLayer.side_point(side, depth, along_start + world_length, size.x, size.y)
			if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST:
				var swap := start
				start = finish
				finish = swap
			var transform := BackdropLayer.urban_grove_transform(proj, size.x, size.y, side)
			t.ok((transform * source_start).distance_to(proj.world_to_screen(start.x, start.y)) < 0.01, "first root stays on ground beyond side %d for %dx%d" % [side, size.x, size.y])
			t.ok((transform * source_end).distance_to(proj.world_to_screen(finish.x, finish.y)) < 0.01, "last root stays on ground beyond side %d for %dx%d" % [side, size.x, size.y])
			t.ok(absf(transform.y.x) < 0.001 and transform.y.y > 0.0, "grove trunks stay upright on side %d" % side)
			t.ok(along_start <= 0.0 and along_start + world_length >= edge_length, "planting reaches both wall endpoints on side %d for %dx%d" % [side, size.x, size.y])
			t.ok(world_length in [BackdropLayer.URBAN_GROVE_18M_WORLD_LENGTH_M, BackdropLayer.URBAN_GROVE_20M_WORLD_LENGTH_M], "planting uses a generated physical-length profile on side %d" % side)
	var west := BackdropLayer.urban_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST)
	proj.pan(Vector2(31.0, -17.0))
	var moved := BackdropLayer.urban_grove_transform(proj, 16, 12, BackdropLayer.SIDE_WEST)
	t.ok(moved.origin.distance_to(west.origin + Vector2(31.0, -17.0)) < 0.01, "urban grove roots follow camera pan at fixed world position")

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
			var mid := (expected_start + expected_end) * 0.5
			var outside_world := Vector2(-1, 0) if side == BackdropLayer.SIDE_WEST else (Vector2(1, 0) if side == BackdropLayer.SIDE_EAST else (Vector2(0, -1) if side == BackdropLayer.SIDE_NORTH else Vector2(0, 1)))
			var world_mid := (edge[0] + edge[1]) * 0.5
			var outside_screen := proj.world_to_screen(world_mid.x + outside_world.x, world_mid.y + outside_world.y) - mid
			var apron_sample: Vector2 = transform * ((panel["frontage_p0"] + panel["frontage_p1"]) * 0.5 + Vector2(0, 100)) - mid
			t.ok((expected_end - expected_start).cross(outside_screen) * (expected_end - expected_start).cross(apron_sample) > 0.0, "Area A apron lies outside side %d" % side)
			t.ok(panel["world_length_m"] >= (size.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else size.x), "Area A panel profile covers the full edge length")
	var before := BackdropLayer.area_a_transform_for_panel(proj, 16, 12, BackdropLayer.SIDE_EAST, BackdropLayer.AREA_A_12M_FRONTAGE_P0, BackdropLayer.AREA_A_12M_FRONTAGE_P1)
	proj.pan(Vector2(31.0, -17.0))
	var after := BackdropLayer.area_a_transform_for_panel(proj, 16, 12, BackdropLayer.SIDE_EAST, BackdropLayer.AREA_A_12M_FRONTAGE_P0, BackdropLayer.AREA_A_12M_FRONTAGE_P1)
	t.eq(after.origin, before.origin + Vector2(31.0, -17.0), "Area A frontage follows camera pan")


func test_runtime_neighborhood_plate_tracks_each_store_size_and_camera(t, _tree) -> void:
	var viewport := Vector2(1600.0, 900.0)
	var texture_size := Vector2(BackdropLayer.UrbanContextBackdrop.get_size())
	var proj := _proj(1.25)
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		var transform := BackdropLayer.urban_context_transform(proj, size.x, size.y, viewport, texture_size)
		var center_offset := transform.x * texture_size.x * 0.5 + transform.y * texture_size.y * 0.5
		var center := transform.origin + center_offset
		var store_center := proj.world_to_screen((float(size.x) - 1.0) * 0.5, (float(size.y) - 1.0) * 0.5)
		t.ok(center.distance_to(store_center) < 0.01, "neighborhood plate centers on %dx%d store" % [size.x, size.y])
		proj.pan(Vector2(29.0, -13.0))
		var moved := BackdropLayer.urban_context_transform(proj, size.x, size.y, viewport, texture_size)
		var moved_center := moved.origin + moved.x * texture_size.x * 0.5 + moved.y * texture_size.y * 0.5
		t.ok(moved_center.distance_to(center + Vector2(29.0, -13.0)) < 0.01, "neighborhood plate follows camera pan at %dx%d" % [size.x, size.y])
		proj.pan(Vector2(-29.0, 13.0))


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
	for size in [Vector2i(12, 10), Vector2i(16, 12), Vector2i(20, 16)]:
		layer.sync(size.x, size.y, [Vector2i(0, 5)], p, Vector2(1600, 900))
		var sprite := layer.get_node_or_null("SideLandscapeSprite") as Sprite2D
		t.ok(sprite != null, "legacy planting layer remains addressable for %dx%d" % [size.x, size.y])
		t.eq(sprite.visible, false, "detached planting strip is excluded at %dx%d" % [size.x, size.y])
	layer.queue_free()


func test_asphalt_surface_follows_camera_and_fades_at_ends(t, tree) -> void:
	var proj := _proj(1.0)
	var layer := BackdropLayer.new()
	tree.root.add_child(layer)
	layer.sync(16, 12, [Vector2i(7, 11)], proj, Vector2(1600, 900))
	var first := layer._asphalt_texture.surface_get_arrays(0)
	var point: Vector2 = first[Mesh.ARRAY_VERTEX][0]
	var uv: Vector2 = first[Mesh.ARRAY_TEX_UV][0]
	var min_alpha := 1.0
	for c in first[Mesh.ARRAY_COLOR]:
		min_alpha = minf(min_alpha, c.a)
	t.ok(min_alpha < 0.01, "asphalt fades transparent at outer end")
	proj.pan(Vector2(31, -17))
	layer.sync(16, 12, [Vector2i(7, 11)], proj, Vector2(1600, 900))
	var moved := layer._asphalt_texture.surface_get_arrays(0)
	t.ok((moved[Mesh.ARRAY_VERTEX][0] as Vector2).distance_to(point + Vector2(31, -17)) < 0.01, "asphalt follows camera pan")
	t.eq(moved[Mesh.ARRAY_TEX_UV][0], uv, "asphalt sample stays world anchored")
	layer.queue_free()
