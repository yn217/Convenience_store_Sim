extends RefCounted
## Issue #129 phase 1: rival stores — when and where they open, what they take (peak, settling, sales, distance,
## cap), fewer visitors in a running store, switching them off and the save.

const Run := preload("res://tests/support/basket_run.gd")
const MAP := "aoba_city_central_district_v2"


func _store() -> GameState:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "site", "kind": &"SET_SITE", "map_id": MAP, "plot_id": "P01"})
	return s


func test_rivals_open_on_the_map_after_the_first_days(t, _tree) -> void:
	var s := _store()
	var days: Array = []
	for d in range(0, 25):
		s.day = d
		var before := s.rivals.size()
		Market.on_new_day(s)
		if s.rivals.size() > before:
			days.append(d)
	t.eq(days, [4, 10, 16], "from day 4, every 6 days, at most 3")
	var sites: Array = s.rivals.map(func(r): return r["plot_id"])
	t.ok(not sites.has("P01"), "never on the store's own site")
	t.eq(sites.size(), 3, "three different sites: %s" % str(sites))
	var me := WorldMap.plot(MAP, "P01")
	var dist := func(id: String) -> float:
		var p := WorldMap.plot(MAP, id)
		return Vector2(float(p["x"]) - float(me["x"]), float(p["y"]) - float(me["y"])).length()
	t.ok(dist.call(sites[0]) <= dist.call(sites[1]) and dist.call(sites[1]) <= dist.call(sites[2]), "nearest free site first")
	t.ok(Company.used_sites(s).has("%s|%s" % [MAP, sites[0]]), "a rival's site cannot be taken")
	var hand := Run.new_state(300.0)   # a store placed by hand has no site: no rivals come
	for d in range(0, 12):
		hand.day = d
		Market.on_new_day(hand)
	t.eq(hand.rivals, [], "no site, no rivals")


func test_what_a_rival_takes(t, _tree) -> void:
	var s := _store()
	var r := {"rival_id": "rival_01", "name": "x", "map_id": MAP, "plot_id": "P02", "x": float(WorldMap.plot(MAP, "P01")["x"]), "y": float(WorldMap.plot(MAP, "P01")["y"]), "opened_day": 4}
	t.eq(Market.rival_share(s, r, 3), 0.0, "nothing before it opens")
	t.ok(absf(Market.rival_share(s, r, 4) - 0.2) < 0.0001, "next door on its first day: 20%")
	t.ok(Market.rival_share(s, r, 7) < Market.rival_share(s, r, 5), "settling down day by day")
	var settled := Market.rival_share(s, r, 13)
	t.ok(settled > 0.1 and settled < 0.12, "settles near 10%% (%.3f)" % settled)
	t.ok(Market.rival_share(s, r, 9) > Market.rival_share(s, r, 8) - 0.0001 + 0.05, "a sale day takes more")
	var far := r.duplicate()
	far["x"] = float(WorldMap.plot(MAP, "P01")["x"]) + 1600.0
	t.eq(Market.rival_share(s, far, 6), 0.0, "far away: nothing")
	var many: Array = []
	for i in 4:
		many.append(r)
	t.ok(absf(Market.visitor_factor(s, many, 4) - 0.7) < 0.0001, "all together at most 30%")
	t.eq(Market.visitor_factor(s, [], 4), 1.0, "no rivals: exactly 1")


## In a running store a rival next door means fewer visitors; switched off, none open; the rivals survive a save.
func test_a_rival_in_a_running_store(t, _tree) -> void:
	var seen := {}
	for with_rival in [false, true]:
		var s := _store()
		if with_rival:
			var p := WorldMap.plot(MAP, "P02")
			s.rivals.append({"rival_id": "rival_01", "name": "テスト店", "map_id": MAP, "plot_id": "P02", "x": float(p["x"]), "y": float(p["y"]), "opened_day": 0})
		var cmds := GameCommands.new(s)
		Run.run_days(s, cmds, 1)
		seen[with_rival] = int(s.daily_reports[0]["potential_customers"])
		if with_rival:
			var saved := SaveGame.to_dict(s, "rv", "2026-10-27T00:00:00Z")
			var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
			t.ok(lr["ok"], str(lr["errors"]))
			t.eq((lr["state"] as GameState).rivals, s.rivals, "rivals survive a save")
			t.ok(BusinessController.rivals_text(s.snapshot()["rivals"], float(s.snapshot()["rival_factor"])).contains("テスト店"), "named on the 経営 tab")
	t.ok(int(seen[true]) < int(seen[false]), "fewer people come with a rival next door (%d < %d)" % [seen[true], seen[false]])
	var off := _store()
	t.ok(GameCommands.new(off).execute({"command_id": "off", "kind": &"SET_RIVALS", "enabled": false}).ok, "switched off")
	for d in range(0, 12):
		off.day = d
		Market.on_new_day(off)
	t.eq(off.rivals, [], "no rivals when switched off")


## The news: an opening and a sale are events with a notice text (a toast, also when the sound is off).
func test_rival_news(t, _tree) -> void:
	var s := _store()
	for d in range(0, 10):
		s.day = d
		Market.on_new_day(s)
	var types: Array = s.take_events().map(func(e): return e["type"])
	t.ok(types.has("RIVAL_OPENED") and types.has("RIVAL_SALE"), "opening and sale announced: %s" % str(types))
	t.ok(CueText.toast_text("rival_opened", {"name": "ハッピーマート 駅前店"}).contains("ハッピーマート 駅前店"), "the toast names the rival")
	t.eq(CueText.level_of("rival_opened", "important"), "warning")


