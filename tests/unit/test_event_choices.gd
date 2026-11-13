extends RefCounted
## Event choices (user's decision 2026-11-13): the player picks one choice of today's event; a paid one is booked as a
## PROMO expense and its effects replace the event's; with no pick the free choice holds; the pick survives a save.

const Seeds := preload("res://tests/support/test_seeds.gd")
const DAY := 86400
var _n := 0


func _events() -> Array[Dictionary]:
	var problems: Array[String] = []
	var list := GameplayEventDirector.load_events(JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json")), problems)
	assert(problems.is_empty(), str(problems))
	return list


func _balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))


## DAY 1 shortly before 18:00 with the seed's event drawn (evt_after_work, which has choices).
func _state() -> GameState:
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(_balance(), Seeds.SEEDS, fx, pr)
	s.gameplay_events = _events()
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.time_sec = DAY + 17 * 3600 + 3000
	s.day = 1
	EventService.step(s)
	return s


func _choose(s: GameState, choice_id: String) -> CommandResult:
	_n += 1
	return GameCommands.new(s).execute({"command_id": "pick%d" % _n, "kind": &"CHOOSE_EVENT_OPTION", "choice_id": choice_id})


func test_nine_events_offer_a_free_and_a_paid_choice(t, _tree) -> void:
	var with_choices := _events().filter(func(e): return e.has("choices"))
	t.eq(with_choices.size(), 9, "nine events ask the player")
	for e in with_choices:
		var free: Array = (e["choices"] as Array).filter(func(c): return int(c["cost_yen"]) == 0)
		t.eq(free.size(), 1, "%s has exactly one free choice" % e["event_id"])
		t.eq(free[0]["effects"], e["effects"], "%s: not choosing keeps the event as it was" % e["event_id"])
		t.ok(ResourceLoader.exists("res://assets/runtime/event_choices/%s.png" % e["event_id"]), "%s has its picture" % e["event_id"])


func test_bad_choices_are_rejected(t, _tree) -> void:
	var e: Dictionary = (_events().filter(func(x): return x.has("choices"))[0] as Dictionary).duplicate(true)
	var two_free: Dictionary = e.duplicate(true)
	for c in two_free["choices"]:
		c["cost_yen"] = 0
	var problems: Array[String] = []
	t.eq(GameplayEventDirector.load_events([two_free], problems).size(), 0, "two free choices are refused")
	t.ok(problems.any(func(p): return p.contains("exactly one free choice")), str(problems))
	var too_strong: Dictionary = e.duplicate(true)
	too_strong["choices"][0]["effects"]["traffic_multiplier"] = 2.5
	problems.clear()
	t.eq(GameplayEventDirector.load_events([too_strong], problems).size(), 0, "a choice beyond the range is refused")
	var one: Dictionary = e.duplicate(true)
	one["choices"] = [one["choices"][0]]
	problems.clear()
	t.eq(GameplayEventDirector.load_events([one], problems).size(), 0, "a single choice is no choice")


func test_a_paid_choice_costs_its_price_and_changes_the_effect(t, _tree) -> void:
	var s := _state()
	t.eq(s.gameplay_event_state["selected_event_id"], "evt_after_work", "the seed's DAY 1 event")
	var v := EventService.view(s)
	t.eq(v["status"], "scheduled")
	t.eq(v["choice_id"], "", "not chosen yet")
	t.eq((v["choices"] as Array).size(), 2)
	s.time_sec = DAY + 18 * 3600 + 10
	EventService.step(s)
	t.eq(EventService.effects(s)["traffic"], 1.2, "without a pick the free choice holds")
	var cash := s.cash_yen
	var r := _choose(s, "deli")
	t.ok(r.ok, "chosen: %s" % r.message_key)
	t.eq(s.cash_yen, cash - 12000, "the paid choice costs 12,000 yen")
	var tx: Dictionary = s.ledger.transactions[-1]
	t.eq(tx["event_type"], "PROMO", "booked as a promotion expense")
	t.eq(int(tx["expense_delta_yen"]), 12000)
	t.eq(tx["details"]["choice_id"], "deli")
	var fx := EventService.effects(s)
	t.eq(fx["traffic"], 1.25, "its traffic")
	t.eq(GameplayEventDirector.category_multiplier(fx, "bento"), 1.6, "its categories")
	t.eq(EventService.view(s)["choice_id"], "deli")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	t.ok(not _choose(s, "normal").ok, "a pick is final for the day")
	t.eq(s.cash_yen, cash - 12000, "and the refusal costs nothing")


func test_a_choice_that_cannot_be_paid_changes_nothing(t, _tree) -> void:
	var s := _state()
	s.ledger.cash_yen = 5000
	var r := _choose(s, "deli")
	t.ok(not r.ok and r.code == &"INSUFFICIENT_CASH", "too little cash: %s" % r.code)
	t.eq(s.cash_yen, 5000, "no money moved")
	t.eq(s.gameplay_event_state["choice_id"], null, "nothing chosen")
	t.ok(_choose(s, "normal").ok, "the free choice is always possible")
	t.ok(not _choose(s, "unknown").ok, "an unknown choice is refused")


func test_no_choice_without_an_event_or_after_it(t, _tree) -> void:
	var s := _state()
	s.time_sec = DAY + 18 * 3600 + 10
	EventService.step(s)
	s.time_sec = DAY + 23 * 3600 + 10
	EventService.step(s)
	t.eq(EventService.view(s)["status"], "ended")
	t.ok(not _choose(s, "deli").ok, "an ended event cannot be chosen any more")
	s.gameplay_event_state["selected_event_id"] = null
	t.ok(not _choose(s, "deli").ok, "no event, no choice")


func test_the_pick_survives_a_save_and_a_new_day_resets_it(t, _tree) -> void:
	var s := _state()
	t.ok(_choose(s, "deli").ok)
	var data := SaveGame.to_dict(s, "slot", "2026-01-01T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), _balance(), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr.get("errors", "")))
	var l: GameState = lr["state"]
	l.gameplay_events = s.gameplay_events
	t.eq(l.gameplay_event_state["choice_id"], "deli", "the pick is saved")
	var old := data.duplicate(true)
	(old["gameplay_event_state"] as Dictionary).erase("choice_id")
	var lo := SaveGame.from_dict(JSON.parse_string(JSON.stringify(old)), _balance(), s.fixtures, s.products)
	t.ok(lo["ok"], "a save from before event choices still loads: %s" % str(lo.get("errors", "")))
	var o: GameState = lo["state"]
	o.gameplay_events = s.gameplay_events
	t.eq(EventService.view(o)["choice_id"], "", "and has no pick")
	l.business_state = GameState.OPEN
	l.time_sec = 2 * DAY + 60
	l.day = 2
	EventService.step(l)
	t.eq(l.gameplay_event_state["choice_id"], null, "the next day's event is chosen afresh")
