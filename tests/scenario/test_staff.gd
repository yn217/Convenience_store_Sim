extends RefCounted
## Issue #143: store staff — the staff room and the staff cap, the register is open only with a cashier, checkout
## speed follows the register skill, fatigue and rest, restocking from the backroom, wages, save/load.

const Paths := preload("res://tests/scenario/test_customer_paths.gd")


func _store(t) -> GameState:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	s.balance["outdoor_approach"] = false   # customers appear at the door: these tests are about the staff
	return s


func _arrive(s: GameState) -> String:
	s.next_customer_seq += 1
	var id := "cust_%05d" % s.next_customer_seq
	s.arrival_queue.append({"customer_id": id, "arrived_at_sec": s.time_sec})
	return id


func _cmd(s: GameState, kind: StringName, payload: Dictionary) -> CommandResult:
	var c := {"command_id": "st_%d_%s" % [s.applied_command_ids.size(), kind], "kind": kind}
	c.merge(payload)
	return GameCommands.new(s).execute(c)


func test_staff_rooms_set_the_cap(t, _tree) -> void:
	var s := _store(t)
	t.eq(s.staff.size(), 2, "the store starts with two staff")
	t.eq(StaffAI.capacity(s), 2, "without a staff room: 2")
	s.business_state = GameState.SETUP
	var r := _cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_l", "x": 1, "y": 1, "rotation": 0})
	t.ok(not r.ok and r.message_key == &"store_too_small", "the large room needs a 20-wide store: %s" % r.message_key)
	r = _cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_m", "x": 1, "y": 1, "rotation": 0})
	t.ok(r.ok, "the medium room fits the 16x12 store: %s %s" % [r.code, r.message_key])
	t.eq(StaffAI.capacity(s), 6, "a medium room allows 6")
	r = _cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_s", "x": 1, "y": 5, "rotation": 0})
	t.ok(not r.ok and r.message_key == &"staff_room_exists", "one staff room per store")


## The till is closed until a cashier stands behind it; then the checkout runs at the cashier's speed.
func test_the_register_needs_a_cashier(t, _tree) -> void:
	var s := _store(t)
	var runner := SimulationRunner.new(s)
	var ai: CustomerAI = runner._customers
	var reg := String(ai.register_plan_now(s)["register_id"])
	var cell := StaffAI.cashier_cell(s, reg)
	t.ok(cell.x >= 0, "the register has a cashier cell behind it: %s" % cell)
	t.ok(StaffAI.cashier(s, reg).is_empty(), "nobody at the till at first: closed")
	var guard := 0
	while StaffAI.cashier(s, reg).is_empty() and guard < 2000:
		runner._run_step()
		guard += 1
	var cashier := StaffAI.cashier(s, reg)
	t.ok(not cashier.is_empty(), "a staff member walked to the till (%d steps)" % guard)
	t.eq(cashier["tile"], cell, "and stands at the cashier cell")
	var slow := cashier.duplicate(true)
	slow["skills"]["register"] = 1
	var fast := cashier.duplicate(true)
	fast["skills"]["register"] = 5
	cashier["skills"]["register"] = 1
	var t1 := StaffAI.checkout_seconds(s, reg, 2)
	cashier["skills"]["register"] = 5
	var t5 := StaffAI.checkout_seconds(s, reg, 2)
	t.ok(t5 < t1, "a quick cashier checks out faster: %d < %d s" % [t5, t1])
	cashier["fatigue"] = 95.0
	t.ok(StaffAI.checkout_seconds(s, reg, 2) > t5, "a tired one is slower")


func test_no_cashier_no_checkout(t, _tree) -> void:
	var s := _store(t)
	s.staff.clear()   # nobody works today
	var runner := SimulationRunner.new(s)
	_arrive(s)
	for i in 3000:
		runner._run_step()
	t.eq(int(s.visit_stats["purchased"]), 0, "with no staff nobody can pay")
	t.ok(runner._customers.should_balk(s), "and new customers would turn back at the door")


