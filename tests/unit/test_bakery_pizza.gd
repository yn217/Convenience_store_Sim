extends RefCounted
## Issue #130 phase 1: fresh bread baked into the bakery oven's trays (keeps 8 hours, then wasted) and pizza baked
## to order at the pizza oven (the customer waits while it bakes); sold in a running store; visitors who come for
## them only when the store has an oven.

const Run := preload("res://tests/support/basket_run.gd")


func test_baked_and_sold(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := 0
	for type_id in ["bakery_oven", "pizza_oven"]:
		var done := false
		for y in range(1, s.grid.height - 2):
			for x in range(1, s.grid.width - 1):
				if not done and cmds.execute({"command_id": "o_%s_%d_%d" % [type_id, x, y], "kind": &"PLACE_FIXTURE", "type_id": type_id, "x": x, "y": y, "rotation": 0}).ok:
					done = true
					placed += 1
	t.eq(placed, 2, "both ovens placed")
	Run.run_days(s, cmds, 1, 12)
	var sold := {}
	var wasted := 0
	for tx in s.ledger.transactions:
		var cat := String(s.products.get_sku(String(tx["details"].get("sku_id", ""))).get("category", ""))
		if tx["event_type"] == "SALE" and ["bakery", "pizza"].has(cat):
			sold[cat] = int(sold.get(cat, 0)) + int(tx["details"].get("qty", 1))
		if tx["event_type"] == "WASTAGE" and cat == "bakery":
			wasted += int(tx["details"].get("qty", 0))
	t.ok(int(sold.get("bakery", 0)) > 0, "fresh bread sold (%d)" % int(sold.get("bakery", 0)))
	t.ok(int(sold.get("pizza", 0)) > 0, "pizzas sold (%d)" % int(sold.get("pizza", 0)))
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pick := Lcg32.new(21)
	var money := Lcg32.new(22)
	var n := 0
	for i in 2000:
		if VisitPurpose.draw(pick, money, 8, balance, "", ["drink", "rice_ball", "bread"])["purpose_id"] == "fresh_bake":
			n += 1
	t.eq(n, 0, "no oven: nobody comes for fresh bread")


## Phase 2: a lot of dough put in the bakery oven is not on sale while it bakes; after 20 minutes it is on the trays
## and keeps 8 hours from then; a lot still baking survives a save; the card says it is baking.
func test_a_lot_bakes_before_it_is_on_sale(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var oven := ""
	for y in range(1, s.grid.height - 2):
		for x in range(1, s.grid.width - 1):
			if oven == "":
				var r := cmds.execute({"command_id": "ov_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "bakery_oven", "x": x, "y": y, "rotation": 0})
				if r.ok:
					oven = r.data["instance_id"]
	t.ok(cmds.execute({"command_id": "o1", "kind": &"ORDER_STOCK", "sku_id": "bake_001", "qty": 8}).ok, "dough ordered")
	t.ok(cmds.execute({"command_id": "r1", "kind": &"RESTOCK", "instance_id": oven, "slot_id": "tray0", "sku_id": "bake_001", "qty": 8}).ok, "into the oven")
	var in_oven := s.inventory_segments.filter(func(g): return g["location"]["kind"] == "OVEN")
	t.eq(in_oven.size(), 1, "a lot is baking")
	t.eq(int(s.snapshot()["shelf_stock"].get(oven, {}).get("tray0", 0)), 0, "nothing on sale yet")
	t.ok(not cmds.execute({"command_id": "r2", "kind": &"RESTOCK", "instance_id": oven, "slot_id": "tray0", "sku_id": "bake_001", "qty": 1}).ok, "the tray is taken by the lot in the oven")
	t.ok(FixtureCard.baking_text(s.snapshot()["baking"][oven]).contains("焼成中 8個（あと20分）"), "the card says it bakes")
	var saved := SaveGame.to_dict(s, "bake", "2026-10-28T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).bakes_pending, 1, "a lot still baking survives a save")
	s.time_sec += 1199
	t.eq(Cooking.finish_bakes(s), 0, "not yet")
	s.time_sec += 1
	t.eq(Cooking.finish_bakes(s), 8, "baked: 8 on the tray")
	t.eq(int(s.snapshot()["shelf_stock"].get(oven, {}).get("tray0", 0)), 8, "on sale")
	var seg: Dictionary = s.inventory_segments.filter(func(g): return g["location"].get("fixture_id", "") == oven)[0]
	t.eq(int(seg["expires_at_sec"]), s.time_sec + 28800, "keeps 8 hours from the bake")
	t.ok(s.take_events().any(func(e): return e["type"] == "BAKE_DONE"), "the bake is an event")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the stock stays consistent")
