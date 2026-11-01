extends RefCounted
## Issues #28/#32 (domain part): tutorial steps, 12 milestones and the 3-day challenge rotation are
## judged from state and ledger data only, announced once, saved, and never pay anything out.

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.milestones = ProgressionService.load_milestones(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/mvp_v1.milestones.json")))
	return s


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	_n += 1
	var c := {"command_id": "g%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _ids(events: Array[Dictionary]) -> Array:
	return events.map(func(e): return e["id"])


func _step(s: GameState) -> int:
	return int(s.progression_state["tutorial_step_index"])


func _sale(s: GameState, n: int, price: int = 150, cost: int = 100) -> void:
	for i in n:
		s.ledger.record("SALE", "sale_%d_%d" % [s.ledger.transactions.size(), i], price, s.day, s.time_sec, {"qty": 1}, {"revenue": price, "cogs": cost})


func test_the_shipped_milestones_load(t, _tree) -> void:
	var problems: Array[String] = []
	var list := ProgressionService.load_milestones(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/mvp_v1.milestones.json")), problems)
	t.eq(problems, [] as Array[String])
	t.eq(list.size(), 12)
	var seen := {}
	for m in list:
		t.ok(not seen.has(m["milestone_id"]))
		seen[m["milestone_id"]] = true
		t.eq(m["reward"]["kind"], "badge_only", "rewards are badges only")


func test_milestone_loader_rejects_bad_data(t, _tree) -> void:
	var good := {"schema_version": 1, "milestone_id": "ms_x", "name_ja": "テスト", "metric": "total_sales_count", "threshold": 1, "reward": {"kind": "badge_only", "badge_id": "badge_x"}, "notice_cue_id": "milestone_celebrate"}
	for mutate in [
		func(m): m["metric"] = "total_magic",
		func(m): m["threshold"] = 0,
		func(m): m["threshold"] = 1.5,
		func(m): m["reward"] = {"kind": "cash", "badge_id": "badge_x"},
		func(m): m["milestone_id"] = "x",
		func(m): m.erase("name_ja"),
		func(m): m["extra"] = 1,
	]:
		var bad: Dictionary = good.duplicate(true)
		mutate.call(bad)
		var problems: Array[String] = []
		var list := ProgressionService.load_milestones([bad], problems)
		t.ok(not problems.is_empty() and list.is_empty(), str(bad))
	var dup: Array[String] = []
	ProgressionService.load_milestones([good, good], dup)
	t.ok(not dup.is_empty(), "duplicate ids")
	var none: Array[String] = []
	ProgressionService.load_milestones({}, none)
	t.ok(not none.is_empty())


func test_tutorial_follows_the_state_step_by_step(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.eq(_step(s), 0)
	t.eq(_ids(ProgressionService.evaluate(s)), ["tut_01"], "tut_01: the game is running")
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	t.eq(_step(s), 1, "a shelf alone is not the register step")
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	t.eq(_step(s), 3, "register done, and the shelf already counts for tut_03: both pass at once")
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 9})
	t.eq(_step(s), 3, "9 units is not 10")
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 1})
	t.eq(_step(s), 4)
	_run(cmds, &"RESTOCK", {"instance_id": "fx_0001", "slot_id": "row0", "sku_id": "rice_001", "qty": 4})
	t.eq(_step(s), 5, "stock on a shelf customers can reach")
	t.ok(_run(cmds, &"START_BUSINESS").ok)
	t.eq(_step(s), 6)
	_sale(s, 1)
	ProgressionService.evaluate(s)
	t.eq(_step(s), 7)
	s.close_day_once(0)
	ProgressionService.evaluate(s)
	t.eq(_step(s), 8, "the DAY0 report completes the last step")
	t.eq(ProgressionService.evaluate(s).size(), 0, "nothing new: each step is announced once")


