extends RefCounted
## Issue #146: several stores of one company — one shared ledger with a scope per store.

const Run := preload("res://tests/support/basket_run.gd")


## Two stores booking the same ids on one shared ledger: every row lands, each store sees only its own rows,
## and the company's cash is one purse.
func test_stores_share_one_ledger(t, _tree) -> void:
	var a := Run.new_state(100.0)
	var b := Run.new_state(100.0)
	b.ledger = a.ledger
	b.set_store_id("s2")
	var cash := a.cash_yen
	for st in [a, b]:
		st.set_store_id(st.store_id)   # the booking store sets the shared ledger's scope
		t.ok(st.ledger.record("DAILY_FIXED", "0:DAILY_FIXED", -1000, 0, 0, {}, {"expense": 1000}), "a day's fixed cost for %s" % (st.store_id if st.store_id != "" else "store 1"))
		t.ok(st.ledger.record("SALE", "sale:res_cust_00001_0", 150, 0, 10, {"sku_id": "rice_001", "qty": 1}, {"revenue": 150, "cogs": 100}), "the same sale id in both stores")
	a.ledger.scope = ""
	t.eq(a.ledger.transactions.size(), 4, "every row landed")
	t.eq(a.cash_yen, cash - 2000 + 300, "one purse for the company")
	t.ok(a.ledger.has_event("0:DAILY_FIXED"), "store 1 charged")
	a.ledger.scope = "s2/"
	t.ok(a.ledger.has_event("0:DAILY_FIXED"), "store 2 charged on its own id")
	a.ledger.scope = ""
	var first := LedgerSummary.summarize(a.ledger, 0)
	t.eq([first["revenue_yen"], first["fixed_cost_yen"]], [150, 1000], "store 1 sees its own rows only")
	a.ledger.scope = "s2/"
	var second := LedgerSummary.summarize(a.ledger, 0)
	t.eq([second["revenue_yen"], second["fixed_cost_yen"]], [150, 1000], "and so does store 2")
	t.eq(SaveGame.semantic_errors(b), [] as Array[String], "two stores' daily charges are not 'charged twice'")
	t.eq(Ledger.store_of("s2/0:DAILY_FIXED"), "s2")
	t.eq(Ledger.store_of("0:DAILY_FIXED"), "", "the first store's ids are unchanged")
	b.next_staff_seq = 0
	t.eq(StaffAI.make(b, {"name": "x", "skills": {}}, Vector2i.ZERO)["staff_id"], "s2_staff_001", "staff ids are company-unique")
	var saved := SaveGame.to_dict(b, "ms", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), b.balance.duplicate(true), b.fixtures, b.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq([(lr["state"] as GameState).store_id, (lr["state"] as GameState).ledger.scope], ["s2", "s2/"], "the store id survives a save")


func _company() -> GameState:
	var a := Run.new_state(300.0, {"staff_enabled": true})   # staff run the tills (off screen too)
	a.ledger.cash_yen = 50000000
	return a


