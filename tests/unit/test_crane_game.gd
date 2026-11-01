extends RefCounted
## Issue #132: the crane game (UFO catcher). A session at the machine: plays paid there one by one (never at the till),
## the prize taken out only on a win, the plays bounded by patience and money, the counts saved; a store without the
## machine keeps its old behaviour.

const Run := preload("res://tests/support/basket_run.gd")


func _customer(id: String, wallet: int, planned: int) -> Dictionary:
	return {"customer_id": id, "fixture_id": "fx_1", "sku_id": "crane_001", "wallet_yen": wallet, "planned_yen": planned}


## The session follows from the customer and the machine: the same customer plans the same plays; the plays stop at
## the first win and never pass max_plays or the money left; some sessions win and some do not.
func test_a_session_is_fixed_and_bounded(t, _tree) -> void:
	var s := Run.new_state(100.0)
	t.eq(CraneGame.plan(s, _customer("c1", 2000, 100)), CraneGame.plan(s, _customer("c1", 2000, 100)), "the same customer, the same plays")
	var wins := 0
	for i in 400:
		var pl := CraneGame.plan(s, _customer("c%03d" % i, 2000, 100))
		t.ok(int(pl["plays"]) >= 1 and int(pl["plays"]) <= int(CraneGame.data()["max_plays"]), "1..max_plays")
		if int(pl["win_at"]) > 0:
			wins += 1
			t.eq(int(pl["win_at"]), int(pl["plays"]), "the plays stop at the win")
	t.ok(wins > 60 and wins < 300, "some sessions win, some do not (%d of 400)" % wins)
	t.eq(int(CraneGame.plan(s, _customer("c1", 150, 100))["plays"]), 1, "money for one play only: one play")
	t.eq(CraneGame.session_seconds(s, _customer("c1", 150, 100)), int(CraneGame.data()["play_seconds"]), "the time at the machine grows with the plays")


