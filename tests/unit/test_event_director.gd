extends RefCounted
## Issue #31: daily gameplay events (13, 16): draw, effects, notices, save / load, data contract.

const Seeds := preload("res://tests/support/test_seeds.gd")
const DAY := 86400
var _n := 0


func _events() -> Array[Dictionary]:
	var problems: Array[String] = []
	var list := GameplayEventDirector.load_events(JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json")), problems)
	assert(problems.is_empty(), str(problems))
	return list


func _state(with_events: bool = true) -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	if with_events:
		s.gameplay_events = _events()
	return s


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "ev%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## Open store with stock so that the whole sim path is live.
func _open_store(s: GameState) -> void:
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 12})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 12})
	s.business_state = GameState.OPEN
	s.speed_setting = 1


# ---------------------------------------------------------------- data contract

func test_twelve_seed_events_load_and_are_sane(t, _tree) -> void:
	var events := _events()
	t.eq(events.size(), 15, "the 12 seed events and the 3 choice events of 2026-11-13")
	var ids := {}
	for e in events:
		t.ok(not ids.has(e["event_id"]), "unique id")
		ids[e["event_id"]] = true
		t.ok(e["window_start_hour"] < e["window_end_hour"])
		t.ok(e["effects"]["traffic_multiplier"] >= 0.7 and e["effects"]["traffic_multiplier"] <= 1.4)
		for c in e["effects"]["category_weight_multipliers"]:
			t.ok(GameplayEventDirector.CATEGORIES.has(c))
			t.ok(e["effects"]["category_weight_multipliers"][c] >= 1.0 and e["effects"]["category_weight_multipliers"][c] <= 1.8)
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var cats := {}
	for sku in products.skus.values():
		cats[sku["category"]] = true
	for e in events:
		for c in e["effects"]["category_weight_multipliers"]:
			t.ok(cats.has(c), "%s names a category that exists" % e["event_id"])


func test_bad_event_data_is_rejected(t, _tree) -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json"))[0] if false else JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json"))[0]
	var cases := {
		"traffic": func(e): e["effects"]["traffic_multiplier"] = 2.0,
		"window": func(e): e["window_start_hour"] = 20; e["window_end_hour"] = 20,
		"category": func(e): e["effects"]["category_weight_multipliers"] = {"sushi": 1.2},
		"cat_range": func(e): e["effects"]["category_weight_multipliers"] = {"drink": 2.5},
		"weight": func(e): e["weight"] = 0,
		"day0": func(e): e["min_day_index"] = 0,
		"extra": func(e): e["surprise"] = 1,
		"id": func(e): e["event_id"] = "local_fair",
	}
	for name in cases:
		var e: Dictionary = good.duplicate(true)
		cases[name].call(e)
		var errs: Array[String] = []
		t.eq(GameplayEventDirector.load_events([e], errs).size(), 0, name)
		t.ok(errs.size() > 0, "%s reported" % name)
	var dup: Array[String] = []
	GameplayEventDirector.load_events([good, good], dup)
	t.ok(dup.size() > 0, "duplicate ids")


func test_independent_event_seed(t, _tree) -> void:
	var s := _state()
	t.eq(s.rng_states["events"], 345678)
	t.eq(s.rng_states["arrivals"], Seeds.ARRIVALS)
	t.ok(s.rng_states["events"] != s.rng_states["arrivals"] and s.rng_states["events"] != s.rng_states["purchases"] and s.rng_states["events"] != s.rng_states["visuals"])


# ---------------------------------------------------------------- the daily draw

func test_golden_day1_roll(t, _tree) -> void:
	var events := _events()
	var r := GameplayEventDirector.draw(events, 1, 50, 345678)
	t.eq(r["event_id"], "evt_after_work", "event seed 345678, reputation 50, DAY 1")
	t.eq(r["next_state"], 877959509)
	t.eq(r["roll"], 6)
	t.eq(r["total"], 11 * 7 + 30, "evt_neighbor_mentions needs reputation 60")
	t.eq(GameplayEventDirector.candidates(events, 1, 50).size(), 11)
	t.eq(GameplayEventDirector.candidates(events, 1, 60).size(), 12)
	t.eq(GameplayEventDirector.candidates(events, 1, 50)[0]["event_id"], "evt_after_work", "ordered by id")
	# One RNG step even without candidates, and the last slot is "none".
	var none := GameplayEventDirector.draw([], 1, 50, 345678)
	t.eq(none["event_id"], "")
	t.eq(none["next_state"], 877959509)
	var last := GameplayEventDirector.draw(events, 1, 50, 0)
	t.ok(last["roll"] < last["total"])


