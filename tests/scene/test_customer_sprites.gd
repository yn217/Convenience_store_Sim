extends RefCounted
## Issue #23: customer sprite manifests, facing/animation choice and the shared ground anchor.


func test_manifests_load_for_three_variants(t, _tree) -> void:
	var sprites := CustomerSprites.new()
	var anchors := {}
	for vid in CustomerSprites.VARIANTS:
		var v := sprites.variant(vid)
		t.ok(not v.is_empty(), "%s loads" % vid)
		anchors[vid] = v["anchor"]
		for d in 4:
			t.eq(v["frames"][d]["walk"].size(), 6)
			t.eq(v["frames"][d]["idle"].size(), 2)
			t.eq(v["frames"][d]["inspect"].size(), 4)
			for anim in v["frames"][d]:
				for tex in v["frames"][d][anim]:
					t.eq(tex.get_size(), v["canvas"], "every frame has the one canvas (feet cannot move)")
	t.ok(sprites.variant("customer_zzz").is_empty(), "unknown art falls back to a placeholder")


func test_variant_choice_is_stable_and_mixed(t, _tree) -> void:
	t.eq(CustomerSprites.variant_for("cust_000004"), CustomerSprites.variant_for("cust_000004"))
	var seen := {}
	for i in 12:
		seen[CustomerSprites.variant_for("cust_%06d" % i)] = true
	t.eq(seen.size(), 3, "several customers in a row look different")


func test_facing_follows_movement(t, _tree) -> void:
	t.eq(CustomerSprites.facing_for(Vector2(0.4, 0.0), 3), CustomerSprites.FACING_E)
	t.eq(CustomerSprites.facing_for(Vector2(0.0, 0.4), 3), CustomerSprites.FACING_S)
	t.eq(CustomerSprites.facing_for(Vector2(-0.4, 0.0), 0), CustomerSprites.FACING_W)
	t.eq(CustomerSprites.facing_for(Vector2(0.0, -0.4), 0), CustomerSprites.FACING_N)
	t.eq(CustomerSprites.facing_for(Vector2.ZERO, 2), 2, "standing keeps the last facing")


func test_animation_by_phase_and_frame_clock(t, _tree) -> void:
	t.eq(CustomerSprites.anim_for("WALK_SHELF"), "walk")
	t.eq(CustomerSprites.anim_for("EXIT"), "walk")
	t.eq(CustomerSprites.anim_for("SELECT"), "inspect")
	t.eq(CustomerSprites.anim_for("QUEUE"), "idle")
	var walk := {"frames": 6, "fps": 8.0, "loop": true}
	t.eq(CustomerSprites.frame_index(walk, 0.0), 0)
	t.eq(CustomerSprites.frame_index(walk, 0.13), 1)
	t.eq(CustomerSprites.frame_index(walk, 0.75), 0, "one cycle = 0.75 s")
	var inspect := {"frames": 4, "fps": 4.0 / 0.45, "loop": false}
	t.eq(CustomerSprites.frame_index(inspect, 5.0), 3, "a non-looping pose holds its last frame")


func test_presenter_moves_smoothly_and_pauses_at_speed_zero(t, tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	world.fixture_catalog = fixtures
	var c := {"customer_id": "cust_000001", "tile": Vector2i(2, 2), "phase": "WALK_SHELF", "next": Vector2i(3, 2), "progress": 0.0}
	var snap := {"store_width": 20, "store_height": 12, "revision": 1, "entrance_tiles": [Vector2i(0, 5)] as Array[Vector2i],
		"fixtures": [], "customers": [c], "shelf_stock": {}, "speed_setting": 1}
	world.apply_snapshot(snap)
	var p: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	p._sync_customers(0.0)
	t.eq(p.customer_view(c)["pos"], Vector2(2, 2))
	c["progress"] = 0.6
	p._sync_customers(0.1)
	var mid: Vector2 = p.customer_view(c)["pos"]
	t.ok(mid.x > 2.0 and mid.x < 2.6, "eases toward the new position instead of jumping: %s" % str(mid))
	t.eq(p.customer_view(c)["facing"], CustomerSprites.FACING_E)
	t.eq(p.customer_view(c)["anim"], "walk")
	# At speed 0 the animation clock does not advance.
	snap["speed_setting"] = 0
	world.apply_snapshot(snap)
	var before: float = p.anim_time
	p._process(0.5)
	t.eq(p.anim_time, before)
	snap["speed_setting"] = 2
	world.apply_snapshot(snap)
	p._process(0.5)
	t.ok(absf(p.anim_time - before - 1.0) < 1e-6, "speed 2 runs the clock at game time")
	# A customer far from its target (teleport / spawn) is placed, not dragged across the floor.
	c["tile"] = Vector2i(10, 8)
	c["next"] = Vector2i(10, 8)
	p._sync_customers(0.1)
	t.eq(p.customer_view(c)["pos"], Vector2(10, 8))
	# Leaving customers are forgotten.
	world.apply_snapshot({"store_width": 20, "store_height": 12, "revision": 2, "entrance_tiles": [Vector2i(0, 5)] as Array[Vector2i],
		"fixtures": [], "customers": [], "shelf_stock": {}})
	p._sync_customers(0.1)
	t.ok(p._pos.is_empty())
	world.queue_free()
	await tree.process_frame
