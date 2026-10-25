extends RefCounted
## Issue #144: daily hiring candidates from the archetypes, hire / fire within the staff room's cap, the staffing
## figures by hour and the advice, a friendly cashier keeps the line patient, candidates survive a save.

const Paths := preload("res://tests/scenario/test_customer_paths.gd")


func _store(t) -> GameState:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	s.balance["outdoor_approach"] = false
	return s


func _cmd(s: GameState, kind: StringName, payload: Dictionary) -> CommandResult:
	var c := {"command_id": "hi_%d_%s" % [s.applied_command_ids.size(), kind], "kind": kind}
	c.merge(payload)
	return GameCommands.new(s).execute(c)


func test_candidates_are_drawn_from_the_archetypes(t, _tree) -> void:
	var a := _store(t)
	var b := _store(t)
	t.eq(a.staff_candidates.size(), StaffMarket.CANDIDATES_PER_DAY, "three candidates")
	t.eq(a.staff_candidates, b.staff_candidates, "the same seed offers the same people")
	var ranges := {}
	for arc in StaffMarket.data()["archetypes"]:
		ranges[arc["archetype"]] = arc["skills"]
	for c in a.staff_candidates:
		t.ok(ranges.has(c["archetype"]), "a known archetype: " + c["archetype"])
		for k in StaffAI.SKILLS:
			var r: Array = ranges[c["archetype"]][k]
			t.ok(int(c["skills"][k]) >= int(r[0]) and int(c["skills"][k]) <= int(r[1]), "%s %s within %s" % [c["archetype"], k, str(r)])
	# a new morning, new faces
	var first := a.staff_candidates.duplicate(true)
	var runner := SimulationRunner.new(a)
	a.time_sec = DemandModel.SECONDS_PER_DAY - 20   # straight to the next morning
	while a.day == 0:
		runner._run_step()
	t.ok(a.staff_candidates != first, "the next morning brings other candidates")
	t.ok(String(a.staff_candidates[0]["candidate_id"]).begins_with("cand_d001_"), "ids carry the day")
	# many draws cover every archetype
	var seen := {}
	for d in 30:
		a.day = d
		StaffMarket.draw_candidates(a)
		for c in a.staff_candidates:
			seen[c["archetype"]] = true
	t.eq(seen.size(), (StaffMarket.data()["archetypes"] as Array).size(), "sharp and balanced types all appear")


func test_hiring_is_capped_by_the_staff_room(t, _tree) -> void:
	var s := _store(t)
	var cand: String = s.staff_candidates[0]["candidate_id"]
	var r := _cmd(s, &"HIRE_STAFF", {"candidate_id": cand})
	t.ok(not r.ok and r.message_key == &"staff_cap_reached", "two staff and no staff room: full")
	s.business_state = GameState.SETUP
	t.ok(_cmd(s, &"PLACE_FIXTURE", {"type_id": "staff_room_s", "x": 1, "y": 1, "rotation": 0}).ok, "a small staff room (cap 3)")
	s.business_state = GameState.OPEN
	var wages_before := BusinessService.wages(s)
	r = _cmd(s, &"HIRE_STAFF", {"candidate_id": cand})
	t.ok(r.ok, "hired: %s" % r.message_key)
	t.eq(s.staff.size(), 3, "three staff")
	t.ok(BusinessService.wages(s) > wages_before, "the wage bill grows")
	t.ok(not s.staff_candidates.any(func(c): return c["candidate_id"] == cand), "the candidate is gone from the list")
	r = _cmd(s, &"HIRE_STAFF", {"candidate_id": s.staff_candidates[0]["candidate_id"]})
	t.ok(not r.ok and r.message_key == &"staff_cap_reached", "the room's cap holds")
	# a smaller room never fires anyone
	s.business_state = GameState.SETUP
	t.ok(_cmd(s, &"REMOVE_FIXTURE", {"instance_id": StaffAI.staff_room(s)}).ok, "staff room removed")
	t.eq(s.staff.size(), 3, "the staff stay")
	r = _cmd(s, &"FIRE_STAFF", {"staff_id": s.staff[2]["staff_id"]})
	t.ok(r.ok, "let one go")
	t.eq(s.staff.size(), 2)
	t.ok(not _cmd(s, &"FIRE_STAFF", {"staff_id": "staff_999"}).ok, "an unknown person cannot be fired")