## A machine in a running store: customers play at it, every play is a SALE at the machine, a win takes a prize out
## (its cost booked), the counts match the ledger and survive a save; the ledger stays consistent.
func test_plays_are_paid_at_the_machine(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(1, s.grid.height - 1):
		for x in range(1, s.grid.width - 2):
			if placed == "":
				var r := cmds.execute({"command_id": "cr_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "crane_game", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.ok(placed != "", "a crane game placed")
	Run.run_days(s, cmds, 1, 21)
	var plays := 0
	var wins := 0
	var fee_only := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["event_id"]).begins_with("crane:"):
			plays += 1
			t.eq(String(tx["details"].get("fixture_id", "")), placed, "booked on the machine")
			if int(tx["cogs_delta_yen"]) > 0:
				wins += 1
			else:
				fee_only += 1
	t.ok(plays > 0, "customers played (%d plays)" % plays)
	t.ok(fee_only > 0, "plays without a win pay the fee only (%d)" % fee_only)
	t.eq(int(s.crane_stats[placed]["plays"]), plays, "every play counted")
	t.eq(int(s.crane_stats[placed]["wins"]), wins, "every win counted (%d)" % wins)
	t.ok(int(s.fixture_money_today().get(placed, {}).get("revenue_yen", 0)) > 0, "the machine's takings show on its card")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	var saved := SaveGame.to_dict(s, "cr", "2026-10-28T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).crane_stats, s.crane_stats, "the counts survive a save")
	t.ok(CueText.toast_text("crane_won", {"prize": "しろねこ", "plays": 3}).contains("しろねこ"), "a win is announced")


## Phase 2: a store holds at most max_per_store machines, and a machine emptied by a win is announced.
func test_cap_and_empty_notice(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed: Array[String] = []
	var refused := ""
	for y in range(1, s.grid.height - 1):
		for x in range(1, s.grid.width - 2):
			var r := cmds.execute({"command_id": "cr_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "crane_game", "x": x, "y": y, "rotation": 0})
			if r.ok:
				placed.append(String(r.data["instance_id"]))
			elif r.message_key == &"crane_limit":
				refused = "crane_limit"
	var cap := int(CraneGame.data()["max_per_store"])
	t.eq(placed.size(), cap, "at most %d machines in a store" % cap)
	t.eq(refused, "crane_limit", "a further machine is refused with its own reason")
	t.ok(CommandMessages.text(&"INVALID_OPERATION", &"crane_limit").contains("2台"), "the reason is shown to the player")

	var fid := placed[0]
	CraneGame.check_empty(s, fid)
	var empties := s.event_log.filter(func(e): return e["type"] == "CRANE_EMPTY")
	t.eq(empties.size(), 1, "an empty machine is announced")
	t.eq(String(empties[0]["payload"]["fixture_id"]), fid, "for that machine")
	t.ok(CueText.toast_text("crane_empty", {}).contains("補充"), "the notice asks for a refill")


## Phase 2 breakdowns: the play count to the next breakdown is fixed per machine and repair and stays in range; a
## machine past it breaks after its session, takes no players while broken, and a paid repair (a REPAIR row, counted
## with the fixed costs) puts it back; the state survives a save.
func test_breakdown_and_repair(t, _tree) -> void:
	var d: Dictionary = CraneGame.data()["breakdown"]
	var lo := int(d["after_plays"][0])
	var hi := int(d["after_plays"][1])
	t.eq(CraneGame.break_after("fx_1", 0), CraneGame.break_after("fx_1", 0), "the same machine breaks at the same play")
	var differs := false
	for i in 50:
		var n := CraneGame.break_after("fx_%d" % i, i % 3)
		t.ok(n >= lo and n <= hi, "%d..%d plays to a breakdown (%d)" % [lo, hi, n])
		differs = differs or n != CraneGame.break_after("fx_0", 0)
	t.ok(differs, "machines break at different plays")

	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(1, s.grid.height - 1):
		for x in range(1, s.grid.width - 2):
			if placed == "":
				var r := cmds.execute({"command_id": "cb_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "crane_game", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.eq(cmds.execute({"command_id": "rp0", "kind": &"REPAIR_CRANE", "fixture_id": placed}).message_key, &"crane_not_broken", "a working machine needs no repair")
	s.crane_stats[placed] = {"plays": 0, "wins": 0, "since": 100000, "repairs": 0, "broken": false}   # due to break
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	var broke: Array = []   # drained each step: the event log keeps only the latest events
	while s.day == 0 and s.time_sec < 21 * 3600:
		runner._run_step()
		broke.append_array(s.take_events().filter(func(e): return e["type"] == "CRANE_BROKEN"))
	t.ok(CraneGame.is_broken(s, placed), "the machine broke")
	t.eq(broke.size(), 1, "the breakdown is announced once")
	t.ok(CueText.toast_text("crane_broken", broke[0]["payload"]).contains("修理"), "the notice says how to fix it")
	var plays := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["event_id"]).begins_with("crane:"):
			plays += 1
	t.ok(plays >= 1, "the breaking session was played")
	t.eq(int(s.crane_stats[placed]["plays"]), plays, "no plays once broken (%d)" % plays)
	var machine_offered := false
	for e in CustomerAI.new().candidates(s):
		machine_offered = machine_offered or e["fixture_id"] == placed
	t.ok(not machine_offered, "a broken machine is not offered to customers")

	var saved := SaveGame.to_dict(s, "cb", "2026-10-29T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).crane_stats, s.crane_stats, "the breakdown survives a save")

	var cash := s.ledger.cash_yen
	var fixed_before := int(LedgerSummary.summarize(s.ledger, s.day)["fixed_cost_yen"])
	var r := cmds.execute({"command_id": "rp1", "kind": &"REPAIR_CRANE", "fixture_id": placed})
	t.ok(r.ok, "the repair is done")
	t.eq(s.ledger.cash_yen, cash - CraneGame.repair_cost(), "the repair is paid")
	t.eq(int(LedgerSummary.summarize(s.ledger, s.day)["fixed_cost_yen"]), fixed_before + CraneGame.repair_cost(), "counted with the fixed costs")
	t.ok(not CraneGame.is_broken(s, placed), "back in order")
	t.eq(int(s.crane_stats[placed]["since"]), 0, "the count to the next breakdown starts again")
	t.eq(int(s.crane_stats[placed]["repairs"]), 1, "one repair counted")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	t.ok(FixtureCard.repair_text(CraneGame.repair_cost()).contains("¥5,000"), "the card's button shows the cost")


## Without the machine nobody comes to play.
func test_no_machine_no_players(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pick := Lcg32.new(5)
	var money := Lcg32.new(6)
	var n := 0
	var m := 0
	for i in 2000:
		if VisitPurpose.draw(pick, money, 17, balance, "", ["drink", "snack", "rice_ball"])["purpose_id"] == "crane_game":
			n += 1
		if VisitPurpose.draw(pick, money, 17, balance, "", ["drink", "snack", "rice_ball", "crane_prize"])["purpose_id"] == "crane_game":
			m += 1
	t.eq(n, 0, "no machine: nobody comes to play")
	t.ok(m > 20, "with a machine some come to play in the evening (%d)" % m)