func test_steps_already_satisfied_advance_together_and_are_announced_once(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	s.progression_state["tutorial_step_index"] = 0
	# Build the state without evaluation in between (e.g. loaded or done in one go).
	s.grid.add_instance({"instance_id": "fx_0001", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0, "enabled": true}, s.fixtures)
	s.grid.add_instance({"instance_id": "fx_0002", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0, "enabled": true}, s.fixtures)
	var events := ProgressionService.evaluate(s)
	t.eq(_ids(events), ["tut_01", "tut_02", "tut_03"])
	t.eq(s.take_progression_events().size(), 3, "queued for the UI")
	t.eq(s.take_progression_events().size(), 0, "taken once")
	t.ok(cmds != null)


func test_evaluating_pays_nothing(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_sale(s, 12)
	var cash := s.cash_yen
	var rep := s.reputation
	var stock := s.inventory_segments.duplicate(true)
	var prices := s.product_price_overrides.duplicate()
	ProgressionService.evaluate(s)
	t.ok(s.progression_state["completed_milestone_ids"].size() >= 2, "milestones were reached")
	t.eq(s.cash_yen, cash, "no cash reward")
	t.eq(s.reputation, rep, "no reputation reward")
	t.eq(s.inventory_segments, stock)
	t.eq(s.product_price_overrides, prices)


func test_sales_milestones_count_confirmed_sales_once(t, _tree) -> void:
	var s := _state()
	_sale(s, 1)
	t.eq(_ids(ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "MILESTONE")), ["ms_first_sale"])
	# The same transaction id re-sent is refused by the ledger and cannot add a second sale.
	var rows := s.ledger.transactions.size()
	s.ledger.record("SALE", s.ledger.transactions[0]["event_id"], 150, 0, 0, {"qty": 1}, {"revenue": 150, "cogs": 100})
	t.eq(s.ledger.transactions.size(), rows)
	t.eq(ProgressionService.evaluate(s).size(), 0)
	_sale(s, 9)
	t.eq(_ids(ProgressionService.evaluate(s)), ["ms_ten_sales"])
	_sale(s, 40)
	var ids := _ids(ProgressionService.evaluate(s))
	t.ok(ids.has("ms_fifty_sales") and ids.has("ms_revenue_10000") == false or ids.has("ms_fifty_sales"))
	t.eq(s.progression_totals["sales"], 50)
	t.eq(ProgressionService.level(s), s.progression_state["completed_milestone_ids"].size())


func test_other_milestone_metrics(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	for spec in [[4, 5], [4, 8], [10, 5]]:
		_run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": spec[0], "y": spec[1], "rotation": 0})
	t.ok(s.progression_state["completed_milestone_ids"].has("ms_three_fixtures"))
	s.reputation = 69
	ProgressionService.evaluate(s)
	t.ok(not s.progression_state["completed_milestone_ids"].has("ms_reputation_70"))
	s.reputation = 70
	t.eq(_ids(ProgressionService.evaluate(s)), ["ms_reputation_70"])
	s.visit_stats["entered"] = 10
	t.eq(_ids(ProgressionService.evaluate(s)), ["ms_ten_visitors"])
	for d in 7:
		s.close_day_once(d)
	var after := _ids(ProgressionService.evaluate(s))
	t.ok(after.has("ms_first_week"), "seven closed days")
	t.ok(after.has("ms_fifty_visitors") == false)
	# first profit needs a CLOSED day with positive operating profit
	var p := _state()
	_sale(p, 3)
	ProgressionService.evaluate(p)
	t.ok(not p.progression_state["completed_milestone_ids"].has("ms_first_profit"), "an open day is not a profit day yet")
	p.close_day_once(0)
	ProgressionService.evaluate(p)
	t.ok(p.progression_state["completed_milestone_ids"].has("ms_first_profit"), "closed with 150 profit")
	var loss := _state()
	loss.ledger.record("DAILY_FIXED", "0:DAILY_FIXED", -1000, 0, 0, {}, {"expense": 1000})
	loss.close_day_once(0)
	ProgressionService.evaluate(loss)
	t.ok(not loss.progression_state["completed_milestone_ids"].has("ms_first_profit"), "a loss day does not count")


func test_the_daily_challenge_rotates_by_day_number(t, _tree) -> void:
	t.eq(ProgressionService.challenge_for_day(0), "", "DAY0 belongs to the tutorial")
	t.eq(ProgressionService.challenge_for_day(1), "challenge_sales_3")
	t.eq(ProgressionService.challenge_for_day(2), "challenge_stock_2")
	t.eq(ProgressionService.challenge_for_day(3), "challenge_no_waste")
	t.eq(ProgressionService.challenge_for_day(4), "challenge_sales_3")
	t.eq(ProgressionService.challenge_for_day(300), "challenge_no_waste")
	var s := _state()
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["active_daily_challenge_id"], null, "no challenge on day 0")
	t.eq(s.progression_state["active_daily_challenge_day"], -1)
	s.day = 1
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["active_daily_challenge_id"], "challenge_sales_3")
	t.eq(s.progression_state["active_daily_challenge_day"], 1)
	s.reputation = 99   # anything that changes during the day must not re-draw it
	s.progression_state["active_daily_challenge_id"] = "challenge_sales_3"
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["active_daily_challenge_id"], "challenge_sales_3", "fixed for the day")