func test_fatigue_rises_and_rest_recovers(t, _tree) -> void:
	var s := _store(t)
	s.business_state = GameState.SETUP
	t.ok(_cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_s", "x": 1, "y": 1, "rotation": 0}).ok, "a staff room")
	s.business_state = GameState.OPEN
	s.balance["staff_fatigue_per_hour"] = {"register": 60, "restock": 60, "walk": 40, "idle": 20, "rest": -120}   # a quick day
	var runner := SimulationRunner.new(s)
	var rested := false
	var peak := 0.0
	for i in 20000:
		runner._run_step()
		for st in s.staff:
			peak = maxf(peak, float(st["fatigue"]))
			if st["phase"] == "REST":
				rested = true
		if rested and peak >= float(s.balance["staff_rest_threshold"]):
			break
	t.ok(peak >= float(s.balance["staff_rest_threshold"]), "work tires the staff: peak %.1f" % peak)
	t.ok(rested, "a tired person went to rest in the staff room")
	var before := 0.0
	var resting: Dictionary = {}
	for st in s.staff:
		if st["phase"] == "REST":
			resting = st
	if not resting.is_empty():
		before = float(resting["fatigue"])
		for i in 300:
			runner._run_step()
		t.ok(float(resting["fatigue"]) < before, "resting lowers fatigue: %.1f -> %.1f" % [before, resting["fatigue"]])
	# midnight
	s.time_sec = DemandModel.SECONDS_PER_DAY - 20
	while s.time_sec % DemandModel.SECONDS_PER_DAY != 0:
		runner._run_step()
	for st in s.staff:
		t.eq(float(st["fatigue"]), 0.0, "a new day starts rested")


## A tired cashier hands the till over: it stays until the relief stands at the till, so the register never closes
## for the change (realistic-store soak, 2026-10-25: customers stood at a closed till while the relief walked over).
func test_the_till_stays_open_during_a_handover(t, _tree) -> void:
	var s := _store(t)
	s.business_state = GameState.SETUP
	t.ok(_cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_s", "x": 1, "y": 1, "rotation": 0}).ok, "a staff room")
	s.business_state = GameState.OPEN
	s.balance["staff_fatigue_per_hour"] = {"register": 60, "restock": 20, "walk": 20, "idle": 10, "rest": -120}
	var runner := SimulationRunner.new(s)
	var was := {}
	var handovers := 0
	var bad := 0
	for i in 20000:
		runner._run_step()
		var at_till: Array = s.staff.filter(func(x): return x["phase"] == "REGISTER")
		for st in s.staff:
			var prev: String = was.get(st["staff_id"], "")
			if prev == "REGISTER" and st["phase"] in ["TO_REST", "REST"] and float(st["fatigue"]) < StaffAI.FORCED:
				handovers += 1
				if at_till.is_empty():
					bad += 1
			was[st["staff_id"]] = st["phase"]
		if handovers >= 3:
			break
	t.ok(handovers >= 1, "the cashier handed over for a rest (%d times)" % handovers)
	t.eq(bad, 0, "every time someone else already stood at the till")


## A slot below the threshold with stock in the backroom is refilled by a staff member.
func test_staff_restock_from_the_backroom(t, _tree) -> void:
	var s := _store(t)
	var drink_slot := {}
	var drink_id := ""
	for id in s.grid.instances:
		if s.grid.instances[id]["type_id"] == "fridge_drink":
			drink_id = id
			drink_slot = s.fixtures.get_type("fridge_drink")["shelf_slots"][0]
	t.ok(_cmd(s, &"ORDER_STOCK", {"sku_id": "drink_001", "qty": 30}).ok, "stock arrives in the backroom")
	var back_before := s.backroom_available("drink_001")
	var need_before := StaffAI._slot_need(s, drink_id, drink_slot, "drink_001")
	t.ok(need_before > 0, "the drink slot is not full (%d free)" % need_before)
	var runner := SimulationRunner.new(s)
	var restocked := 0
	for i in 6000:
		runner._run_step()
		for e in s.event_log.slice(maxi(s.event_log.size() - 10, 0)):
			if e["type"] == "STAFF_RESTOCKED" and int(e["tick"]) == s.time_sec:
				restocked += int(e["payload"]["qty"])
		if restocked > 0:
			break
	t.ok(restocked > 0, "staff carried %d units to a shelf" % restocked)
	t.ok(s.backroom_available("drink_001") < back_before or restocked > 0, "from the backroom")


func test_wages_are_a_daily_cost(t, _tree) -> void:
	var s := _store(t)
	var costs := BusinessService.day_costs(s)
	var expect := 0
	for st in s.staff:
		expect += StaffAI.daily_wage(s.balance, st)
	t.eq(int(costs["WAGES"]), expect, "wages = the sum of the daily wages")
	t.eq(StaffAI.daily_wage(s.balance, s.staff[0]), int(s.balance["staff_wage_base_yen"]) + 12 * int(s.balance["staff_wage_per_skill_yen"]), "a balanced person's wage")
	var runner := SimulationRunner.new(s)
	s.time_sec = DemandModel.SECONDS_PER_DAY - 20   # straight to midnight
	while s.day == 0:
		runner._run_step()
	var sum := LedgerSummary.summarize(s.ledger, 1)
	t.eq(int(sum["wages_yen"]), expect, "day 1's ledger books the wages")
	var report: Dictionary = s.daily_reports.back()
	t.ok(report.has("wages_yen"), "the daily report has a wages line")


func test_staff_survive_a_save(t, _tree) -> void:
	var s := _store(t)
	s.business_state = GameState.SETUP
	_cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_s", "x": 1, "y": 1, "rotation": 0})
	s.business_state = GameState.OPEN
	var runner := SimulationRunner.new(s)
	for i in 400:
		runner._run_step()
	var saved := SaveGame.to_dict(s, "staff", "2026-10-25T00:00:00Z")
	var r := SaveGame.from_dict(saved, s.balance, s.fixtures, s.products)
	t.ok(r["ok"], str(r["errors"]))
	var l: GameState = r["state"]
	t.eq(l.staff.size(), s.staff.size(), "same staff")
	for i in s.staff.size():
		t.eq(l.staff[i]["phase"], s.staff[i]["phase"], "phase of %s" % s.staff[i]["staff_id"])
		t.eq(l.staff[i]["tile"], s.staff[i]["tile"])
		t.eq(l.staff[i]["path"], s.staff[i]["path"])
		t.ok(absf(float(l.staff[i]["fatigue"]) - float(s.staff[i]["fatigue"])) < 0.001, "fatigue kept")
	t.eq(JSON.stringify(SaveGame.to_dict(l, "staff", "2026-10-25T00:00:00Z")), JSON.stringify(saved), "it saves the same again")


func test_staff_panel_lines(t, _tree) -> void:
	var c := {"customer_id": "staff_001", "staff": true, "name": "佐藤", "archetype": "balanced",
		"skills": {"register": 3, "restock": 4, "stamina": 2, "service": 3}, "fatigue": 41.6, "daily_wage_yen": 880, "phase": "TO_SHELF", "carry": 8}
	var lines := OverlayModel.customer_panel_lines(c, "飲料冷蔵ケース")
	t.eq(lines[0], "店員 佐藤（バランス型）")
	t.eq(lines[1], "レジ 3　品出し 4　体力 2　接客 3")
	t.eq(lines[2], "疲労 42%　日給 ¥880")
	t.eq(lines[3], "仕事：飲料冷蔵ケースへ商品を運んでいる（8個）")
