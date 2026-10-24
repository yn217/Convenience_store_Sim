extends RefCounted
## Issue #104: a clerk stands behind each register, sorts with the register and its customers, switches to the
## checkout pose while a customer of that register is in CHECKOUT, and is never a pick target.


func _snapshot(fixtures: Array, customers: Array, revision: int) -> Dictionary:
	return {"store_width": 20, "store_height": 12, "revision": revision, "entrance_tiles": [Vector2i(0, 5)] as Array[Vector2i],
		"fixtures": fixtures, "customers": customers, "shelf_stock": {}, "speed_setting": 1}


func _clerks(p: Node2D) -> Array:
	var out := []
	for it in p._compose_all():
		if it["kind"] == "clerk":
			out.append(it)
	return out


func test_clerk_per_register_with_checkout_pose_and_draw_order(t, tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var world: Node2D = load("res://scenes/store/StoreWorld.tscn").instantiate()
	tree.root.add_child(world)
	await tree.process_frame   # the presenter's _ready (which finds the world) runs once the node is in the tree
	world.fixture_catalog = fixtures
	var layout := [
		{"instance_id": "reg1", "type_id": "register_basic", "x": 5, "y": 5, "rotation": 0},
		{"instance_id": "reg2", "type_id": "register_basic", "x": 9, "y": 5, "rotation": 2},
		{"instance_id": "shelf1", "type_id": "shelf_general", "x": 2, "y": 2, "rotation": 0},
	]
	var paying := {"customer_id": "cust_000001", "tile": Vector2i(6, 5), "phase": "CHECKOUT", "register_id": "reg1",
		"next": Vector2i(6, 5), "progress": 0.0}
	world.apply_snapshot(_snapshot(layout, [paying], 1))
	var p: Node2D = world.get_node("ObjectSortRoot/FixturePresenter")
	t.ok(not p._people.variant(CustomerSprites.CLERK).is_empty(), "the clerk art loads")

	var clerks := _clerks(p)
	t.eq(clerks.size(), 2, "one clerk per register, none for the shelf")
	var by_reg := {}
	for cl in clerks:
		by_reg[cl["register_id"]] = cl
	t.ok(by_reg.has("reg1") and by_reg.has("reg2"), "a clerk for each register")
	t.eq(by_reg["reg1"]["anim"], "checkout", "reg1 checks out a customer: checkout pose")
	t.eq(by_reg["reg2"]["anim"], "idle", "reg2 is free: idle")

	# Draw order: the clerk on the back side is drawn before its register and the customer on the access side after it.
	var ordered: Array = p._compose_all()
	var clerk_at := -1
	var customer_at := -1
	var reg_first := -1
	for i in ordered.size():
		var it: Dictionary = ordered[i]
		if it["kind"] == "clerk" and it["register_id"] == "reg1":
			clerk_at = i
		elif it["kind"] == "customer":
			customer_at = i
		elif it["kind"] == "fixture" and it["inst"]["instance_id"] == "reg1" and reg_first < 0:
			reg_first = i
	t.ok(clerk_at >= 0 and reg_first >= 0 and clerk_at < reg_first, "the clerk is drawn behind its register")
	t.ok(customer_at > reg_first, "the customer on the access side is drawn in front of the register")

	# Picking never sees a clerk: a click on the clerk's feet picks only customers and fixtures.
	var screen: Vector2 = world.projection.world_to_screen(4.0, 5.5)
	for cand in world.pick_candidates(screen):
		t.ok(cand["kind"] != "clerk", "clerk is not a pick target: %s" % str(cand["kind"]))
	t.ok(p.compose().all(func(it): return it["kind"] != "clerk"), "compose() (the picking list) has no clerk")

	# The customer finishes checkout: the clerk goes back to idle on the next snapshot.
	var leaving := paying.duplicate()
	leaving["phase"] = "EXIT"
	world.apply_snapshot(_snapshot(layout, [leaving], 2))
	for cl in _clerks(p):
		if cl["register_id"] == "reg1":
			t.eq(cl["anim"], "idle", "no customer in CHECKOUT: idle again")

	# No register, no clerk.
	world.apply_snapshot(_snapshot([layout[2]], [], 3))
	t.eq(_clerks(p).size(), 0, "a store without registers has no clerk")
	world.queue_free()
	await tree.process_frame
