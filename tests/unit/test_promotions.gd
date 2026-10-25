extends RefCounted
## Issue #137 phase 1: price sales and bundles — the price customers see, the setup cost, the bundle discount at
## the till, start / stop / expiry, the results per promotion and the save round trip.

const Run := preload("res://tests/support/basket_run.gd")


static func _sku_of(s: GameState, category: String) -> String:
	for sku in s.products.skus.values():
		if sku["category"] == category:
			return sku["sku_id"]
	return ""


static func _units_of(s: GameState, category: String) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and s.products.get_sku(tx["details"]["sku_id"])["category"] == category:
			n += int(tx["details"]["qty"])
	return n


func test_definitions_are_well_formed(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cats := {}
	for sku in s.products.skus.values():
		cats[sku["category"]] = true
	for d in Promotions.data()["promotions"]:
		t.ok(["price", "bundle"].has(d["kind"]), d["def_id"] + ": known kind")
		t.ok(int(d["setup_cost_yen"]) > 0 and int(d["default_days"]) >= 1, d["def_id"] + ": cost and days")
		var used: Array = d.get("categories", [])
		for g in d.get("bundle", []):
			used.append_array(g)
		for c in used:
			t.ok(cats.has(c), "%s: category %s exists" % [d["def_id"], c])


func test_price_sales_change_what_customers_pay(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var onigiri := _sku_of(s, "rice_ball")
	var bread := _sku_of(s, "bread")
	var oden := _sku_of(s, "oden")
	var list_bread := s.list_price(bread)
	var cash := s.cash_yen
	for id in ["sale_onigiri", "sale_bread_morning", "sale_oden"]:
		t.ok(cmds.execute({"command_id": "p_" + id, "kind": &"START_PROMOTION", "def_id": id, "days": 2}).ok, id + " starts")
	t.eq(s.cash_yen, cash - 3000 - 2000 - 2000, "the setup costs are paid")
	var sum := LedgerSummary.summarize(s.ledger, s.day)
	t.eq(int(sum["promo_yen"]), 7000, "booked as 販促費")
	t.eq(int(sum["operating_profit_yen"]), int(sum["gross_profit_yen"]) - int(sum["fixed_cost_yen"]) - int(sum["advertising_yen"]) - int(sum["electricity_yen"]) - int(sum["wastage_yen"]) - int(sum["wages_yen"]) - 7000, "and comes off the operating profit")
	t.eq(s.sell_price(onigiri), 100, "おにぎり at the flat 100 yen")
	t.eq(s.list_price(onigiri), int(s.products.get_sku(onigiri)["default_sell_price_yen"]), "the list price is untouched")
	t.eq(s.sell_price(oden), int(round(s.list_price(oden) * 0.7 / 10.0)) * 10, "おでん 30% off, to 10 yen")
	s.time_sec = 7 * 3600
	t.eq(s.sell_price(bread), int(round(list_bread * 0.8 / 10.0)) * 10, "bread 20% off at 7:00")
	s.time_sec = 13 * 3600
	t.eq(s.sell_price(bread), list_bread, "and the list price at 13:00")
	t.ok(not cmds.execute({"command_id": "p_again", "kind": &"START_PROMOTION", "def_id": "sale_oden", "days": 2}).ok, "one of each at a time")
	var r := cmds.execute({"command_id": "p_4th", "kind": &"START_PROMOTION", "def_id": "sale_coffee", "days": 2})
	t.ok(not r.ok and r.message_key == &"too_many_promotions", "at most three at once")
	var id_oden: String = s.promotions[2]["promotion_id"]
	t.ok(cmds.execute({"command_id": "p_stop", "kind": &"STOP_PROMOTION", "promotion_id": id_oden}).ok, "stopped")
	t.eq(s.sell_price(oden), s.list_price(oden), "back to the list price")
	s.day += 2
	t.eq(s.sell_price(onigiri), s.list_price(onigiri), "a promotion ends after its days")
	t.eq(Promotions.running(s).size(), 0)


func test_a_sale_sells_more_and_books_the_discount(t, _tree) -> void:
	var units := {}
	for promo in [false, true]:
		var s := Run.new_state(300.0)
		var cmds := Run.place_layout(s)
		if promo:
			cmds.execute({"command_id": "p1", "kind": &"START_PROMOTION", "def_id": "sale_onigiri", "days": 2})
		Run.run_days(s, cmds, 2)
		units[promo] = _units_of(s, "rice_ball")
		if promo:
			var disc := 0
			for tx in s.ledger.transactions:
				if tx["event_type"] == "SALE" and tx["details"].has("discount_yen"):
					t.eq(int(tx["revenue_delta_yen"]), 100 * int(tx["details"]["qty"]), "sold at the sale price")
					disc += int(tx["details"]["discount_yen"])
			var st: Dictionary = s.promo_stats[s.promotions[0]["promotion_id"]]
			t.eq(int(st["units"]), units[true], "every onigiri sold was on the deal")
			t.eq(int(st["discount_yen"]), disc, "and the discount adds up")
	t.ok(int(units[true]) > int(units[false]), "the sale sells more onigiri (%d > %d)" % [units[true], units[false]])


func test_bundle_discount_needs_both_groups(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "b1", "kind": &"START_PROMOTION", "def_id": "bundle_morning", "days": 2})
	t.eq(Promotions.bundle_for(s, ["bread", "drink"]).get("yen", 0), 50, "bread + drink")
	t.eq(Promotions.bundle_for(s, ["rice_ball", "drink", "snack"]).get("yen", 0), 50, "onigiri + drink")
	t.ok(Promotions.bundle_for(s, ["rice_ball", "bread"]).is_empty(), "no drink, no discount")
	Run.run_days(s, cmds, 2)
	var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "DISCOUNT")
	t.ok(rows.size() > 0, "some baskets earned the bundle (%d)" % rows.size())
	for tx in rows:
		t.eq(int(tx["cash_delta_yen"]), -50, "50 yen back")
		var basket: String = String(tx["event_id"]).trim_suffix(":BUNDLE")
		var cats: Array = s.ledger.transactions.filter(func(x): return x["event_type"] == "SALE" and x["details"]["transaction_id"] == basket) \
			.map(func(x): return s.products.get_sku(x["details"]["sku_id"])["category"])
		t.ok(cats.has("drink") and (cats.has("bread") or cats.has("rice_ball")), "the basket held both: %s" % str(cats))
	t.eq(int(s.promo_stats[s.promotions[0]["promotion_id"]]["discount_yen"]), 50 * rows.size(), "results count the bundles")
	var report: Dictionary = s.daily_reports[0]
	t.ok(int(report["discount_yen"]) > 0 and int(report["promo_yen"]) == 3000, "the day's report shows 販促費 and 値引き")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")


func test_promotions_survive_a_save(t, _tree) -> void:
	var s := Run.new_state(200.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "s1", "kind": &"START_PROMOTION", "def_id": "sale_onigiri", "days": 3})
	cmds.execute({"command_id": "s2", "kind": &"START_PROMOTION", "def_id": "bundle_lunch", "days": 3})
	Run.run_days(s, cmds, 1)
	var saved := SaveGame.to_dict(s, "promo", "2026-10-25T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	if not lr["ok"]:
		return
	var b: GameState = lr["state"]
	t.eq(b.promotions, s.promotions, "promotions come back")
	t.eq(b.promo_stats, s.promo_stats, "with their results")
	t.eq(b.next_promotion_seq, s.next_promotion_seq)
	t.eq(b.sell_price(_sku_of(b, "rice_ball")), 100, "the sale still runs")
	var views: Array = b.snapshot()["promotions"]
	var on := views.filter(func(v): return not (v["running"] as Dictionary).is_empty())
	t.eq(on.size(), 2, "the card sees two running")
	t.eq(int(on[0]["running"]["days_left"]), 2, "two days left on day 1")
