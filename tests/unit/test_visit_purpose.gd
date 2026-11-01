extends RefCounted
## Issue #141: visit purposes, budget and wallet, impulse pick-ups on the way, and the customer panel.
## Day runs use the sample layout (tests/support/basket_run.gd, legacy pace so a day stays quick to run).

const Run := preload("res://tests/support/basket_run.gd")
const Seeds := preload("res://tests/support/test_seeds.gd")


func _balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))


func test_purpose_table_is_well_formed(t, _tree) -> void:
	var b := _balance()
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var cats := {}
	for sku in pr.skus.values():
		cats[sku["category"]] = true
	var ids := {}
	for p in b["visit_purposes"]:
		t.ok(not ids.has(p["purpose_id"]), "unique id " + p["purpose_id"])
		ids[p["purpose_id"]] = true
		t.ok(String(p["display_name"]) != "", "a name for the panel")
		t.eq((p["hour_weights"] as Array).size(), 24, p["purpose_id"] + ": 24 hour weights")
		t.ok(int(p["budget_yen"][0]) > 0 and int(p["budget_yen"][0]) <= int(p["budget_yen"][1]), p["purpose_id"] + ": budget range")
		t.ok(float(p["wallet_factor"][0]) >= 1.0, p["purpose_id"] + ": the wallet covers the budget")
		t.ok((p["targets"] as Array).size() >= 1 and (p["targets"] as Array).size() <= BasketModel.MAX_SIZE, p["purpose_id"] + ": 1..4 target slots")
		for slot in p["targets"]:
			for c in slot:
				t.ok(c == VisitPurpose.ANY or cats.has(c), "%s: category %s exists" % [p["purpose_id"], c])
	for h in 24:
		var total := 0.0
		for p in b["visit_purposes"]:
			total += float(p["hour_weights"][h])
		t.ok(total > 0.0, "some purpose at %d:00" % h)


func _shares(hour: int, n: int) -> Dictionary:
	var b := _balance()
	var pick := Lcg32.new(1234)
	var money := Lcg32.new(99)
	var out := {}
	for i in n:
		var v := VisitPurpose.draw(pick, money, hour, b)
		out[v["purpose_id"]] = int(out.get(v["purpose_id"], 0)) + 1
		var p := VisitPurpose.find(b, v["purpose_id"])
		if i < 300:
			t_budget_checks.append([v, p])
	return out


var t_budget_checks: Array = []


func _top(shares: Dictionary) -> String:
	var best := ""
	for k in shares:
		if best == "" or int(shares[k]) > int(shares[best]):
			best = k
	return best


func test_purposes_follow_the_time_of_day(t, _tree) -> void:
	t.eq(_top(_shares(8, 2000)), "breakfast", "8:00 is breakfast time")
	t.eq(_top(_shares(12, 2000)), "lunch", "12:00 is lunch")
	t.eq(_top(_shares(15, 2000)), "snack_time", "15:00 is snack time")
	t.eq(_top(_shares(23, 2000)), "late_night", "23:00 is a late-night snack")
	for e in t_budget_checks:
		var v: Dictionary = e[0]
		var p: Dictionary = e[1]
		t.ok(int(v["budget_yen"]) >= int(p["budget_yen"][0]) - 10 and int(v["budget_yen"]) <= int(p["budget_yen"][1]) + 10, "budget in range")
		t.ok(int(v["wallet_yen"]) >= int(v["budget_yen"]), "the wallet covers the budget")
		t.eq(int(v["budget_yen"]) % 10, 0, "budget in tens of yen")
		t.eq(int(v["slots"]), (p["targets"] as Array).size(), "one basket slot per target")


