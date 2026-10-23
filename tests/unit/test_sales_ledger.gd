extends RefCounted
## Issue #17: sale transaction, ledger reconciliation and failure injection (10 §D, §H; 03 §E, §G).

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "l%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _snapshot_economy(s: GameState) -> Dictionary:
	return {"cash": s.cash_yen, "tx": s.ledger.transactions.duplicate(true), "segs": s.inventory_segments.duplicate(true),
		"res": s.reservations.duplicate(true), "events": s.ledger.applied_event_ids.duplicate()}


func test_green_tea_golden_sequence(t, _tree) -> void:
	# 10 §D: cost 75 x 10 -> cash 499250; 6 to the shelf; price 150; reserve 1; checkout.
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "fridge_drink", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	var capex: int = s.fixtures.get_type("fridge_drink")["placement_cost_yen"]
	var base_cash := 500000 - capex
	t.eq(s.cash_yen, base_cash)
	_run(cmds, &"ORDER_STOCK", {"sku_id": "drink_001", "qty": 10})
	t.eq(s.cash_yen, base_cash - 750, "cash 500000-750 style: -75 x 10")
	t.eq(s.snapshot()["backroom_stock"], {"drink_001": 10})
	var sum := LedgerSummary.summarize(s.ledger)
	t.eq(sum["revenue_yen"], 0)
	t.eq(sum["cogs_yen"], 0, "orders are not COGS")
	t.eq(sum["order_yen"], 750)
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "drink_001", "qty": 6})
	t.eq(s.snapshot()["backroom_stock"], {"drink_001": 4}, "backroom 4")
	t.eq(s.snapshot()["shelf_stock"][shelf]["row0"], 6, "shelf 6")
	t.eq(s.cash_yen, base_cash - 750, "restock moves no cash")
	t.ok(_run(cmds, &"SET_PRICE", {"sku_id": "drink_001", "price_yen": 150}).ok)
	var res := InventoryService.reserve(s, "r1", "c1", "drink_001", 600)
	t.eq(res["sell_unit_yen_snapshot"], 150, "the new price applies to a new reservation")
	var phys := 0
	var resv := 0
	for seg in s.inventory_segments:
		if seg["location"]["kind"] == "FIXTURE":
			phys += seg["physical_qty"]
			resv += seg["reserved_qty"]
	t.eq([phys, resv], [6, 1], "physical 6 / reserved 1 / available 5")
	t.ok(InventoryService.complete_sale(s, "tx1", "r1")["ok"])
	sum = LedgerSummary.summarize(s.ledger)
	t.eq(s.cash_yen, base_cash - 750 + 150, "cash +150")
	t.eq(sum["revenue_yen"], 150)
	t.eq(sum["cogs_yen"], 75)
	t.eq(sum["gross_profit_yen"], 75)
	phys = 0
	resv = 0
	for seg in s.inventory_segments:
		if seg["location"]["kind"] == "FIXTURE":
			phys += seg["physical_qty"]
			resv += seg["reserved_qty"]
	t.eq([phys, resv], [5, 0], "physical 5 / reserved 0")
	var before := _snapshot_economy(s)
	t.eq(InventoryService.complete_sale(s, "tx1", "r1")["reason"], "duplicate_transaction")
	t.eq(_snapshot_economy(s), before, "re-sending the same transaction changes nothing")


func test_cost_100_sell_150_five_units_reconciles(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	var start := s.cash_yen
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 10})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 5})
	for i in 5:
		t.ok(not InventoryService.reserve(s, "r%d" % i, "c%d" % i, "rice_001", 600).is_empty())
		t.ok(InventoryService.complete_sale(s, "tx%d" % i, "r%d" % i)["ok"])
	var sum := LedgerSummary.summarize(s.ledger)
	t.eq(sum["revenue_yen"], 750, "sum of price x qty")
	t.eq(sum["cogs_yen"], 500)
	t.eq(sum["gross_profit_yen"], 250, "revenue - cogs")
	t.eq(sum["sale_count"], 5)
	t.eq(sum["order_yen"], 1000)
	t.eq(s.cash_yen, start - 1000 + 750, "cash = start - orders + revenue (no double deduction)")
	t.eq(s.cash_yen, start - sum["order_yen"] + sum["revenue_yen"])
	t.eq(sum["operating_profit_yen"], 250, "orders are not deducted a second time")


