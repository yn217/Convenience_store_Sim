extends RefCounted
## 10_TEST_VECTORS §A goldens + round trip / diamond hit-test / anchors (Issue #4).

const Seeds := preload("res://tests/support/test_seeds.gd")
const ZOOMS := [0.5, 0.75, 1.0, 1.5, 2.0]


func _proj(zoom: float = 1.0) -> IsoProjection:
	var p := IsoProjection.new()
	p.origin = Vector2(1000, 200)
	p.set_zoom(zoom)
	return p


func _near(a: Vector2, b: Vector2, tol: float = 1e-6) -> bool:
	return a.distance_to(b) <= tol


func test_golden_values(t, _tree) -> void:
	var p := _proj()
	t.ok(_near(p.world_to_screen(0, 0), Vector2(1000, 200)), "cell (0,0)")
	t.ok(_near(p.world_to_screen(1, 0), Vector2(1064, 232)), "cell (1,0)")
	t.ok(_near(p.world_to_screen(0, 1), Vector2(936, 232)), "cell (0,1)")
	t.ok(_near(p.world_to_screen(2, 3), Vector2(936, 360)), "cell (2,3)")
	t.ok(_near(p.world_to_screen(0, 0, 1.0), Vector2(1000, 121.61632823), 1e-6), "height 1 m lifts by 78.38367177 px")


func test_zoom_scales_offsets_from_origin(t, _tree) -> void:
	var p := _proj(2.0)
	t.ok(_near(p.world_to_screen(1, 0), Vector2(1128, 264)), "zoom 2 doubles the tile diamond")
	t.eq(_proj(5.0).zoom, 2.0, "zoom clamps to 2.0")
	t.eq(_proj(0.1).zoom, 0.5, "zoom clamps to 0.5")


func test_tile_round_trip_every_tile_every_zoom(t, _tree) -> void:
	for z in ZOOMS:
		var p := _proj(z)
		for y in 12:
			for x in 16:
				var c := Vector2i(x, y)
				t.eq(p.screen_to_tile(p.tile_center(c)), c, "center round trip %s @%s" % [str(c), str(z)])
				var w := p.screen_to_world(p.tile_center(c))
				t.ok(_near(w, Vector2(x, y), 1e-9), "world round trip")


func test_diamond_corners_and_edge_hit_test(t, _tree) -> void:
	for z in ZOOMS:
		var p := _proj(z)
		var c := Vector2i(5, 4)
		var d := p.tile_diamond(c)
		var centre := p.tile_center(c)
		t.ok(_near(d[0], centre + z * Vector2(0, -32)), "top corner")
		t.ok(_near(d[1], centre + z * Vector2(64, 0)), "right corner")
		t.ok(_near(d[2], centre + z * Vector2(0, 32)), "bottom corner")
		t.ok(_near(d[3], centre + z * Vector2(-64, 0)), "left corner")
		# Just inside each corner stays in the tile; just outside belongs to the neighbour.
		for i in 4:
			t.eq(p.screen_to_tile(centre.lerp(d[i], 0.995)), c, "inside corner %d" % i)
		t.ok(p.screen_to_tile(centre.lerp(d[0], 1.02)) != c, "outside top corner leaves tile")
		t.ok(p.screen_to_tile(centre.lerp(d[2], 1.02)) != c, "outside bottom corner leaves tile")
		# Every edge midpoint pair: a point just across an edge is the adjacent tile.
		t.eq(p.screen_to_tile((d[0] + d[1]) * 0.5 + (centre - (d[0] + d[1]) * 0.5) * -0.02), Vector2i(5, 3), "north edge -> (5,3)")
		t.eq(p.screen_to_tile((d[1] + d[2]) * 0.5 + (centre - (d[1] + d[2]) * 0.5) * -0.02), Vector2i(6, 4), "east edge -> (6,4)")
		t.eq(p.screen_to_tile((d[2] + d[3]) * 0.5 + (centre - (d[2] + d[3]) * 0.5) * -0.02), Vector2i(5, 5), "south edge -> (5,5)")
		t.eq(p.screen_to_tile((d[3] + d[0]) * 0.5 + (centre - (d[3] + d[0]) * 0.5) * -0.02), Vector2i(4, 4), "west edge -> (4,4)")


func test_random_points_inside_diamond_map_to_their_tile(t, _tree) -> void:
	var rng := Lcg32.new(Seeds.VISUALS)
	var p := _proj(1.0)
	for i in 2000:
		var c := Vector2i(int(rng.uniform_0_1() * 16.0), int(rng.uniform_0_1() * 12.0))
		var fx := (rng.uniform_0_1() - 0.5) * 0.98   # stay off the exact borders
		var fy := (rng.uniform_0_1() - 0.5) * 0.98
		var pt := p.world_to_screen(c.x + fx, c.y + fy)
		t.eq(p.screen_to_tile(pt), c, "point inside tile %s" % str(c))


func test_corner_and_edge_tiles_of_the_store(t, _tree) -> void:
	var p := _proj(1.0)
	var corners := [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 11), Vector2i(15, 11)]
	for c in corners:
		t.eq(p.screen_to_tile(p.tile_center(c)), c, "corner tile %s" % str(c))
	# Just outside the floor maps to a tile outside the store (callers bounds-check).
	t.eq(p.screen_to_tile(p.world_to_screen(-0.6, 0)), Vector2i(-1, 0), "west of floor")
	t.eq(p.screen_to_tile(p.world_to_screen(15.6, 11)), Vector2i(16, 11), "east of floor")


func test_floor_bounds_and_centering_follow_grid_size(t, _tree) -> void:
	var p := IsoProjection.new()
	var b := p.floor_bounds(16, 12)
	t.ok(absf(b.size.x - 28.0 * 64.0) < 1e-6, "width = (w+h)*64")
	t.ok(absf(b.size.y - 28.0 * 32.0) < 1e-6, "height = (w+h)*32")
	var b2 := p.floor_bounds(20, 8)
	t.ok(absf(b2.size.x - 28.0 * 64.0) < 1e-6 and absf(b2.size.y - 28.0 * 32.0) < 1e-6, "w+h preserved")
	var b3 := p.floor_bounds(10, 10)
	t.ok(absf(b3.size.x - 20.0 * 64.0) < 1e-6, "10x10 narrower than 16x12")
	for z in ZOOMS:
		var q := IsoProjection.new()
		q.set_zoom(z)
		q.center_floor(Vector2(1920, 1080), 16, 12)
		var cb := q.floor_bounds(16, 12)
		t.ok(_near(cb.position + cb.size * 0.5, Vector2(960, 540), 1e-6), "floor centred @%s" % str(z))


func test_sprite_anchor_and_rotated_footprint_ground_point(t, _tree) -> void:
	for z in ZOOMS:
		var p := _proj(z)
		var ground := p.world_to_screen(4, 5)
		var anchor := Vector2(300, 420)
		t.ok(_near(p.sprite_top_left(ground, anchor) + anchor * (z / 2.0), ground), "anchor lands on the ground point @%s" % str(z))
		for r in 4:
			var cells := StoreGrid.footprint_cells({"w": 1, "h": 2}, 4, 5, r)
			var centroid := Vector2.ZERO
			for c in cells:
				centroid += Vector2(c)
			centroid /= cells.size()
			var screen := p.world_to_screen(centroid.x, centroid.y)
			t.ok(p.screen_to_world(screen).distance_to(centroid) * 64.0 * z < 1.0, "rotation %d ground point within 1 screen px" % r)
			for c in cells:
				t.ok(cells.has(p.screen_to_tile(p.tile_center(c))), "occupied cell round trips")
