extends RefCounted
## Issue #133 phase 1: daily goods (socks, underwear, umbrellas) and hygiene goods (masks, plasters, wet wipes) on
## a goods shelf, and the visitors who come for them — only when the store carries them. No medicines.

const Run := preload("res://tests/support/basket_run.gd")
const NEW := ["daily_goods", "hygiene"]


func test_visitors_come_only_when_carried(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pick := Lcg32.new(11)
	var money := Lcg32.new(12)
	var without := 0
	var n_with := 0
	for i in 3000:
		if VisitPurpose.draw(pick, money, 10, balance, "", ["drink", "snack", "rice_ball"])["purpose_id"] == "sudden_need":
			without += 1
		if VisitPurpose.draw(pick, money, 10, balance, "", ["drink", "snack", "rice_ball", "hygiene"])["purpose_id"] == "sudden_need":
			n_with += 1
	t.eq(without, 0, "no goods shelf: nobody comes for a mask")
	t.ok(n_with > 20, "with one, some come for it (%d)" % n_with)


func test_goods_sell_in_a_running_store(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(1, s.grid.height - 2):
		for x in range(1, s.grid.width - 1):
			if placed == "":
				var r := cmds.execute({"command_id": "g_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "shelf_goods", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.ok(placed != "", "a goods shelf placed")
	cmds.execute({"command_id": "o1", "kind": &"ORDER_STOCK", "sku_id": "hyg_001", "qty": 10})
	cmds.execute({"command_id": "r1", "kind": &"RESTOCK", "instance_id": placed, "slot_id": "row1", "sku_id": "hyg_001", "qty": 10})
	Run.run_days(s, cmds, 1, 14)
	var sold := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and ["daily_goods", "hygiene"].has(String(s.products.get_sku(String(tx["details"].get("sku_id", ""))).get("category", ""))):
			sold += int(tx["details"].get("qty", 1))
	t.ok(sold > 0, "goods sold (%d)" % sold)
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
