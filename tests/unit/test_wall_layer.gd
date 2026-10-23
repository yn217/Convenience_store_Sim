extends RefCounted
## Issue #61 (walls): far-edge wall geometry, entrance openings, lamps and the camera margin for walls.


func _proj(zoom: float = 1.0) -> IsoProjection:
	var p := IsoProjection.new()
	p.origin = Vector2(1000, 200)
	p.set_zoom(zoom)
	return p


func _of(quads: Array, kind: StringName, wall: String = "") -> Array:
	return quads.filter(func(q): return q["kind"] == kind and (wall == "" or q["wall"] == wall))


func test_no_walls_for_empty_store(t, _tree) -> void:
	t.eq(WallLayer.wall_quads(_proj(), 0, 0, []).size(), 0, "no walls without a floor")


func test_walls_only_on_far_edges(t, _tree) -> void:
	var quads := WallLayer.wall_quads(_proj(), 16, 12, [])
	t.ok(not quads.is_empty(), "walls are produced")
	for q in quads:
		t.ok(q["wall"] == "north" or q["wall"] == "west", "only north and west walls")
		t.eq(q["points"].size(), 4, "every wall piece is a quad")
	t.eq(_of(quads, &"wall", "north").size(), 1, "one solid north run without openings")
	t.eq(_of(quads, &"wall", "west").size(), 1, "one solid west run without openings")


func test_wall_heights_and_wainscot_band(t, _tree) -> void:
	var p := _proj()
	var quads := WallLayer.wall_quads(p, 16, 12, [])
	var top: Dictionary = _of(quads, &"wall", "north")[0]
	var base: Dictionary = _of(quads, &"wainscot", "north")[0]
	# Points are [a at z0, b at z0, b at z1, a at z1]: the wall top is 2.6 m above the floor line.
	t.ok(absf(top["points"][2].y - p.world_to_screen(15.5, -0.5, 2.6).y) < 1e-6, "upper wall reaches 2.6 m")
	t.ok(absf(base["points"][2].y - p.world_to_screen(15.5, -0.5, 0.9).y) < 1e-6, "wainscot band ends at 0.9 m")
	t.ok(top["color"] == WallLayer.WALL_TOP, "upper wall uses the light wall colour")
	t.ok(base["color"] == WallLayer.WAINSCOT, "wainscot uses the darker band colour")


func test_entrance_on_west_edge_opens_a_glass_door(t, _tree) -> void:
	var quads := WallLayer.wall_quads(_proj(), 16, 12, [Vector2i(0, 5), Vector2i(0, 6)])
	var glass: Array = _of(quads, &"glass")
	t.eq(glass.size(), 1, "the two adjacent entrance tiles form one door panel")
	t.ok(glass[0]["span"] == Vector2(4.5, 6.5), "door panel spans the entrance tiles on the west wall")
	t.eq(glass[0]["color"].a, 0.5, "glass panel is half transparent")
	for q in _of(quads, &"wall", "west") + _of(quads, &"wainscot", "west") + _of(quads, &"trim", "west"):
		t.ok(q["span"].y <= 4.5 or q["span"].x >= 6.5, "no solid west wall inside the door")


func test_entrance_on_north_edge_opens_the_north_wall(t, _tree) -> void:
	var quads := WallLayer.wall_quads(_proj(), 16, 12, [Vector2i(3, 0)])
	var glass: Array = _of(quads, &"glass")
	t.eq(glass.size(), 1, "one door on the north wall")
	t.eq(glass[0]["wall"], "north", "door is on the north wall")
	t.eq(_of(quads, &"wall", "north").size(), 2, "north wall is split around the door")


func test_lamps_about_every_three_tiles(t, _tree) -> void:
	var quads := WallLayer.wall_quads(_proj(), 16, 12, [])
	t.eq(_of(quads, &"lamp", "north").size(), 5, "north wall: lamps at tiles 1, 4, 7, 10, 13")
	t.eq(_of(quads, &"lamp", "west").size(), 4, "west wall: lamps at tiles 1, 4, 7, 10")
	for q in _of(quads, &"lamp"):
		t.ok(q["color"] == UiTheme.WARM, "lamps use the warm UI colour")


func test_fit_keeps_wall_tops_on_screen(t, _tree) -> void:
	var vp := Vector2(1280, 720)
	var p := IsoProjection.new()
	p.fit_floor(vp, 16, 12)
	var quads := WallLayer.wall_quads(p, 16, 12, [])
	var inside := true
	for q in quads:
		for pt in q["points"]:
			if pt.y < 0.0 or pt.y > vp.y or pt.x < 0.0 or pt.x > vp.x:
				inside = false
	t.ok(inside, "every wall point is inside the viewport after fit")
	t.ok(Rect2(Vector2.ZERO, vp).encloses(p.floor_bounds(16, 12)), "floor stays inside the viewport after fit")
