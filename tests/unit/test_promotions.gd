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
		t.ok(["price", "bundle", "multi", "second_half", "coupon", "volume_up", "gift", "stamps", "fair", "collab"].has(d["kind"]), d["def_id"] + ": known kind")
		t.ok(int(d["setup_cost_yen"]) > 0 and int(d["default_days"]) >= 1, d["def_id"] + ": cost and days")
		if d["kind"] == "volume_up" or d["kind"] == "collab":
			for sid in d["skus"]:
				t.ok(s.products.has_sku(sid), "%s: product %s exists" % [d["def_id"], sid])
			continue
		var used: Array = d.get("categories", [])
		for g in d.get("bundle", []):
			used.append_array(g)
		used.append_array((d.get("pulls", {}) as Dictionary).keys())
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


## Phase 2: multi-buy deals — the tier and half-price arithmetic.
func test_multi_buy_arithmetic(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "m1", "kind": &"START_PROMOTION", "def_id": "multi_snack", "days": 2})
	cmds.execute({"command_id": "m2", "kind": &"START_PROMOTION", "def_id": "second_half_noodle", "days": 2})
	var snack := func(n: int) -> Array:
		var out: Array = []
		for i in n:
			out.append({"category": "snack", "price": 150})
		return out
	t.eq(Promotions.multi_discounts(s, snack.call(1)), [], "one snack: nothing")
	t.eq(int(Promotions.multi_discounts(s, snack.call(2))[0]["yen"]), 40, "two: 40 yen")
	t.eq(int(Promotions.multi_discounts(s, snack.call(3))[0]["yen"]), 90, "three: 90 yen")
	var noodles := [{"category": "instant_noodle", "price": 200}, {"category": "instant_noodle", "price": 180}, {"category": "drink", "price": 150}]
	t.eq(int(Promotions.multi_discounts(s, noodles)[0]["yen"]), 90, "the second noodle at half its price (180 / 2)")
	t.eq(Promotions.multi_for(s, "snack").get("def_id", ""), "multi_snack")
	t.ok(Promotions.multi_for(s, "drink").is_empty(), "no deal on drinks")


## Phase 2: with the snack deal customers take more snacks, the till books the discount, the ledger stays consistent.
func test_a_multi_buy_deal_sells_more_units(t, _tree) -> void:
	var units := {}
	for promo in [false, true]:
		var s := Run.new_state(300.0)
		var cmds := Run.place_layout(s)
		if promo:
			cmds.execute({"command_id": "p1", "kind": &"START_PROMOTION", "def_id": "multi_snack", "days": 2})
		Run.run_days(s, cmds, 1)
		units[promo] = _units_of(s, "snack")
		if promo:
			var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "DISCOUNT" and String(tx["event_id"]).contains(":MULTI:"))
			t.ok(rows.size() > 0, "baskets earned the deal (%d)" % rows.size())
			for tx in rows:
				t.ok([40, 90].has(-int(tx["cash_delta_yen"])), "a tier's yen: %d" % -int(tx["cash_delta_yen"]))
			var st: Dictionary = s.promo_stats[s.promotions[0]["promotion_id"]]
			t.eq(int(st["discount_yen"]), rows.reduce(func(a, tx): return a + int(tx["expense_delta_yen"]), 0), "results count the discounts")
			t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	t.ok(int(units[true]) > int(units[false]), "more snacks sold with the deal (%d > %d)" % [units[true], units[false]])


## Phase 2: next-visit coupons — issued for a basket of the categories, holders come back while the coupon is
## valid, redeem it at the till (a DISCOUNT row), unused ones expire; coupons survive a save.
func test_next_visit_coupons(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	t.ok(cmds.execute({"command_id": "c1", "kind": &"START_PROMOTION", "def_id": "coupon_meal", "days": 2}).ok, "started")
	var issued := Promotions.issue_coupon(s, ["drink"])
	t.ok(issued.is_empty(), "no coupon for a basket without onigiri or bento")
	Run.run_days(s, cmds, 2)
	var st: Dictionary = s.promo_stats[s.promotions[0]["promotion_id"]]
	t.ok(int(st.get("issued", 0)) > 10, "coupons handed out (%d)" % int(st.get("issued", 0)))
	var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "DISCOUNT" and String(tx["event_id"]).ends_with(":COUPON"))
	t.ok(rows.size() > 0, "holders came back and redeemed (%d)" % rows.size())
	t.eq(int(st.get("redeemed", 0)), rows.size(), "every redemption counted")
	t.eq(int(st.get("discount_yen", 0)), 50 * rows.size(), "50 yen each")
	t.ok(int(st.get("redeemed", 0)) <= int(st.get("issued", 0)), "never more than were issued")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "cpn", "2026-10-26T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).coupons, s.coupons, "outstanding coupons survive a save")
	t.eq((lr["state"] as GameState).promo_stats, s.promo_stats, "with the counts")
	s.day += 10
	Promotions.expire_coupons(s)
	t.eq(s.coupons, [], "unused coupons expire")
	t.ok(PromotionController.promo_line({"display_name": "x", "kind": "coupon", "running": {"days_left": 1, "stats": st}}).contains("配布"), "the card shows issued and used")