## Phase 3: a rival renovates once (shut, then the opening pull again) and closes for good when the first store
## keeps a high reputation; its site is free again; both are news and survive a save.
func test_rival_renovates_and_closes(t, _tree) -> void:
	var s := _store()
	s.reputation = 50
	for d in range(0, 26):
		s.day = d
		Market.on_new_day(s)
	var r: Dictionary = s.rivals[0]
	t.eq(int(r.get("renovate_day", -1)), 18, "renovates 14 days after it opened on day 4")
	t.eq(Market.status(r, 19), "renovating", "shut while renovating")
	t.eq(Market.rival_share(s, r, 19), 0.0, "takes nothing while shut")
	t.ok(Market.rival_share(s, r, 21) > Market.rival_share(s, r, 17) * 1.5, "reopens with the opening pull again")
	t.ok(not r.has("closed_day"), "a store with an ordinary reputation does not drive it out")
	var types: Array = s.take_events().map(func(e): return e["type"])
	t.ok(types.has("RIVAL_RENOVATION"), "the renovation is news")
	s.reputation = 70
	s.day = 26
	Market.on_new_day(s)
	t.eq(int(r.get("closed_day", -1)), 26, "a well-liked store drives it out after 21 days")
	t.eq(Market.rival_share(s, r, 27), 0.0, "a closed rival takes nothing")
	t.ok(not Company.used_sites(s).has("%s|%s" % [MAP, r["plot_id"]]), "its site is free again")
	t.ok(s.take_events().any(func(e): return e["type"] == "RIVAL_CLOSED"), "the closing is news")
	t.ok(BusinessController.rivals_text(Market.views(s, s.rivals, 27), 1.0).contains("閉店"), "shown as closed on the 経営 tab")
	t.ok(CueText.toast_text("rival_closed", {"name": "x店"}).contains("閉店"), "and as a toast")
	var saved := SaveGame.to_dict(s, "rv3", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).rivals, s.rivals, "renovation and closing survive a save")


## Phase 2: local conditions — from day 6 every 7 days the next one starts, lasts its days (the new apartment
## block stays), changes visitors and pulls categories, within the floor and ceiling; news; saved.
func test_local_conditions(t, _tree) -> void:
	var s := _store()
	s.rivals_enabled = true
	var started: Array = []
	for d in range(0, 40):
		s.day = d
		var before := s.market_conditions.size()
		Market.on_new_day(s)
		if s.market_conditions.size() > before:
			started.append([d, s.market_conditions.back()["condition_id"]])
	t.eq(started.map(func(x): return x[0]), [6, 13, 20, 27, 34], "from day 6, every 7 days")
	t.eq(started[0][1], "road_works", "in the order of the list")
	s.rivals.clear()
	t.ok(absf(Market.condition_factor(s.market_conditions, 7) - 0.85) < 0.0001, "road works: fewer visitors on day 7")
	t.eq(Market.condition_factor(s.market_conditions, 10), 1.0, "over after its 4 days")
	t.ok(absf(Market.condition_category(s.market_conditions, 14, "snack") - 1.3) < 0.0001, "the school festival pulls snacks")
	t.ok(Market.condition_factor(s.market_conditions, 39) > 1.07, "the new apartment block stays")
	t.ok(absf(Market.visitor_factor(s, [], 7) - 0.85) < 0.0001, "applied to the store's visitors")
	t.ok(BusinessController.conditions_text(s.snapshot()["conditions"]).contains("マンション"), "named on the 経営 tab")
	t.ok(CueText.toast_text("condition_started", {"name_ja": "地域のお祭り", "note": "x"}).contains("地域のお祭り"), "and as news")
	var saved := SaveGame.to_dict(s, "cond", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).market_conditions, s.market_conditions, "conditions survive a save")
	var hand := Run.new_state(100.0)
	for d in range(0, 20):
		hand.day = d
		Market.on_new_day(hand)
	t.eq(hand.market_conditions, [], "a store without a map site keeps its old behaviour")


## More conditions: a supply squeeze raises the order price of its categories (and the cost of what is sold) while it
## lasts; a rival's new sweets pull desserts down. Both come after the first five, in the list's order.
func test_supply_squeeze_and_a_rivals_new_product(t, _tree) -> void:
	var s := _store()
	s.market_conditions = [{"condition_id": "supply_squeeze", "start_day": 0, "end_day": 4}, {"condition_id": "rival_new_product", "start_day": 0, "end_day": 4}]
	var cmds := GameCommands.new(s)
	var cash := s.ledger.cash_yen
	var unit := int(s.products.get_sku("rice_001")["purchase_cost_yen"])
	t.ok(cmds.execute({"command_id": "o1", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 10}).ok, "ordered")
	t.eq(cash - s.ledger.cash_yen, 10 * int(round(unit * 1.2)), "rice costs 20% more")
	t.eq(int(s.inventory_segments.back()["unit_cost_yen"]), int(round(unit * 1.2)), "and its cost of sales follows")
	cash = s.ledger.cash_yen
	cmds.execute({"command_id": "o2", "kind": &"ORDER_STOCK", "sku_id": "snack_001", "qty": 10})
	t.eq(cash - s.ledger.cash_yen, 10 * int(s.products.get_sku("snack_001")["purchase_cost_yen"]), "other goods as before")
	t.ok(Market.condition_category(s.market_conditions, 1, "dessert") < 1.0, "desserts sell less against the rival's new sweets")
	s.day = 5
	cash = s.ledger.cash_yen
	cmds.execute({"command_id": "o3", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 10})
	t.eq(cash - s.ledger.cash_yen, 10 * unit, "back to the usual price once it is over")
	var ids: Array = Market.conditions_data()["conditions"].map(func(c): return c["condition_id"])
	t.eq(ids.slice(0, 5), ["road_works", "school_festival", "new_apartment", "sports_tournament", "festival"], "the first five keep their order")
