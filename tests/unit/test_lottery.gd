extends RefCounted
## Issue #138 phase 1: prize draws at the till — a set bought whole, every ticket wins a prize drawn without
## replacement from an order fixed when the set is bought, the last ticket's extra prize, takings and costs in the
## ledger, unsold tickets written off, the save, and customers buying tickets at the till.

const Run := preload("res://tests/support/basket_run.gd")


func test_sets_are_well_formed(t, _tree) -> void:
	for d in Lottery.data()["sets"]:
		var n := Lottery.total_tickets(d)
		t.ok(n >= 20, d["set_id"] + ": tickets")
		t.ok(int(d["ticket_price_yen"]) * n > int(d["set_cost_yen"]), d["set_id"] + ": selling out pays for the set")
		t.ok(String(d["last_one"]) != "", d["set_id"] + ": an extra prize for the last ticket")


func test_every_ticket_wins_and_the_last_one_gets_more(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var cash := s.ledger.cash_yen
	t.ok(cmds.execute({"command_id": "k1", "kind": &"START_LOTTERY", "set_id": "kuji_animals"}).ok, "set bought")
	t.eq(cash - s.ledger.cash_yen, 24000, "the set is paid for whole")
	t.ok(not cmds.execute({"command_id": "k2", "kind": &"START_LOTTERY", "set_id": "kuji_robots"}).ok, "one set at a time")
	var lot: Dictionary = s.lotteries[0]
	var other := Run.new_state(100.0)
	Run.place_layout(other).execute({"command_id": "k1", "kind": &"START_LOTTERY", "set_id": "kuji_animals"})
	t.eq(other.lotteries[0]["order"], lot["order"], "the same purchase draws the same order")
	var tiers := {}
	var prizes := 0
	var last := {}
	while true:
		var p := Lottery.sell_ticket(s, lot, "cust")
		if p.is_empty():
			break
		prizes += 1
		tiers[p["tier"]] = int(tiers.get(p["tier"], 0)) + 1
		last = p
	t.eq(prizes, 60, "60 tickets, 60 prizes")
	t.eq(tiers, {"A": 2, "B": 4, "C": 12, "D": 20, "E": 22}, "drawn without replacement: exactly the set")
	t.ok(bool(last["last_one"]), "the last ticket gets the extra prize")
	t.eq(lot["status"], "sold_out", "sold out")
	var events: Array = s.take_events().map(func(e): return e["type"])
	t.ok(events.has("LOTTERY_SOLD_OUT") and events.has("LOTTERY_TOP"), "the top prizes and the sell-out are news")
	var rev := 0
	var cogs := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["event_id"]).begins_with("kuji:"):
			rev += int(tx["revenue_delta_yen"])
			cogs += int(tx["cogs_delta_yen"])
	t.eq(rev, 700 * 60, "takings: 60 tickets at 700 yen")
	t.eq(cogs, 24000, "the set cost spread over the tickets")
	t.ok(LotteryController.set_line(Lottery.views(s)[0]).contains("完売"), "the card says sold out")


## Customers buy tickets at the till; the tickets left at the end are written off; the set survives a save.
func test_tickets_sell_at_the_till(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "k1", "kind": &"START_LOTTERY", "set_id": "kuji_robots"})
	t.ok(Lottery.visitor_factor(s) > 1.0, "a set with its top prize left draws a few more people")
	Run.run_days(s, cmds, 2)
	var lot: Dictionary = s.lotteries[0]
	var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "SALE" and String(tx["event_id"]).begins_with("kuji:"))
	t.ok(int(lot["sold"]) > 0, "tickets sold at the till (%d)" % int(lot["sold"]))
	t.eq(rows.size(), int(lot["sold"]), "one SALE row per ticket")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "kuji", "2026-10-27T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).lotteries, s.lotteries, "the set, its order and the tickets sold survive a save")
	var sold := int(lot["sold"])
	s.day = int(lot["end_day"]) + 1
	Lottery.close_expired(s)
	t.eq(lot["status"], "ended", "it stops after its last day")
	var w := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "WASTAGE" and String(tx["event_id"]).begins_with("kuji_left:"))
	t.eq(w.size(), 1, "the tickets left are written off")
	var cogs := 0
	for tx in rows:
		cogs += int(tx["cogs_delta_yen"])
	t.eq(cogs + int(w[0]["expense_delta_yen"]), 22000, "sold share + written-off share = the set cost")
	t.eq(int(w[0]["details"]["qty"]), 50 - sold, "every unsold ticket")