func test_opening_a_store(t, _tree) -> void:
	var a := _company()
	var cmds := GameCommands.new(a)
	var cash := a.cash_yen
	var r := cmds.execute({"command_id": "o1", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P05", "size_id": "small"})
	t.ok(r.ok, "opened: %s" % r.message_key)
	t.eq(a.cash_yen, cash - 3000000, "a small store costs 3,000,000 yen from the company's purse")
	var b := Company.find(a, "s2")
	t.ok(b != null and b.ledger == a.ledger, "the second store shares the purse")
	t.eq([b.location_id, b.plot_id, b.business_state], ["school", "P05", GameState.SETUP], "on its site, closed")
	t.eq(Vector2i(b.grid.width, b.grid.height), Vector2i(12, 10), "small")
	t.eq(b.grid.instances.size(), 0, "empty: fixtures are bought separately")
	t.ok(b.staff.size() > 0 and String(b.staff[0]["staff_id"]).begins_with("s2_"), "with its own staff")
	r = cmds.execute({"command_id": "o2", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P05", "size_id": "large"})
	t.ok(not r.ok and r.message_key == &"site_taken", "one store per site")
	t.ok(cmds.execute({"command_id": "o3", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P07", "size_id": "large"}).ok, "a large one elsewhere")
	t.eq(a.cash_yen, cash - 3000000 - 8000000, "8,000,000 yen")
	t.eq(Company.views(a).size(), 3, "three stores in the list")


## Two open stores: the one off screen sells from its own shelves every hour on its own ledger scope, pays its
## own day, and nothing without a cashier; switching keeps each store's stock and staff; a save replays.
func test_a_store_off_screen_keeps_trading(t, _tree) -> void:
	var a := _company()
	var cmds_a := Run.place_layout(a)
	GameCommands.new(a).execute({"command_id": "o1", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P01", "size_id": "medium"})
	var b := Company.switch_to(a, "s2")
	t.ok(b != null and b.branches.has(a), "store 2 on screen, store 1 off screen")
	var cmds_b := Run.place_layout(b)
	Run.restock(b, cmds_b, 0)
	t.ok(cmds_b.execute({"command_id": "openb", "kind": &"START_BUSINESS"}).ok, "store 2 opens")
	var b_stock := b.inventory_segments.size()
	a = Company.switch_to(b, "")
	t.eq(b.inventory_segments.size(), b_stock, "switching keeps store 2's stock")
	Run.restock(a, cmds_a, 0)
	cmds_a.execute({"command_id": "opena", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(a)
	while a.day == 0:
		runner._run_step()
	for i in 1800:
		runner._run_step()
	var b_sales := a.ledger.transactions.filter(func(tx): return tx["event_type"] == "SALE" and Ledger.store_of(tx["event_id"]) == "s2")
	var a_sales := a.ledger.transactions.filter(func(tx): return tx["event_type"] == "SALE" and Ledger.store_of(tx["event_id"]) == "")
	t.ok(b_sales.size() > 20 and a_sales.size() > 20, "both stores sell (on screen %d, off screen %d)" % [a_sales.size(), b_sales.size()])
	t.eq(b.daily_reports.size(), 1, "store 2 closed its day")
	t.ok(int(b.daily_reports[0]["revenue_yen"]) > 0 and int(b.daily_reports[0]["revenue_yen"]) < int(a.daily_reports[0]["revenue_yen"]) + 100000, "with its own figures")
	t.eq(a.ledger.transactions.filter(func(tx): return String(tx["event_id"]) == "s2/1:DAILY_FIXED").size(), 1, "store 2 paid its new day once")
	t.eq(b.reservations.filter(func(r): return r["customer_id"] == "").size(), 0, "nothing left reserved off screen")
	for seg in b.inventory_segments:
		t.ok(int(seg["physical_qty"]) >= 0 and int(seg["reserved_qty"]) == 0, "stock stays sane")
	var saved := SaveGame.to_dict(a, "two", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), a.balance.duplicate(true), a.fixtures, a.products)
	t.ok(lr["ok"], str(lr["errors"]))
	if not lr["ok"]:
		return
	var c: GameState = lr["state"]
	t.eq(c.branches.size(), 1, "the second store comes back")
	t.ok(c.branches[0].ledger == c.ledger, "on the shared purse")
	var rc := SimulationRunner.new(c)
	for i in 3600:
		runner._run_step()
		rc._run_step()
	t.eq(Run.fingerprint(c), Run.fingerprint(a), "loaded and uninterrupted runs agree")
	t.eq(c.branches[0].inventory_segments.map(func(s): return s["physical_qty"]), a.branches[0].inventory_segments.map(func(s): return s["physical_qty"]), "store 2 too")
	# No cashier, no sales.
	for st in a.branches[0].staff.duplicate():
		a.branches[0].staff.erase(st)
	var before := a.ledger.transactions.filter(func(tx): return Ledger.store_of(tx["event_id"]) == "s2" and tx["event_type"] == "SALE").size()
	for i in 3600:
		runner._run_step()
	var after := a.ledger.transactions.filter(func(tx): return Ledger.store_of(tx["event_id"]) == "s2" and tx["event_type"] == "SALE").size()
	t.eq(after, before, "without staff the store off screen sells nothing")


func test_staff_transfer(t, _tree) -> void:
	var a := _company()
	var cmds := GameCommands.new(a)
	cmds.execute({"command_id": "o1", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P02", "size_id": "small"})
	var who: String = a.staff[0]["staff_id"]
	var n_a := a.staff.size()
	Company.find(a, "s2").staff.pop_back()   # a place free under its cap (2 without a staff room)
	t.ok(cmds.execute({"command_id": "t1", "kind": &"TRANSFER_STAFF", "staff_id": who, "to_store_id": "s2"}).ok, "moved while both are closed")
	t.eq(a.staff.size(), n_a - 1, "left store 1")
	t.ok(Company.find(a, "s2").staff.any(func(x): return x["staff_id"] == who), "joined store 2 with the same id")
	var b := Company.find(a, "s2")
	while b.staff.size() < StaffAI.capacity(b):
		b.staff.append(StaffAI.make(b, {"name": "x", "skills": {}}, Vector2i.ZERO))
	var r := cmds.execute({"command_id": "t2", "kind": &"TRANSFER_STAFF", "staff_id": a.staff[0]["staff_id"], "to_store_id": "s2"})
	t.ok(not r.ok and r.message_key == &"staff_cap_reached", "within the receiving store's cap")
	a.business_state = GameState.OPEN
	r = cmds.execute({"command_id": "t3", "kind": &"TRANSFER_STAFF", "staff_id": who, "to_store_id": ""})
	t.ok(not r.ok and r.message_key == &"stores_must_be_closed", "only while both stores are closed")


## The company's figures add up every store's day; one store has none.
func test_company_totals(t, _tree) -> void:
	var a := _company()
	t.eq(Company.totals(a, 0), {}, "one store: no company line")
	GameCommands.new(a).execute({"command_id": "o1", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P02", "size_id": "small"})
	var b := Company.find(a, "s2")
	a.set_store_id("")
	a.ledger.record("SALE", "x1", 300, 0, 10, {"qty": 2}, {"revenue": 300, "cogs": 200})
	b.set_store_id("s2")
	b.ledger.record("SALE", "x1", 500, 0, 20, {"qty": 3}, {"revenue": 500, "cogs": 300})
	a.set_store_id("")
	var tot := Company.totals(a, 0)
	t.eq([tot["stores"], tot["revenue_yen"], tot["gross_profit_yen"], tot["units_sold"]], [2, 800, 300, 5], "both stores added up")
	t.eq(LedgerSummary.summarize(a.ledger, 0)["revenue_yen"], 300, "the store's own report stays its own")
	t.ok(ReportController.company_text(tot).contains("全店合計（2店"), ReportController.company_text(tot))