func test_price_change_does_not_rewrite_confirmed_sales(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 4})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 4})
	InventoryService.reserve(s, "r1", "c1", "rice_001", 600)
	InventoryService.reserve(s, "r2", "c2", "rice_001", 600)
	InventoryService.complete_sale(s, "tx1", "r1")
	_run(cmds, &"SET_PRICE", {"sku_id": "rice_001", "price_yen": 400})
	InventoryService.complete_sale(s, "tx2", "r2")   # reserved at 150 -> pays 150
	InventoryService.reserve(s, "r3", "c3", "rice_001", 600)
	InventoryService.complete_sale(s, "tx3", "r3")   # reserved at 400
	var revenues: Array[int] = []
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE":
			revenues.append(tx["revenue_delta_yen"])
	t.eq(revenues, [150, 150, 400] as Array[int])


func test_failed_checkout_changes_nothing(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 3})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 3})
	InventoryService.reserve(s, "r1", "c1", "rice_001", 600)
	var before := _snapshot_economy(s)
	t.eq(InventoryService.complete_sale(s, "tx", "ghost")["reason"], "unknown_reservation")
	t.eq(_snapshot_economy(s), before, "unknown reservation")
	# Injected fault: the reservation says 2 but the segment only reserved 1.
	s.reservations[0]["qty"] = 2
	before = _snapshot_economy(s)
	t.eq(InventoryService.complete_sale(s, "tx", "r1")["reason"], "insufficient_stock")
	t.eq(_snapshot_economy(s), before, "inconsistent reservation is refused whole")
	s.reservations[0]["qty"] = 1
	# Injected fault: the sale event id was already used (ledger refuses it).
	s.ledger.applied_event_ids["tx"] = true
	before = _snapshot_economy(s)
	var out := InventoryService.complete_sale(s, "tx", "r1")
	t.ok(not out["ok"])
	t.eq(_snapshot_economy(s), before, "ledger rejection leaves stock and reservation alone")
	s.time_sec = 86400
	before = _snapshot_economy(s)
	t.ok(not InventoryService.complete_sale(s, "tx_new", "r1")["ok"], "expired stock")
	t.eq(_snapshot_economy(s), before)


func test_fixture_purchase_and_undo_are_capex_not_operating(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	var sum := LedgerSummary.summarize(s.ledger)
	t.eq(sum["capex_yen"], 45000)
	t.eq(sum["operating_profit_yen"], 0, "capex does not enter operating profit")
	_run(cmds, &"UNDO_LAYOUT", {})
	sum = LedgerSummary.summarize(s.ledger)
	t.eq(sum["capex_yen"], 0, "the reversal cancels the purchase")
	t.eq(s.cash_yen, 500000)


func test_end_to_end_day_reconciles_cash(t, _tree) -> void:
	# A morning of simulated customers: every cash movement is explained by the ledger summary.
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 12})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 12})
	s.business_state = GameState.OPEN
	s.speed_setting = 4
	s.time_sec = 11 * 3600
	s.balance["base_potential_visitors_per_day"] = 2000   # busy enough to see several sales
	var initial := 500000
	var runner := SimulationRunner.new(s)
	var steps := 0
	while steps < 3600:
		steps += runner.process_frame(1.0 / 15.0)
	var sum := LedgerSummary.summarize(s.ledger)
	t.ok(sum["sale_count"] > 0, "customers bought something")
	t.eq(s.visit_stats["purchased"], sum["sale_count"], "every purchase has one sale row")
	t.eq(s.cash_yen, initial - sum["capex_yen"] - sum["order_yen"] + sum["revenue_yen"], "cash fully explained")
	t.eq(sum["revenue_yen"], sum["sale_count"] * 150)
	t.eq(sum["cogs_yen"], sum["sale_count"] * 100)
	var left := 0
	for seg in s.inventory_segments:
		left += seg["physical_qty"]
	t.eq(left, 12 - sum["sale_count"], "units sold = units gone")
