extends RefCounted
## Scenarios with a deadline (ScenarioRules / ScenarioService, user's decision 2026-11-14): the data, the start, the
## verdict once per closed day, no game over, the fixed site, the save and the company's stores.

const Run := preload("res://tests/support/basket_run.gd")


func _report(day: int, revenue: int) -> Dictionary:
	return {"day_index": day, "revenue_yen": revenue}


func test_the_scenario_file_is_valid_and_every_goal_can_be_reached(t, _tree) -> void:
	var problems: Array[String] = []
	var list := ScenarioRules.parse(JSON.parse_string(FileAccess.get_file_as_string(ScenarioRules.DATA_PATH)), problems)
	t.eq(problems, [] as Array[String], "the scenario file is valid")
	t.ok(list.size() >= 3, "three or more scenarios: %d" % list.size())
	var rivals = JSON.parse_string(FileAccess.get_file_as_string(Market.PATH))
	for sc in list:
		var st: Dictionary = sc["start"]
		if st.has("plot_id"):
			t.ok(not WorldMap.site(String(st["map_id"]), String(st["plot_id"])).is_empty(), "%s: its site can be opened" % sc["scenario_id"])
		var rep := int(st.get("reputation", 50))
		for g in sc["goals"]:
			match String(g["metric"]):
				"reputation":   # reputation moves by at most 1 a day
					t.ok(rep + int(sc["days"]) >= int(g["target"]), "%s: reputation %d can be reached in %d days" % [sc["scenario_id"], int(g["target"]), int(sc["days"])])
				"rival_closed":   # the first rival opens on first_day and may close after close_min_days at close_reputation
					t.ok(int(rivals["first_day"]) + int(rivals["close_min_days"]) < int(sc["days"]), "%s: the rival can close in time" % sc["scenario_id"])
					t.ok(rep + int(rivals["first_day"]) + int(rivals["close_min_days"]) >= int(rivals["close_reputation"]), "%s: the reputation to close it can be reached" % sc["scenario_id"])
					t.ok(st.has("plot_id"), "%s: rivals need a site on the map" % sc["scenario_id"])


func test_a_bad_scenario_is_left_out_with_a_reason(t, _tree) -> void:
	var problems: Array[String] = []
	var good := {"scenario_id": "a", "name_ja": "A", "summary_ja": "s", "intro_ja": "i", "clear_ja": "c", "fail_ja": "f", "days": 7,
		"goals": [{"metric": "reputation", "target": 55}]}
	var no_goal := good.duplicate(true)
	no_goal["scenario_id"] = "b"
	no_goal["goals"] = []
	var bad_metric := good.duplicate(true)
	bad_metric["scenario_id"] = "c"
	bad_metric["goals"] = [{"metric": "happiness", "target": 1}]
	var half_site := good.duplicate(true)
	half_site["scenario_id"] = "d"
	half_site["start"] = {"plot_id": "P01"}
	var out := ScenarioRules.parse({"scenarios": [good, no_goal, bad_metric, half_site, good]}, problems)
	t.eq(out.size(), 1, "only the good one")
	t.eq(problems.size(), 4, "a reason for each: %s" % str(problems))


func test_the_verdict_counts_days_and_a_clear_on_the_last_day(t, _tree) -> void:
	var sc := {"days": 7, "goals": [{"metric": "best_day_revenue", "target": 300000}]}
	t.eq(ScenarioRules.verdict(sc, {"best_day_revenue": 10}, 3), "active")
	t.eq(ScenarioRules.verdict(sc, {"best_day_revenue": 300000}, 3), "cleared")
	t.eq(ScenarioRules.verdict(sc, {"best_day_revenue": 10}, 7), "failed", "day 7 = the seventh day has closed")
	t.eq(ScenarioRules.verdict(sc, {"best_day_revenue": 300000}, 7), "cleared", "a clear on the last day counts")
	t.eq(ScenarioRules.days_left(sc, 0), 7)
	t.eq(ScenarioRules.days_left(sc, 9), 0)


func test_starting_a_scenario_sets_cash_reputation_and_site(t, _tree) -> void:
	var s := Run.new_state(100.0)
	t.eq(ScenarioService.start(s, "sc_rebuild"), "")
	t.eq(s.cash_yen, 200000)
	t.eq(s.reputation, 40)
	t.eq(String(s.scenario["status"]), "active")
	var r := Run.new_state(100.0)
	t.eq(ScenarioService.start(r, "sc_rival_battle"), "")
	t.eq(r.plot_id, "P07")
	t.eq(r.location_id, "residential", "the site sets the location")
	t.eq(r.reputation, 58)
	t.eq(ScenarioService.start(Run.new_state(100.0), "nope"), "unknown_scenario")
	var opened := Run.new_state(100.0)
	opened.business_state = GameState.OPEN
	t.eq(ScenarioService.start(opened, "sc_first_week"), "scenario_needs_new_game", "only a new game")
	t.eq(ScenarioService.view(Run.new_state(100.0)), {}, "free play has no scenario")


