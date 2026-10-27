extends RefCounted
## Issue #139 phase 1: capsule toy machines — the 1 / 3 / 5 machine fixtures and the capsule series, the prize of a
## turn (from the sale id, one in rare_one_in rare), turns paid at the machine (never at the till), and a store
## without machines that keeps its old behaviour.

const Run := preload("res://tests/support/basket_run.gd")


func test_machines_and_series(t, _tree) -> void:
	var s := Run.new_state(100.0)
	for x in [["capsule_toy_1", 1, 1], ["capsule_toy_3", 2, 3], ["capsule_toy_5", 3, 5]]:
		var def := s.fixtures.get_type(x[0])
		t.ok(not def.is_empty(), x[0] + " exists")
		t.eq(int(def["footprint"]["w"]), x[1], x[0] + ": width")
		t.eq((def["shelf_slots"] as Array).size(), x[2], x[0] + ": one series per machine")
		t.eq(BuildCatalog.category_of(def), BuildCatalog.SERVICE, x[0] + ": listed under 設備")
	var skus: Array = s.products.skus.values().filter(func(k): return k["category"] == "capsule_toy")
	t.eq(skus.size(), 3, "three capsule series")
	for k in skus:
		t.ok(not CapsuleToys.series(k["sku_id"]).is_empty(), "%s: its prizes" % k["sku_id"])
		t.ok(int(k["default_sell_price_yen"]) > int(k["purchase_cost_yen"]), "%s: a turn earns more than the capsule costs" % k["sku_id"])
		t.ok(ProductIcons.texture(k, 32).get_image().get_used_rect().size.x > 10, "%s: an icon" % k["sku_id"])


func test_the_prize_of_a_turn(t, _tree) -> void:
	t.eq(CapsuleToys.prize_of("capsule_001", "sale:res_x_0"), CapsuleToys.prize_of("capsule_001", "sale:res_x_0"), "the same sale, the same prize")
	var rare := 0
	var names := {}
	for i in 1200:
		var p := CapsuleToys.prize_of("capsule_001", "sale:res_cust_%05d_0" % i)
		names[p["name"]] = true
		if p["rare"]:
			rare += 1
	t.ok(rare > 50 and rare < 160, "about one in 12 is rare (%d of 1200)" % rare)
	t.eq(names.size(), 6, "every prize comes out: %s" % str(names.keys()))


## A machine in a running store: customers come to turn it, pay at the machine (no till), the turns and rare prizes
## are counted and survive a save; the ledger stays consistent.
func test_turns_are_paid_at_the_machine(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(1, s.grid.height - 1):
		for x in range(1, s.grid.width - 2):
			if placed == "":
				var r := cmds.execute({"command_id": "cap_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "capsule_toy_3", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.ok(placed != "", "a 3-machine unit placed")
	var seen_till := false
	Run.run_days(s, cmds, 2)
	var turns := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["details"].get("sku_id", "")).begins_with("capsule_"):
			turns += int(tx["details"].get("qty", 1))
			if String(tx["details"].get("transaction_id", "")) != String(tx["event_id"]):
				seen_till = true
	t.ok(turns > 0, "customers turned the machines (%d)" % turns)
	t.ok(not seen_till, "every turn paid at the machine")
	var counted := 0
	var rare := 0
	for k in s.capsule_stats:
		counted += int(s.capsule_stats[k]["turns"])
		rare += int(s.capsule_stats[k]["rare"])
	t.eq(counted, turns, "every turn counted")
	t.ok(rare <= turns, "rare prizes among them (%d)" % rare)
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "cap", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).capsule_stats, s.capsule_stats, "the counts survive a save")
	t.ok(CueText.toast_text("capsule_rare", {"prize": "きんいろのねこ", "name": "x"}).contains("きんいろのねこ"), "a rare prize is announced")


## Without a machine nobody comes for capsules.
func test_no_machine_no_capsule_visitors(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pick := Lcg32.new(5)
	var money := Lcg32.new(6)
	var n := 0
	var m := 0
	for i in 2000:
		if VisitPurpose.draw(pick, money, 16, balance, "", ["drink", "snack", "rice_ball"])["purpose_id"] == "capsule_toy":
			n += 1
		if VisitPurpose.draw(pick, money, 16, balance, "", ["drink", "snack", "rice_ball", "capsule_toy"])["purpose_id"] == "capsule_toy":
			m += 1
	t.eq(n, 0, "no machine: nobody comes to turn one")
	t.ok(m > 20, "with a machine some come for it after school (%d)" % m)
