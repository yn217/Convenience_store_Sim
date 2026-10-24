extends RefCounted
## Issue #104: the customer variant pool is deterministic, and the clerk stands on the back side of a register
## for all four rotations, facing the customer side.


func _register() -> Dictionary:
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	return fx.get_type("register_basic")


func test_variant_pool_is_deterministic_and_covers_the_new_looks(t, _tree) -> void:
	var pool := CustomerSprites.VARIANTS
	t.eq(pool.size(), 6, "six new looks in the pool")
	for vid in ["office_worker", "student_uniform", "casual_woman", "casual_man", "older_person", "parent"]:
		t.ok(pool.has(vid), "%s is in the pool" % vid)
	t.ok(not pool.has(CustomerSprites.CLERK), "the clerk is never a customer")
	t.ok(not pool.has("customer_a"), "the legacy figures are a fallback, not in the pool")
	# The numeric tail picks the look: index = tail mod pool size.
	t.eq(CustomerSprites.variant_for("cust_000000"), pool[0])
	t.eq(CustomerSprites.variant_for("cust_000013"), pool[13 % pool.size()])
	t.eq(CustomerSprites.variant_for("cust_000013"), CustomerSprites.variant_for("cust_000013"), "same id, same look")
	var seen := {}
	for i in 60:
		var vid := CustomerSprites.variant_for("cust_%06d" % i)
		t.ok(pool.has(vid), "pool member for %d" % i)
		seen[vid] = true
	t.eq(seen.size(), pool.size(), "every look is used")
	# Ids without a numeric tail still map into the pool, the same way every time.
	var named := CustomerSprites.variant_for("walk_in")
	t.ok(pool.has(named), "non-numeric id maps into the pool")
	t.eq(CustomerSprites.variant_for("walk_in"), named, "non-numeric id is stable")


func test_register_is_recognised_and_shelves_are_not(t, _tree) -> void:
	t.ok(ClerkPlacement.is_register(_register()), "register_basic is a register")
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	t.ok(not ClerkPlacement.is_register(fx.get_type("shelf_general")), "a shelf is not a register")


func test_clerk_is_on_the_back_side_for_all_four_rotations(t, _tree) -> void:
	var def := _register()
	# Footprint of register_basic is 1 wide, 2 tall at rotation 0 (cells (5,5),(5,6)); it swaps for rotations 1 and 3.
	# Access edge E turns clockwise with the rotation: E, S, W, N.
	var expected := {
		0: {"cell": Vector2i(4, 5), "pos": Vector2(4.0, 5.5), "facing": CustomerSprites.FACING_E},
		1: {"cell": Vector2i(5, 4), "pos": Vector2(5.5, 4.0), "facing": CustomerSprites.FACING_S},
		2: {"cell": Vector2i(6, 5), "pos": Vector2(6.0, 5.5), "facing": CustomerSprites.FACING_W},
		3: {"cell": Vector2i(5, 6), "pos": Vector2(5.5, 6.0), "facing": CustomerSprites.FACING_N},
	}
	for r in 4:
		var p := ClerkPlacement.placement(def, 5, 5, r)
		t.ok(not p.is_empty(), "rotation %d places a clerk" % r)
		var e: Dictionary = expected[r]
		t.eq(p["cell"], e["cell"], "rotation %d: clerk cell behind the counter" % r)
		t.eq(p["pos"], e["pos"], "rotation %d: clerk feet one tile behind the counter's centre" % r)
		t.eq(p["facing"], e["facing"], "rotation %d: clerk faces the access side" % r)
		# The clerk tile touches the footprint on the back side and is not a footprint cell itself.
		var cells := StoreGrid.footprint_cells(def["footprint"], 5, 5, r)
		t.ok(not cells.has(p["cell"]), "rotation %d: clerk is not on the register" % r)
		var touching := false
		for c in cells:
			if absi(c.x - p["cell"].x) + absi(c.y - p["cell"].y) == 1:
				touching = true
		t.ok(touching, "rotation %d: clerk tile is next to the register" % r)


func test_clerk_pose_follows_checkout(t, _tree) -> void:
	t.eq(ClerkPlacement.anim_for(false), "idle")
	t.eq(ClerkPlacement.anim_for(true), "checkout")
