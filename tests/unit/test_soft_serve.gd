extends RefCounted
## Issue #131 phase 1: soft serve and frappé made to order — their machines and mixes, the wait at the machine while
## one is made, sales in a running store, and visitors who come for them only when the store has a machine.

const Run := preload("res://tests/support/basket_run.gd")


## The customer stands at the machine while it is made: the time at the shelf grows by the making time.
func test_the_wait_while_it_is_made(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var ai := CustomerAI.new()
	var steps := func(sku_id: String) -> int:
		var c := {"customer_id": "cust_00001", "fixture_id": "f1", "sku_id": sku_id}
		var n := 1
		while not ai._browsed(s, c):
			n += 1
		return n
	var plain := int(steps.call("snack_001"))
	var frappe := int(steps.call("frappe_001"))
	t.ok(frappe - plain >= int(float(Cooking.prep_seconds("frappe")) / GameClock.STEP_GAME_SECONDS) - 1, "the making time is added (%d vs %d steps)" % [frappe, plain])


func test_sold_in_a_running_store(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := 0
	for type_id in ["soft_serve_machine", "frappe_blender"]:
		var done := false
		for y in range(1, s.grid.height - 1):
			for x in range(1, s.grid.width - 1):
				if not done and cmds.execute({"command_id": "m_%s_%d_%d" % [type_id, x, y], "kind": &"PLACE_FIXTURE", "type_id": type_id, "x": x, "y": y, "rotation": 0}).ok:
					done = true
					placed += 1
	t.eq(placed, 2, "both machines placed")
	Run.run_days(s, cmds, 1, 16)
	var sold := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and ["soft_serve", "frappe"].has(String(s.products.get_sku(String(tx["details"].get("sku_id", ""))).get("category", ""))):
			sold += int(tx["details"].get("qty", 1))
	t.ok(sold > 0, "soft serve and frappé sold (%d)" % sold)
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pick := Lcg32.new(3)
	var money := Lcg32.new(4)
	var n := 0
	for i in 2000:
		if VisitPurpose.draw(pick, money, 14, balance, "", ["drink", "snack"])["purpose_id"] == "sweet_treat":
			n += 1
	t.eq(n, 0, "no machine: nobody comes for a soft serve")