func test_sales_challenge_counts_todays_unique_sales(t, _tree) -> void:
	var s := _state()
	s.day = 1
	_sale(s, 2)
	t.eq(_ids(ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "CHALLENGE")), [])
	s.day = 0
	_sale(s, 5)   # yesterday's sales do not help
	s.day = 1
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["completed_daily_challenge_ids"], [])
	_sale(s, 1)
	var done := ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "CHALLENGE")
	t.eq(_ids(done), ["daily:1:challenge:challenge_sales_3"])
	_sale(s, 4)
	t.eq(ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "CHALLENGE").size(), 0, "completed once")


func test_stock_challenge_needs_two_categories_while_open(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf_a: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	var shelf_b: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_bread", "x": 4, "y": 8, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	for spec in [["rice_001", shelf_a], ["bread_001", shelf_b]]:
		_run(cmds, &"ORDER_STOCK", {"sku_id": spec[0], "qty": 5})
		_run(cmds, &"RESTOCK", {"instance_id": spec[1], "slot_id": "row0", "sku_id": spec[0], "qty": 5})
	s.day = 2
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["active_daily_challenge_id"], "challenge_stock_2")
	t.ok(not s.progression_state["challenge_stock_qualified"], "stocked in SETUP: the store was not open yet")
	t.eq(s.progression_state["completed_daily_challenge_ids"], [])
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	var events := ProgressionService.evaluate(s)
	t.ok(s.progression_state["challenge_stock_qualified"])
	t.ok(_ids(events).has("daily:2:challenge:challenge_stock_2"))


func test_no_waste_challenge_settles_when_the_day_closes(t, _tree) -> void:
	var s := _state()
	s.day = 3
	ProgressionService.evaluate(s)
	t.eq(s.progression_state["active_daily_challenge_id"], "challenge_no_waste")
	_sale(s, 2)
	s.visit_stats["purchased"] = 2
	t.eq(ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "CHALLENGE").size(), 0, "not before the day ends")
	s.close_day_once(3)
	s.day = 4
	var events := ProgressionService.evaluate(s)
	t.ok(_ids(events).has("daily:3:challenge:challenge_no_waste"))
	t.eq(s.progression_state["active_daily_challenge_id"], "challenge_sales_3", "day 4 draws the next one")
	# with waste, or with nobody buying, it fails and nothing is announced
	var w := _state()
	w.day = 3
	ProgressionService.evaluate(w)
	_sale(w, 1)
	w.ledger.record("WASTAGE", "wastage:x", 0, 3, 0, {}, {"expense": 100})
	w.visit_stats["purchased"] = 1
	w.close_day_once(3)
	w.day = 4
	t.ok(not _ids(ProgressionService.evaluate(w)).has("daily:3:challenge:challenge_no_waste"))
	var n := _state()
	n.day = 3
	ProgressionService.evaluate(n)
	n.close_day_once(3)
	n.day = 4
	t.ok(not _ids(ProgressionService.evaluate(n)).has("daily:3:challenge:challenge_no_waste"), "no customer, no credit")


