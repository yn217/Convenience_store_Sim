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