func test_staffing_figures_and_advice(t, _tree) -> void:
	var s := _store(t)
	s.balance["checkout_base_game_seconds"] = 3000   # a slow till builds a line
	var runner := SimulationRunner.new(s)
	for i in 12:
		s.next_customer_seq += 1
		s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
		for k in 30:
			runner._run_step()
	for i in 1500:
		runner._run_step()
	var lines := StaffMarket.line_by_hour(s.staff_metrics)
	var peak := 0.0
	for v in lines:
		peak = maxf(peak, float(v))
	t.ok(peak >= 1.0, "the line is recorded by hour: peak %.1f" % peak)
	var util := 0.0
	for st in s.staff:
		util = maxf(util, StaffMarket.utilisation(s.staff_metrics, st["staff_id"]))
	t.ok(util > 0.3, "the cashier is busy most of the time: %.2f" % util)
	StaffMarket.note(s, "balked")
	t.eq(int(s.staff_metrics["balked"][DemandModel.hour_of_day(s.time_sec)]), 1, "a turned-back customer is counted in its hour")
	var advice := StaffMarket.advice(s)
	t.ok(advice.contains("時台のレジ待ち"), "the advice names the busy hour: %s" % advice)
	t.ok(advice.contains("上限"), "and says the cap is reached (2 staff, no room)")
	var view: Dictionary = s.snapshot()["staffing"]
	t.eq((view["line_today"] as Array).size(), 24, "the 店員 tab gets 24 hours")
	t.eq(String(view["advice"]), advice)


func test_a_friendly_cashier_keeps_the_line_patient(t, _tree) -> void:
	var s := _store(t)
	var c := {"queue_since": 0, "register_id": "x"}
	s.time_sec = int(s.balance["queue_patience_game_seconds"]) + 10
	var ai := CustomerAI.new()
	t.ok(ai._timed_out(s, c), "nobody at the till: the base patience runs out")
	s.staff[0]["phase"] = "REGISTER"
	s.staff[0]["skills"]["service"] = 5
	t.ok(not ai._timed_out(s, c), "a service-5 cashier keeps people waiting longer")
	s.staff[0]["skills"]["service"] = 1
	t.ok(ai._timed_out(s, c), "a service-1 cashier does not")


func test_candidates_survive_a_save(t, _tree) -> void:
	var s := _store(t)
	var saved := SaveGame.to_dict(s, "hire", "2026-10-25T00:00:00Z")
	var r := SaveGame.from_dict(saved, s.balance, s.fixtures, s.products)
	t.ok(r["ok"], str(r["errors"]))
	t.eq((r["state"] as GameState).staff_candidates, s.staff_candidates, "same candidates after loading")


func test_tab_texts(t, _tree) -> void:
	t.eq(StaffController.summary_text(2, 3, 1760), "店員 2 / 上限 3人　人件費 ¥1,760/日")
	var c := {"name": "高橋", "label": "レジ得意", "skills": {"register": 5, "restock": 1, "stamina": 2, "service": 3}, "daily_wage_yen": 840}
	t.eq(StaffController.candidate_line(c), "高橋（レジ得意）　レジ 5　品出し 1　体力 2　接客 3　日給 ¥840")
	var line: Array = []
	line.resize(24)
	line.fill(0.0)
	line[12] = 2.4
	var lost: Array = []
	lost.resize(24)
	lost.fill(0)
	lost[12] = 3
	var text := StaffController.hours_text(line, lost, lost)
	t.ok(text.contains("12時 ■■■■■ 2.4人　帰った 6人"), "the noon line: %s" % text.split("\n")[6])