## One fixed-seed day on the sample layout with purposes: the money rules hold at every step, impulse pick-ups
## happen and are paid for, and the panel can describe every customer.
func test_a_day_with_purposes_keeps_the_money_rules(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	var impulses := 0
	var impulse_ids := {}
	var too_expensive := 0
	var purposes := {}
	var checked := 0
	var paid_impulse := 0
	while s.day == 0:
		runner._run_step()
		for c in s.customers:
			if String(c.get("purpose_id", "")) == "":
				continue
			purposes[c["purpose_id"]] = true
			var target_yen := 0
			var all_yen := 0
			for e in c["basket_log"]:
				if e["state"] == "planned" or e["state"] == "taken":
					all_yen += int(e["price"])
					if e["kind"] == "target":
						target_yen += int(e["price"])
			if target_yen > int(c["budget_yen"]):
				t.ok(false, "%s: target items %d stay within the budget %d" % [c["customer_id"], target_yen, c["budget_yen"]])
			if all_yen > int(c["wallet_yen"]):
				t.ok(false, "%s: everything %d stays within the wallet %d" % [c["customer_id"], all_yen, c["wallet_yen"]])
			if all_yen != int(c["planned_yen"]):
				t.ok(false, "%s: planned_yen %d matches the log %d" % [c["customer_id"], c["planned_yen"], all_yen])
			checked += 1
		for e in s.event_log.slice(maxi(s.event_log.size() - 40, 0)):   # this step's events (a step emits far fewer)
			if int(e["tick"]) != s.time_sec:
				continue
			if e["type"] == "CUSTOMER_IMPULSE":
				impulses += 1
				impulse_ids[e["payload"]["customer_id"]] = true
			elif e["type"] == "SALE_COMMITTED" and impulse_ids.has(e["payload"]["customer_id"]):
				paid_impulse += 1
	for c in s.customers:
		for e in c.get("basket_log", []):
			if e["state"] == "too_expensive":
				too_expensive += 1
	t.ok(checked > 1000, "customer steps checked: %d" % checked)
	t.ok(purposes.size() >= 5, "a day brings many purposes: %s" % str(purposes.keys()))
	t.ok(impulses > 0, "customers picked things up on the way: %d" % impulses)
	t.ok(paid_impulse > 0, "impulse customers paid at the till: %d sales" % paid_impulse)


## Higher prices: fewer items fit the budgets and fewer are bought (the spend per customer drives the sales).
func test_higher_prices_sell_fewer_units(t, _tree) -> void:
	var base := _day({})
	var dear := _day({"markup": 1.6})
	t.ok(int(dear["units"]) < int(base["units"]), "units fall when prices rise 60%%: %d < %d" % [dear["units"], base["units"]])
	t.ok(int(dear["declined"]) > int(base["declined"]), "more items are declined (too dear or not bought): %d > %d" % [dear["declined"], base["declined"]])


## One day on the sample layout; markup multiplies every price. -> {units sold, declined basket items}.
func _day(opts: Dictionary) -> Dictionary:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	Run.restock(s, cmds, 0)
	if opts.has("markup"):
		var n := 0
		for sku in s.products.skus.values():
			n += 1
			var price := int(round(float(sku["default_sell_price_yen"]) * float(opts["markup"]) / 10.0)) * 10
			cmds.execute({"command_id": "pr%d" % n, "kind": &"SET_PRICE", "sku_id": sku["sku_id"], "price_yen": price})
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	var last_log := {}   # customer -> its basket log as last seen (customers leave with it)
	while s.day == 0:
		runner._run_step()
		for c in s.customers:
			last_log[c["customer_id"]] = c.get("basket_log", [])
	var declined := 0
	for log in last_log.values():
		for e in log:
			if e["state"] == "too_expensive" or e["state"] == "not_bought":
				declined += 1
	var units := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE":
			units += int(tx["details"]["qty"])
	return {"units": units, "declined": declined}


func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total


func test_panel_lines(t, _tree) -> void:
	var c := {"customer_id": "cust_00007", "phase": "QUEUE", "queue_slot": 1, "purpose_name": "昼食", "wallet_yen": 2340,
		"budget_yen": 900, "planned_yen": 460, "impulse_count": 1, "basket_log": [
			{"name": "鮭おにぎり", "price": 160, "kind": "target", "state": "taken"},
			{"name": "緑茶500ml", "price": 150, "kind": "target", "state": "planned"},
			{"name": "板チョコ", "price": 150, "kind": "impulse", "state": "taken"},
			{"name": "チーズケーキ", "price": 380, "kind": "target", "state": "too_expensive"}]}
	var lines := OverlayModel.customer_panel_lines(c, "")
	t.eq(lines[0], "客 cust_00007　来店目的：昼食")
	t.eq(lines[1], "所持金 ¥2,340　予算 ¥900　予定 ¥460")
	t.eq(lines[2], "かご：✔鮭おにぎり ¥160、・緑茶500ml ¥150、✔★板チョコ ¥150")
	t.eq(lines[3], "買わなかった：チーズケーキ ¥380（予算オーバー）")
	t.eq(lines[4], "★ ついで買い 1点")
	t.eq(lines[5], "状態：会計待ち (2番目)")
	var old := OverlayModel.customer_panel_lines({"customer_id": "cust_00001", "phase": "EXIT"}, "")
	t.eq(old[0], "客 cust_00001　来店目的：（記録なし）", "an old save's customer has no purpose")
	t.eq(OverlayModel.yen(1234567), "¥1,234,567")
