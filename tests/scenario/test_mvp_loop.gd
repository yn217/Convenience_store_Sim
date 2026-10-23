extends RefCounted
## Issue #25: the whole core loop on the real scene with fixed seeds - empty store -> order -> place ->
## restock -> open -> customers -> sales -> next-day ad -> day close -> daily report -> save -> load ->
## the next day. Cash, stock and the report are checked against each other, not against tuning values.

const DIR := "user://test_saves_scenario"
const DAY := 86400


func _clean() -> void:
	for slot in ["slot_1", "slot_2", "slot_3"]:
		for ext in [".json", ".json.bak", ".json.tmp"]:
			var p := "%s/%s%s" % [DIR, slot, ext]
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)


func _cmd(app: Node, id: String, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	var c := {"command_id": id, "kind": kind}
	c.merge(payload)
	return app.run_command(c)


func _must(t, r: CommandResult, name: String) -> void:
	t.ok(r.ok, "%s: %s %s" % [name, r.code, r.message_key])


func _play(app: Node, until_sec: int) -> void:
	var guard := 0
	while app.state.time_sec < until_sec and guard < 400000:
		app.runner.process_frame(1.0 / 15.0)
		guard += 1


func _ledger_cash(s: GameState) -> int:
	var total := 500000
	for tx in s.ledger.transactions:
		total += int(tx["cash_delta_yen"])
	return total


func _units_on_hand(s: GameState) -> int:
	var n := 0
	for seg in s.inventory_segments:
		n += int(seg["physical_qty"])
	return n


func test_empty_store_to_second_day_with_save_and_load(t, tree) -> void:
	_clean()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	app.save_dir = DIR
	var s: GameState = app.state
	t.eq(s.cash_yen, 500000)
	t.eq(s.business_state, GameState.SETUP)
	t.eq(s.grid.instances.size(), 0)

	# S-01 / S-15: a shelf can be built without a register, but the shop cannot open; a missing register is told
	_must(t, _cmd(app, "k1", &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}), "k1")
	t.eq(_cmd(app, "k2", &"START_BUSINESS").code, &"MISSING_REGISTER")
	_must(t, _cmd(app, "k3", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0}), "k3")
	_must(t, _cmd(app, "k4", &"PLACE_FIXTURE", {"type_id": "fridge_drink", "x": 4, "y": 8, "rotation": 0}), "k4")
	var shelf := "fx_0001"
	var fridge := "fx_0003"
	t.eq(s.grid.instances[shelf]["type_id"], "shelf_onigiri")
	t.eq(s.grid.instances[fridge]["type_id"], "fridge_drink")

	# order -> backroom -> shelf (cash only moves on the order)
	var before_order := s.cash_yen
	_must(t, _cmd(app, "k5", &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 24}), "k5")
	_must(t, _cmd(app, "k6", &"ORDER_STOCK", {"sku_id": "drink_001", "qty": 12}), "k6")
	var ordered := before_order - s.cash_yen
	t.eq(ordered, 24 * int(s.products.get_sku("rice_001")["purchase_cost_yen"]) + 12 * int(s.products.get_sku("drink_001")["purchase_cost_yen"]))
	var cash_after_orders := s.cash_yen
	_must(t, _cmd(app, "k7", &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 12}), "k7")
	_must(t, _cmd(app, "k8", &"RESTOCK", {"instance_id": shelf, "slot_id": "row1", "sku_id": "rice_001", "qty": 12}), "k8")
	_must(t, _cmd(app, "k9", &"RESTOCK", {"instance_id": fridge, "slot_id": "row0", "sku_id": "drink_001", "qty": 12}), "k9")
	t.eq(s.cash_yen, cash_after_orders, "moving stock to a shelf costs nothing")
	t.eq(_units_on_hand(s), 36)
	_must(t, _cmd(app, "k10", &"SET_PRICE", {"sku_id": "rice_001", "price_yen": 160}), "k10")
	_must(t, _cmd(app, "k11", &"SET_NEXT_DAY_AD", {"tier_yen": 1000}), "k11")

	# open and trade the whole day 0
	_must(t, _cmd(app, "k12", &"START_BUSINESS"), "k12")
	t.eq(s.business_state, GameState.OPEN)
	s.balance["base_potential_visitors_per_day"] = 600
	s.speed_setting = 4
	_play(app, 23 * 3600)
	var sold_morning: int = s.visit_stats["purchased"]
	t.ok(sold_morning > 0, "customers bought something: %d, time %d" % [sold_morning, s.time_sec])

	# S-09: the ad chosen for tomorrow is charged once at the day boundary, today's ad stays as it was
	t.eq(s.applied_ad_tier_yen, 1000, "today runs with the tier that was set before opening")
	var k13 := _cmd(app, "k13", &"SET_NEXT_DAY_AD", {"tier_yen": 2000})
	t.ok(k13.ok, "k13: %s %s" % [k13.code, k13.message_key])
	t.eq(s.applied_ad_tier_yen, 1000, "changing tomorrow's ad does not touch today's")
	_play(app, DAY + 600)   # through midnight
	t.eq(s.day, 1)
	t.eq(s.daily_reports.size(), 1, "day 0 closed exactly once")
	var report: Dictionary = s.daily_reports[0]
	t.eq(report["day_index"], 0)
	var ad_rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "AD")
	t.eq(ad_rows.size(), 2, "one charge per day: day 0 at opening, day 1 at midnight")
	t.eq(int(ad_rows[0]["expense_delta_yen"]), 1000, "today's ad stays 1000")
	t.eq(int(ad_rows[1]["expense_delta_yen"]), 2000, "tomorrow's tier, charged once")
	t.eq(report["advertising_yen"], 1000, "the closed day keeps its own ad cost")
	t.eq(s.applied_ad_tier_yen, 2000)

	# S-05 / S-08: the report, the ledger and the cash agree; units gone = units sold
	var sum := LedgerSummary.summarize(s.ledger)
	t.eq(s.cash_yen, _ledger_cash(s), "every yen of cash is a ledger row")
	t.eq(report["revenue_yen"], sum["revenue_yen"], "all revenue so far belongs to day 0")
	var sold_total := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE":
			sold_total += int(tx["details"]["qty"])
	t.eq(_units_on_hand(s), 36 - sold_total, "no unit appears or disappears except by a sale")
	t.eq(report["purchasing_customers"], sold_total, "one unit per visit")
	t.eq(report["revenue_yen"] - report["cogs_yen"], report["gross_profit_yen"])
	t.ok(report["visitors"] >= report["purchasing_customers"])
	var rep_revenue := 0
	var rep_cogs := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and int(tx["day_index"]) == 0:
			rep_revenue += int(tx["revenue_delta_yen"])
			rep_cogs += int(tx["cogs_delta_yen"])
	t.eq(report["revenue_yen"], rep_revenue)
	t.eq(report["cogs_yen"], rep_cogs)

	# S-11: save -> keep playing -> load -> play the same stretch again: identical outcome
	app.run_command({"command_id": "k14", "kind": &"SET_SPEED", "speed": 0})
	var saved_time: int = s.time_sec
	var saved: CommandResult = app.run_command({"command_id": "k15", "kind": &"SAVE_GAME", "slot_id": "slot_1"})
	t.ok(saved.ok, "save: %s %s" % [saved.code, saved.message_key])
	s.speed_setting = 4
	_play(app, DAY + 6 * 3600)
	var end_a := {"cash": s.cash_yen, "tx": s.ledger.transactions.size(), "rng": s.rng_states.duplicate(), "visit": s.visit_stats.duplicate(), "units": _units_on_hand(s), "time": s.time_sec}
	var loaded: CommandResult = app.run_command({"command_id": "k16", "kind": &"LOAD_GAME", "slot_id": "slot_1"})
	t.ok(loaded.ok, "load: %s %s" % [loaded.code, loaded.message_key])
	s = app.state
	s.balance["base_potential_visitors_per_day"] = 600   # tuning set by this scenario, not part of a save
	t.eq(s.time_sec, saved_time, "back at the saved moment")
	s.speed_setting = 4
	_play(app, DAY + 6 * 3600)
	t.eq(s.cash_yen, end_a["cash"], "same cash after load + replay")
	t.eq(s.ledger.transactions.size(), end_a["tx"])
	t.eq(s.rng_states, end_a["rng"])
	t.eq(s.visit_stats, end_a["visit"])
	t.eq(_units_on_hand(s), end_a["units"])
	t.eq(s.cash_yen, _ledger_cash(s), "the loaded game still reconciles")
	t.eq(s.daily_reports.size(), 1, "the report was not duplicated by the load")

	# the day-1 event draw happened once and survived the load
	t.eq(s.gameplay_event_state["last_selected_day"], 1)
	main.queue_free()
	await tree.process_frame
	_clean()