## Phase 2: "buy one, the next one free" — the coupon takes the price of the cheapest unit of its category in the
## returning holder's basket.
func test_a_free_item_coupon(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "f1", "kind": &"START_PROMOTION", "def_id": "free_dessert", "days": 2})
	var c := Promotions.issue_coupon(s, ["dessert"])
	t.ok(not c.is_empty(), "issued for a dessert")
	t.eq(Promotions.redeem_coupon(s, c["coupon_id"], [{"category": "drink", "price": 150}]), 0, "no dessert in the basket: not used")
	t.eq(Promotions.redeem_coupon(s, c["coupon_id"], [{"category": "dessert", "price": 280}, {"category": "dessert", "price": 220}, {"category": "drink", "price": 150}]), 220, "the cheaper dessert is free")
	t.eq(s.coupons, [], "and the coupon is gone")
	Run.run_days(s, cmds, 2)
	var prices := {}
	for sku in s.products.skus.values():
		if sku["category"] == "dessert":
			prices[s.list_price(sku["sku_id"])] = true
	var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "DISCOUNT" and String(tx["event_id"]).ends_with(":COUPON"))
	t.ok(rows.size() > 0, "holders came back for their free dessert (%d)" % rows.size())
	for tx in rows:
		t.ok(prices.has(int(tx["expense_delta_yen"])), "a dessert's price comes off: %d" % int(tx["expense_delta_yen"]))
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")


## Phase 2: volume-up products are separate SKUs (same price, more cost, more pull), orderable only while their
## campaign runs; on the shelf they sell at the list price and book their own cost.
func test_volume_up_products(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var r := cmds.execute({"command_id": "v0", "kind": &"ORDER_STOCK", "sku_id": "rice_001_up", "qty": 10})
	t.ok(not r.ok and r.message_key == &"campaign_only_sku", "not orderable without the campaign")
	t.ok(cmds.execute({"command_id": "v1", "kind": &"START_PROMOTION", "def_id": "volume_up_onigiri", "days": 5}).ok, "campaign started")
	t.ok(cmds.execute({"command_id": "v2", "kind": &"ORDER_STOCK", "sku_id": "rice_001_up", "qty": 30}).ok, "orderable during it")
	t.eq(s.list_price("rice_001_up"), s.list_price("rice_001"), "the same price as the regular onigiri")
	var shelf := ""
	for id in s.grid.instances:
		if s.grid.instances[id]["type_id"] == "shelf_onigiri":
			shelf = id
	var slot: String = s.fixtures.get_type("shelf_onigiri")["shelf_slots"][0]["slot_id"]
	t.ok(cmds.execute({"command_id": "v3", "kind": &"RESTOCK", "instance_id": shelf, "slot_id": slot, "sku_id": "rice_001_up", "qty": 10}).ok, "on the shelf")
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	while s.day == 0:
		runner._run_step()
	var sold := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "SALE" and tx["details"]["sku_id"] == "rice_001_up")
	t.ok(sold.size() > 0, "the volume-up onigiri sells (%d)" % sold.size())
	for tx in sold:
		t.eq(int(tx["cogs_delta_yen"]), 125 * int(tx["details"]["qty"]), "at its own, higher cost")
		t.eq(int(tx["revenue_delta_yen"]), 150 * int(tx["details"]["qty"]), "and the regular price")
	s.day += 10
	t.ok(not Promotions.orderable(s, "rice_001_up"), "after the campaign it cannot be ordered again")
	t.ok(Promotions.orderable(s, "rice_001"), "regular products always can")