func test_a_clear_is_announced_once_when_a_day_closes(t, _tree) -> void:
	var s := Run.new_state(100.0)
	ScenarioService.start(s, "sc_first_week")
	s.daily_reports.append(_report(0, 120000))
	s.day = 1
	t.eq(ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO")).size(), 0, "not yet")
	s.daily_reports.append(_report(1, 310000))
	s.day = 2
	var ev := ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO"))
	t.eq(ev.size(), 1)
	t.eq(String(ev[0]["kind"]), "SCENARIO_CLEARED")
	t.eq(int(ev[0]["days_used"]), 2, "cleared in two days")
	t.eq(String(s.scenario["status"]), "cleared")
	t.eq(int(s.scenario["result_day"]), 1)
	s.day = 3
	t.eq(ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO")).size(), 0, "announced once")
	var view := ScenarioService.view(s)
	t.ok(view["goals"][0]["done"], "the goal shows as met")


func test_a_missed_deadline_is_announced_once_and_the_game_goes_on(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	ScenarioService.start(s, "sc_first_week")
	for d in 7:
		s.daily_reports.append(_report(d, 1000))
	s.day = 7
	var ev := ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO"))
	t.eq(ev.map(func(e): return e["kind"]), ["SCENARIO_FAILED"])
	t.eq(String(s.scenario["status"]), "failed")
	s.daily_reports.append(_report(7, 900000))
	s.day = 8
	t.eq(ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO")).size(), 0, "no clear after the deadline")
	t.ok(cmds.execute({"command_id": "after", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 1}).ok, "no game over: the store still takes commands")


func test_a_scenario_fixes_its_site_and_keeps_its_rivals(t, _tree) -> void:
	var s := Run.new_state(100.0)
	ScenarioService.start(s, "sc_rival_battle")
	var cmds := GameCommands.new(s)
	var r := cmds.execute({"command_id": "site", "kind": &"SET_SITE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P05"})
	t.eq(r.message_key, &"scenario_site_fixed")
	t.eq(cmds.execute({"command_id": "loc", "kind": &"SET_LOCATION", "location_id": "school"}).message_key, &"scenario_site_fixed")
	t.eq(cmds.execute({"command_id": "rv", "kind": &"SET_RIVALS", "enabled": false}).message_key, &"scenario_needs_rivals")
	t.ok(cmds.execute({"command_id": "rv2", "kind": &"SET_RIVALS", "enabled": true}).ok, "turning them on is fine")
	var free := Run.new_state(100.0)
	ScenarioService.start(free, "sc_first_week")
	t.ok(GameCommands.new(free).execute({"command_id": "site", "kind": &"SET_SITE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P05"}).ok, "a scenario without a site lets the player pick one")


func test_the_rival_goal_counts_a_rival_closed_for_good(t, _tree) -> void:
	var s := Run.new_state(100.0)
	ScenarioService.start(s, "sc_rival_battle")
	s.rivals.append({"rival_id": "rival_01", "opened_day": 4})
	s.day = 20
	t.eq(int(ScenarioService.values(s)["rival_closed"]), 0)
	s.rivals[0]["closed_day"] = 25
	s.day = 25
	var ev := ProgressionService.evaluate(s).filter(func(e): return String(e["kind"]).begins_with("SCENARIO"))
	t.eq(ev.map(func(e): return e["kind"]), ["SCENARIO_CLEARED"])


func test_the_scenario_survives_a_save_and_older_saves_are_free_play(t, _tree) -> void:
	var s := Run.new_state(100.0)
	ScenarioService.start(s, "sc_station_rush")
	s.scenario["judged_day"] = 3
	var data := SaveGame.to_dict(s, "sc", "2026-11-14T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	var back: GameState = lr["state"]
	t.eq(back.scenario, {"scenario_id": "sc_station_rush", "status": "active", "judged_day": 3, "result_day": -1})
	t.eq(back.plot_id, "P01")
	(data["runtime_state"] as Dictionary).erase("scenario")
	var old := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(old["ok"], "a save from before scenarios loads")
	t.eq((old["state"] as GameState).scenario, {}, "as free play")
	data["runtime_state"]["scenario"] = {"scenario_id": "gone", "status": "active", "judged_day": 0, "result_day": -1}
	var odd := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(odd["ok"] and (odd["state"] as GameState).scenario.is_empty(), "an unknown scenario is dropped, the save still loads")


func test_every_store_of_the_company_shares_the_scenario(t, _tree) -> void:
	var a := Run.new_state(100.0)
	ScenarioService.start(a, "sc_first_week")
	a.ledger.cash_yen = 20000000
	t.ok(GameCommands.new(a).execute({"command_id": "o1", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": "P05", "size_id": "small"}).ok, "a second store")
	var b := Company.switch_to(a, "s2")
	t.ok(b.scenario == a.scenario and is_same(b.scenario, a.scenario), "the second store sees the same scenario")
	a.daily_reports.append(_report(0, 400000))
	b.day = 1
	ProgressionService.evaluate(b)
	t.eq(String(a.scenario["status"]), "cleared", "judged on the first store's days, from either store")