func test_skip_show_and_save_load_keep_progress_and_never_reannounce(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_sale(s, 11)
	s.day = 1
	ProgressionService.evaluate(s)
	t.ok(_run(cmds, &"SET_TUTORIAL_SKIPPED", {"skipped": true}).ok)
	t.eq(s.progression_state["tutorial_skipped"], true)
	t.eq(_run(cmds, &"SET_TUTORIAL_SKIPPED", {"skipped": "yes"}).message_key, &"command_malformed")
	var step := _step(s)
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.to_dict(s, "s", "t")))
	var loaded := SaveGame.from_dict(data, balance, s.fixtures, s.products)
	t.ok(loaded["ok"], str(loaded["errors"]))
	var l: GameState = loaded["state"]
	l.milestones = s.milestones
	t.eq(l.progression_state, s.progression_state, "everything survives the save")
	t.eq(ProgressionService.evaluate(l).size(), 0, "a load announces nothing again")
	t.ok(_run(GameCommands.new(l), &"SET_TUTORIAL_SKIPPED", {"skipped": false}).ok)
	t.eq(_step(l), step, "showing the tutorial again keeps its progress")


## #32 本日のミッション: today's challenge with its progress, read without changing anything.
func test_challenge_progress_for_the_mission_list(t, _tree) -> void:
	var s := _state()
	ProgressionService.evaluate(s)
	t.eq(ProgressionService.challenge_progress(s), {}, "day 0 has no challenge")
	s.day = 1
	ProgressionService.evaluate(s)
	_sale(s, 2)
	ProgressionService.evaluate(s)   # the day's sales are counted from the ledger when progress is evaluated
	var before: Dictionary = s.progression_state.duplicate(true)
	t.eq(ProgressionService.challenge_progress(s), {"challenge_id": "challenge_sales_3", "value": 2, "goal": 3, "done": false})
	t.eq(s.progression_state, before, "reading the progress changes nothing")
	_sale(s, 4)
	ProgressionService.evaluate(s)
	t.eq(ProgressionService.challenge_progress(s), {"challenge_id": "challenge_sales_3", "value": 3, "goal": 3, "done": true}, "capped at the goal once done")


## The rows: the challenge first, then the three unfinished titles closest to done (ties keep the data order).
func test_mission_rows(t, _tree) -> void:
	var progress := [
		{"milestone_id": "a", "name_ja": "A", "metric": "total_sales_count", "threshold": 10, "value": 10, "done": true},
		{"milestone_id": "b", "name_ja": "B", "metric": "total_sales_count", "threshold": 10, "value": 2, "done": false},
		{"milestone_id": "c", "name_ja": "C", "metric": "day_closed_count", "threshold": 7, "value": 6, "done": false},
		{"milestone_id": "d", "name_ja": "D", "metric": "total_sales_count", "threshold": 100, "value": 0, "done": false},
		{"milestone_id": "e", "name_ja": "E", "metric": "total_sales_count", "threshold": 50, "value": 0, "done": false},
	]
	var rows := ProgressionText.mission_rows({"challenge_id": "challenge_no_waste", "value": 1, "goal": 1, "done": false}, progress)
	t.eq(rows.size(), 4)
	t.eq(rows[0]["caption"], "今日のチャレンジ")
	t.ok(rows[0]["goal"].begins_with("廃棄ゼロ") and rows[0]["goal"].ends_with("（閉店時に判定）"), rows[0]["goal"])
	t.eq(rows.slice(1).map(func(r): return r["caption"]), ["称号「C」", "称号「B」", "称号「D」"], "nearest first, finished titles left out")
	t.eq(rows[1]["goal"], "7 日間の営業を続けよう")
	t.eq(ProgressionText.mission_rows({}, []).size(), 0)