## #140: a purchase bonus — a basket with three snacks gets the clear file while the stock lasts (bought at the
## start with the setup), customers take more snacks to reach it, and none is given once the stock is gone.
func test_a_gift_while_the_stock_lasts(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var cash := s.ledger.cash_yen
	t.ok(cmds.execute({"command_id": "g1", "kind": &"START_PROMOTION", "def_id": "gift_clearfile", "days": 3}).ok, "started")
	t.eq(cash - s.ledger.cash_yen, 3000 + 40 * 60, "setup and 40 clear files bought at the start")
	var id: String = s.promotions[0]["promotion_id"]
	var snack := {"category": "snack", "price": 150}
	t.eq(Promotions.give_gifts(s, [snack, snack]), [], "two snacks: no gift")
	t.eq(Promotions.give_gifts(s, [snack, snack, snack, {"category": "drink", "price": 150}]), ["限定クリアファイル"], "three snacks: the clear file")
	t.eq(int(s.promo_stats[id]["stock"]), 39, "one fewer left")
	t.ok(Promotions.category_pull(s, "snack") > 1.2, "snacks pull more while it lasts")
	t.eq(int(Promotions.multi_for(s, "snack").get("max_units", 0)), 3, "customers may take more to reach it")
	s.promo_stats[id]["stock"] = 1
	Promotions.give_gifts(s, [snack, snack, snack])
	t.eq(Promotions.give_gifts(s, [snack, snack, snack]), [], "none once the stock is gone")
	t.eq(Promotions.category_pull(s, "snack"), 1.0, "and no more pull")
	t.ok(Promotions.multi_for(s, "snack").is_empty(), "nor a reason to take more")
	t.ok(s.take_events().any(func(e): return e["type"] == "NOVELTY_GONE"), "the end of the stock is an event")
	t.ok(PromotionController.promo_line({"display_name": "x", "kind": "gift", "novelty_name": "限定クリアファイル", "running": {"days_left": 1, "stats": s.promo_stats[id]}}).contains("配布終了"), "the card says so")


## #140: in a running store, the gift is handed out and the stock never goes below 0; the counts survive a save.
func test_gifts_in_a_running_store(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "g1", "kind": &"START_PROMOTION", "def_id": "gift_sticker", "days": 2})
	var id: String = s.promotions[0]["promotion_id"]
	Run.run_days(s, cmds, 2)
	var st: Dictionary = s.promo_stats[id]
	t.ok(int(st.get("given", 0)) > 0, "stickers handed out (%d)" % int(st.get("given", 0)))
	t.eq(int(st["given"]) + int(st["stock"]), 60, "given + left = bought")
	t.ok(int(st["stock"]) >= 0, "never below 0")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "gift", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).promo_stats, s.promo_stats, "the counts survive a save")


## #140: a stamp rally — every 5th basket of the categories gets a card, a returning holder gets a stamp per
## basket, 3 stamps earn the prize while it lasts; cards bring holders back and end with the campaign.
func test_a_stamp_rally(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	t.ok(cmds.execute({"command_id": "r1", "kind": &"START_PROMOTION", "def_id": "stamps_lunch", "days": 10}).ok, "started")
	var id: String = s.promotions[0]["promotion_id"]
	var card := Promotions.issue_coupon(s, ["rice_ball"])
	t.eq(int(card.get("stamps", 0)), 1, "the first basket gets a card with one stamp")
	t.eq(int(card["expires_day"]), int(s.promotions[0]["end_day"]), "valid while the rally runs")
	for i in 4:
		t.ok(Promotions.issue_coupon(s, ["bento"]).is_empty(), "the next four do not")
	t.ok(not Promotions.issue_coupon(s, ["coffee"]).is_empty(), "the fifth does")
	t.ok(Promotions.issue_coupon(s, ["drink"]).is_empty(), "nothing for other categories")
	t.eq(Promotions.redeem_coupon(s, card["coupon_id"], [{"category": "drink", "price": 150}]), 0, "no stamp without its categories")
	t.eq(int(card["stamps"]), 1, "still one")
	Promotions.redeem_coupon(s, card["coupon_id"], [{"category": "bento", "price": 500}])
	t.eq(int(card["stamps"]), 2, "a stamp")
	t.ok(s.coupons.has(card), "the card stays")
	Promotions.redeem_coupon(s, card["coupon_id"], [{"category": "rice_ball", "price": 150}])
	t.ok(not s.coupons.has(card), "three stamps: the card is done")
	t.eq(int(s.promo_stats[id]["redeemed"]), 1, "and the prize handed out")
	t.eq(int(s.promo_stats[id]["stock"]), 19, "one fewer towel")
	s.coupons.clear()
	Run.run_days(s, cmds, 2)
	var st: Dictionary = s.promo_stats[id]
	t.ok(int(st.get("issued", 0)) > 5, "cards handed out in the store (%d)" % int(st.get("issued", 0)))
	t.ok(int(st.get("stamps", 0)) > int(st.get("issued", 0)), "holders came back for stamps (%d stamps)" % int(st.get("stamps", 0)))
	t.eq(int(st["given"]) + int(st["stock"]), 20, "prizes given + left = bought")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "stamps", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).coupons, s.coupons, "the cards with their stamps survive a save")
	s.day = int(s.promotions[0]["end_day"]) + 1
	Promotions.expire_coupons(s)
	t.eq(s.coupons, [], "cards end with the rally")


