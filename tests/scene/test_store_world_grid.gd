extends RefCounted
## StoreWorld presenter: grid size from numeric settings, hover highlight, entrance.


func _world(tree, w: int, h: int) -> Node2D:
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.apply_snapshot({
		"store_width": w, "store_height": h, "revision": 0,
		"entrance_tiles": [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i],
	})
	return world


func test_grid_size_comes_from_settings(t, tree) -> void:
	for size in [Vector2i(16, 12), Vector2i(20, 8), Vector2i(5, 5)]:
		var world := _world(tree, size.x, size.y)
		t.eq(world.tile_count(), size.x * size.y, "tile count %s" % str(size))
		t.ok(world.in_store(Vector2i(size.x - 1, size.y - 1)), "last tile inside")
		t.ok(not world.in_store(Vector2i(size.x, 0)), "x == width outside")
		t.ok(not world.in_store(Vector2i(0, size.y)), "y == height outside")
		world.queue_free()
	await tree.process_frame


func test_hover_highlight_matches_diamond_under_cursor(t, tree) -> void:
	var world := _world(tree, 16, 12)
	var overlay := world.get_node("SelectionOverlay")
	for c in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 11), Vector2i(15, 11), Vector2i(7, 6)]:
		var centre: Vector2 = world.projection.tile_center(c)
		t.eq(world.set_hover_screen(centre), c, "hover centre of %s" % str(c))
		t.eq(overlay.polygon, world.projection.tile_diamond(c), "highlight is exactly the tile diamond")
		var near_corner: Vector2 = centre.lerp(world.projection.tile_diamond(c)[1], 0.99)
		t.eq(world.set_hover_screen(near_corner), c, "just inside the right corner still %s" % str(c))
	t.eq(world.set_hover_screen(world.projection.world_to_screen(-0.7, 3)), Vector2i(-1, -1), "outside floor clears hover")
	t.eq(overlay.polygon.size(), 0, "highlight cleared")
	world.queue_free()
	await tree.process_frame


func test_entrance_tiles_are_on_the_west_edge(t, tree) -> void:
	var world := _world(tree, 16, 12)
	t.eq(world.entrance_tiles, [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i], "fixed entrance (0,5),(0,6)")
	world.queue_free()
	await tree.process_frame