func test_day0_never_draws(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	var runner := SimulationRunner.new(s)
	for i in 3000:
		runner._run_step()
	t.eq(s.time_sec / DAY, 0)
	t.eq(s.gameplay_event_state["last_selected_day"], -1, "DAY 0 is for the tutorial")
	t.eq(s.rng_states["events"], 345678, "no event number consumed")
	t.eq(s.gameplay_event_state["selected_event_id"], null)


func test_day1_draws_once_and_not_again_after_close_open(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	s.time_sec = DAY + 3600
	s.day = 1
	var runner := SimulationRunner.new(s)
	runner._run_step()
	var ges := s.gameplay_event_state
	t.eq(ges["last_selected_day"], 1)
	t.eq(ges["selection_event_id"], "daily:1")
	var after_state: int = s.rng_states["events"]
	t.ok(after_state != 345678, "the event stream advanced exactly once")
	var chosen = ges["selected_event_id"]
	# CLOSE -> OPEN on the same day: no new draw.
	s.business_state = GameState.SETUP
	EventService.step(s)
	s.business_state = GameState.OPEN
	for i in 50:
		runner._run_step()
	t.eq(s.rng_states["events"], after_state, "same day: no redraw")
	t.eq(ges["selected_event_id"], chosen)
	# The next day draws again.
	s.time_sec = 2 * DAY + 3600
	runner._run_step()
	t.eq(ges["last_selected_day"], 2)
	t.ok(s.rng_states["events"] != after_state)


func test_no_draw_while_setup_or_closing(t, _tree) -> void:
	var s := _state()
	s.time_sec = DAY + 100
	for st in [GameState.SETUP, GameState.CLOSING, GameState.PAYMENT_BLOCKED]:
		s.business_state = st
		EventService.step(s)
		t.eq(s.gameplay_event_state["last_selected_day"], -1, "no draw in state %s" % str(st))
	t.eq(s.rng_states["events"], 345678)


func test_events_off_without_master_data(t, _tree) -> void:
	var s := _state(false)
	s.business_state = GameState.OPEN
	s.time_sec = DAY + 10
	EventService.step(s)
	t.eq(s.gameplay_event_state["last_selected_day"], -1)
	t.eq(EventService.view(s)["status"], "no_data")


# ---------------------------------------------------------------- effects

func _force(s: GameState, event_id: String, day: int, started: bool = true) -> void:
	var ev := GameplayEventDirector.event_by_id(s.gameplay_events, event_id)
	var w := GameplayEventDirector.window(day, ev)
	s.gameplay_event_state.merge({"last_selected_day": day, "selection_event_id": "daily:%d" % day, "selected_event_id": event_id, "event_start_sec": w.x, "event_end_sec": w.y, "started": started, "ended": false}, true)


func test_traffic_multiplier_is_applied_once_and_only_in_the_window(t, _tree) -> void:
	var s := _state()
	_force(s, "evt_local_fair", 1)   # 17-22h, traffic 1.35
	var inside := 1 * DAY + 18 * 3600
	t.eq(GameplayEventDirector.effects_at(s.gameplay_events, s.gameplay_event_state, inside)["traffic"], 1.35)
	t.eq(GameplayEventDirector.effects_at(s.gameplay_events, s.gameplay_event_state, 1 * DAY + 16 * 3600)["traffic"], 1.0, "before")
	t.eq(GameplayEventDirector.effects_at(s.gameplay_events, s.gameplay_event_state, 1 * DAY + 22 * 3600)["traffic"], 1.0, "the end is exclusive")
	var base := DemandModel.step_probability(18, 100.0, 1.2, 50, 3, s.balance)
	var with := DemandModel.step_probability(18, 100.0, 1.2, 50, 3, s.balance, 1.35)
	t.ok(absf(with / base - 1.35) < 1e-9, "one multiplication on top of ad / reputation / assortment / hour")
	# The generator uses exactly that probability: replay the same roll by hand.
	s.business_state = GameState.OPEN
	s.time_sec = inside
	s.balance["base_potential_visitors_per_day"] = 100
	var expect := DemandModel.step_probability(DemandModel.hour_of_day(inside), 100.0, DemandModel.ad_multiplier(s.balance.get("advertising_tiers", []), s.applied_ad_tier_yen), s.reputation, DemandGenerator.stocked_category_count(s), s.balance, 1.35)
	var roll := Lcg32.new(int(s.rng_states["arrivals"])).uniform_0_1()
	var drawn := DemandGenerator.step(s)
	t.eq(drawn, roll < expect, "DemandGenerator uses the event probability once")


func test_category_weights_multiply_only_the_matching_category(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	_run(GameCommands.new(s), &"PLACE_FIXTURE", {"type_id": "fridge_drink", "x": 4, "y": 8, "rotation": 0})
	var fridge := ""
	for id in s.grid.instances:
		if s.grid.instances[id]["type_id"] == "fridge_drink":
			fridge = id
	_run(GameCommands.new(s), &"ORDER_STOCK", {"sku_id": "drink_001", "qty": 6})
	_run(GameCommands.new(s), &"RESTOCK", {"instance_id": fridge, "slot_id": "row0", "sku_id": "drink_001", "qty": 6})
	var ai := CustomerAI.new()
	var before := ai.candidates(s)
	_force(s, "evt_hot_day", 0)   # drink x1.6, ice_cream x1.6
	s.time_sec = 12 * 3600
	var after := ai.candidates(s)
	t.eq(before.size(), after.size())
	for i in before.size():
		var cat: String = s.products.get_sku(before[i]["sku_id"])["category"]
		var ratio: float = after[i]["weight"] / before[i]["weight"]
		t.ok(absf(ratio - (1.6 if cat == "drink" else 1.0)) < 1e-9, "%s x%.2f" % [cat, ratio])
	s.time_sec = 20 * 3600   # window 11-17h is over
	var late := ai.candidates(s)
	for i in before.size():
		t.ok(absf(late[i]["weight"] - before[i]["weight"]) < 1e-9, "outside the window the weights are untouched")


func test_nothing_arrives_in_setup_or_closing_even_with_an_event(t, _tree) -> void:
	var s := _state()
	_force(s, "evt_local_fair", 1)
	s.time_sec = DAY + 18 * 3600
	s.balance["base_potential_visitors_per_day"] = 100000
	var seed_before: int = s.rng_states["arrivals"]
	for st in [GameState.SETUP, GameState.CLOSING]:
		s.business_state = st
		for i in 100:
			DemandGenerator.step(s)
	t.eq(s.visit_stats["potential"], 0)
	t.eq(s.rng_states["arrivals"], seed_before, "no draw, no RNG use")


# ---------------------------------------------------------------- notices, window, save

func test_started_and_ended_notices_once_with_stable_ids(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	s.time_sec = DAY + 5 * 3600
	s.day = 1
	s.rng_states["events"] = 345678   # DAY 1 -> evt_after_work (18-23h)
	var runner := SimulationRunner.new(s)
	var seen: Array = []
	var guard := 0
	while s.time_sec < DAY + 23 * 3600 + 120 and guard < 40000:
		runner._run_step()
		seen.append_array(s.take_events())
		guard += 1
		s.business_state = GameState.OPEN   # keep the shop open for the whole window
	var started := seen.filter(func(e): return e["type"] == "EVENT_STARTED")
	var ended := seen.filter(func(e): return e["type"] == "EVENT_ENDED")
	t.eq(started.size(), 1)
	t.eq(ended.size(), 1)
	t.eq(started[0]["id"], "daily:1:evt_after_work:started")
	t.eq(ended[0]["id"], "daily:1:evt_after_work:ended")
	t.ok(started[0]["tick"] >= DAY + 18 * 3600 and started[0]["tick"] < DAY + 18 * 3600 + 10)
	t.eq(started[0]["payload"]["window"], "18:00-23:00")
	t.eq(s.gameplay_event_state["shown_notice_ids"], ["daily:1:evt_after_work:started", "daily:1:evt_after_work:ended"])
	t.eq(EventService.view(s)["status"], "ended")
	t.eq(EventService.effects(s)["traffic"], 1.0, "back to neutral after the end")


func test_opening_after_the_window_is_recorded_and_not_redrawn(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	s.time_sec = DAY + 23 * 3600 + 600   # evt_after_work ended at 23:00
	s.day = 1
	EventService.step(s)
	var ges := s.gameplay_event_state
	t.eq(ges["selected_event_id"], "evt_after_work")
	t.eq(ges["started"], false)
	t.eq(ges["ended"], true, "missed")
	t.eq(EventService.view(s)["status"], "missed")
	t.eq(s.take_events().size(), 0, "a missed event raises no notice")
	var st: int = s.rng_states["events"]
	EventService.step(s)
	t.eq(s.rng_states["events"], st, "no redraw")


func test_save_load_keeps_selection_rng_and_does_not_replay(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	s.time_sec = DAY + 17 * 3600 + 3000   # shortly before the event starts (18h)
	s.day = 1
	EventService.step(s)
	t.eq(s.gameplay_event_state["selected_event_id"], "evt_after_work")
	var data := SaveGame.to_dict(s, "slot", "2026-01-01T00:00:00Z")
	t.eq(data["rng_states"]["events"], s.rng_states["events"])
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var loaded := SaveGame.from_dict(data, balance, s.fixtures, s.products)
	t.ok(loaded["ok"], str(loaded.get("errors", "")))
	var l: GameState = loaded["state"]
	l.gameplay_events = s.gameplay_events
	t.eq(l.gameplay_event_state, s.gameplay_event_state)
	t.eq(l.rng_states["events"], s.rng_states["events"])
	l.business_state = GameState.OPEN
	EventService.step(l)
	t.eq(l.rng_states["events"], s.rng_states["events"], "load does not redraw the day")
	# Save in the middle of the event: started stays started, no second EVENT_STARTED.
	l.time_sec = DAY + 18 * 3600 + 10
	EventService.step(l)
	t.eq(l.take_events().filter(func(e): return e["type"] == "EVENT_STARTED").size(), 1)
	var mid := SaveGame.to_dict(l, "slot", "2026-01-01T00:00:00Z")
	var l2: GameState = SaveGame.from_dict(mid, balance, s.fixtures, s.products)["state"]
	l2.gameplay_events = s.gameplay_events
	l2.business_state = GameState.OPEN
	l2.time_sec = l.time_sec + 20
	EventService.step(l2)
	t.eq(l2.take_events().size(), 0, "no replay of EVENT_STARTED after a load")
	t.eq(EventService.effects(l2)["traffic"], 1.2, "and the effect carries on")


func test_the_event_stream_does_not_disturb_other_randomness(t, _tree) -> void:
	var a := _state()
	var b := _state(false)
	_open_store(a)
	_open_store(b)
	a.balance["base_potential_visitors_per_day"] = 800
	b.balance["base_potential_visitors_per_day"] = 800
	var ra := SimulationRunner.new(a)
	var rb := SimulationRunner.new(b)
	for i in 3000:   # DAY 0 only: events never fire, so the runs are identical
		ra._run_step()
		rb._run_step()
	t.eq(a.rng_states["arrivals"], b.rng_states["arrivals"])
	t.eq(a.rng_states["purchases"], b.rng_states["purchases"])
	t.eq(a.cash_yen, b.cash_yen)


## #31 イベント履歴: each drawn day is remembered once when the next day's draw replaces it, survives a save, and old
## saves without it still load.
func test_event_history_is_kept_and_saved(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	for d in [1, 2, 3]:
		s.time_sec = d * DAY + 23 * 3600   # late in the day: the window is over, a drawn event counts as missed
		EventService.step(s)
	EventService.step(s)   # same day again: nothing new
	t.eq(s.event_history.map(func(h): return h["day"]), [1, 2], "days 1 and 2 are remembered when day 2 and 3 are drawn")
	t.ok(s.event_history.all(func(h): return h["held"] == false), "the store opened after every window")
	var hist := EventService.history(s)
	t.eq(hist[0]["day"], 2, "newest first")
	var saved := SaveGame.to_dict(s, "slot", "2026-01-01T00:00:00Z")
	var loaded := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(loaded["ok"], str(loaded.get("errors", [])))
	t.eq((loaded["state"] as GameState).event_history, s.event_history, "the history survives a save")
	saved["runtime_state"].erase("event_history")
	var old := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(old["ok"] and (old["state"] as GameState).event_history.is_empty(), "an older save loads with no history")
	saved["runtime_state"]["event_history"] = [{"day": "x"}]
	t.ok(not SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)["ok"], "a broken history is refused")


func test_event_history_text(t, _tree) -> void:
	var text := EventController.history_text([{"day": 3, "name_ja": "近隣の工事", "held": true}, {"day": 2, "name_ja": "暑い日", "held": false}, {"day": 1, "name_ja": "", "held": false}])
	t.eq(text.split("\n"), PackedStringArray(["DAY 3　近隣の工事（開催）", "DAY 2　暑い日（見送り）", "DAY 1　イベントなし"]))