## #140: a fair pulls its categories and brings a few more people; more of them are sold.
func test_a_fair(t, _tree) -> void:
	var sold := {}
	for with_fair in [false, true]:
		var s := Run.new_state(300.0)
		var cmds := Run.place_layout(s)
		if with_fair:
			t.ok(cmds.execute({"command_id": "f1", "kind": &"START_PROMOTION", "def_id": "fair_autumn", "days": 2}).ok, "started")
			t.ok(Promotions.category_pull(s, "snack") > 1.2 and Promotions.category_pull(s, "drink") == 1.0, "pulls only its categories")
			t.ok(Promotions.visitor_factor(s) > 1.0, "a few more people come")
		Run.run_days(s, cmds, 2)
		var n := 0
		for tx in s.ledger.transactions:
			if tx["event_type"] == "SALE" and ["snack", "dessert"].has(String(s.products.get_sku(String(tx.get("details", {}).get("sku_id", ""))).get("category", ""))):
				n += 1
		sold[with_fair] = n
	t.ok(int(sold[true]) > int(sold[false]), "more snacks and desserts sold (%d > %d)" % [sold[true], sold[false]])


## #140 phase 2: a collab fair — its limited goods can be ordered only while it runs, they sell to fans on the goods
## shelf, snacks pull more and a few more people come.
func test_a_collab_fair_with_limited_goods(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var r := cmds.execute({"command_id": "g0", "kind": &"ORDER_STOCK", "sku_id": "cgoods_002", "qty": 10})
	t.ok(not r.ok and r.message_key == &"campaign_only_sku", "no limited goods without the fair")
	t.ok(cmds.execute({"command_id": "c1", "kind": &"START_PROMOTION", "def_id": "collab_mascot", "days": 2}).ok, "the fair starts")
	t.ok(Promotions.visitor_factor(s) > 1.0 and Promotions.category_pull(s, "snack") > 1.0, "more people, snacks pull more")
	var shelf := ""
	for y in range(1, s.grid.height - 2):
		for x in range(1, s.grid.width - 1):
			if shelf == "":
				var p := cmds.execute({"command_id": "sg_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "shelf_goods", "x": x, "y": y, "rotation": 0})
				if p.ok:
					shelf = p.data["instance_id"]
	t.ok(cmds.execute({"command_id": "g1", "kind": &"ORDER_STOCK", "sku_id": "cgoods_002", "qty": 10}).ok, "orderable while it runs")
	t.ok(cmds.execute({"command_id": "g2", "kind": &"RESTOCK", "instance_id": shelf, "slot_id": "row0", "sku_id": "cgoods_002", "qty": 10}).ok, "on the goods shelf")
	Run.run_days(s, cmds, 1)
	var sold := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["details"].get("sku_id", "")).begins_with("cgoods_"):
			sold += int(tx["details"].get("qty", 1))
	t.ok(sold > 0, "fans bought the goods (%d)" % sold)
	t.ok(PromotionController.promo_line({"display_name": "x", "kind": "collab", "running": {"days_left": 1, "stats": {}}}).contains("限定グッズ"), "the card says so")

