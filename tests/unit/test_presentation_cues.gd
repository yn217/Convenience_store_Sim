extends RefCounted
## Issue #30 (Domain / Application side): EventEnvelope stream and the PresentationEventBridge.

const LegacyPace := preload("res://tests/support/legacy_pace.gd")

const Seeds := preload("res://tests/support/test_seeds.gd")
var _n := 0


func _cues() -> Array[Dictionary]:
	var problems: Array[String] = []
	var cues := PresentationEventBridge.load_cues(JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/cues_v1.json")), problems)
	assert(problems.is_empty(), str(problems))
	return cues


func _bridge() -> PresentationEventBridge:
	var b := PresentationEventBridge.new()
	b.setup(_cues())
	return b


func _ev(id: String, type: String, payload: Dictionary = {}, tick: int = 0) -> Dictionary:
	return {"id": id, "tick": tick, "type": type, "payload": payload}


func test_fifteen_cues_load_and_validate(t, _tree) -> void:
	var problems: Array[String] = []
	var cues := PresentationEventBridge.load_cues(JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/cues_v1.json")), problems)
	t.eq(problems, [] as Array[String])
	t.eq(cues.size(), 20, "15 + rival_opened, rival_sale, condition_started, rival_renovation, rival_closed (#129)")
	var bad: Array = [{"schema_version": 1, "cue_id": "x", "source_event_type": "A", "animation_id": "a", "duration_seconds": 9, "priority": "loud", "sfx_key": null, "dedupe_payload_field": "id", "cooldown_game_seconds": 0}]
	var errs: Array[String] = []
	PresentationEventBridge.load_cues(bad, errs)
	t.ok(errs.size() >= 2, "out-of-range duration and unknown priority are both reported: %s" % str(errs))
	var dup := [cues[0], cues[0]]
	var derrs: Array[String] = []
	PresentationEventBridge.load_cues(dup, derrs)
	t.ok(derrs.size() > 0, "duplicate ids rejected")


func test_event_becomes_one_cue_and_never_twice(t, _tree) -> void:
	var b := _bridge()
	var e := _ev("ev_000001", "SALE_COMMITTED", {"transaction_id": "sale:r1", "revenue_yen": 150, "register_id": "fx_0002"})
	var first := b.map([e], 10)
	t.eq(first.size(), 1)
	t.eq(first[0]["cue_id"], "checkout_success")
	t.eq(first[0]["source_event_id"], "ev_000001")
	t.eq(first[0]["sfx_key"], "register_beep")
	t.eq(b.map([e], 10).size(), 0, "the same EventEnvelope id never plays twice")
	t.eq(b.map([_ev("ev_000002", "SOMETHING_ELSE")], 10).size(), 0, "events without a cue are ignored")
	b.reset()
	t.eq(b.map([e], 10).size(), 1, "after reset (a loaded game) ids are new again")


func test_cooldown_per_payload_value(t, _tree) -> void:
	var b := _bridge()
	t.eq(b.map([_ev("a", "STOCK_LOW", {"fixture_id": "fx_1"})], 100).size(), 1)
	t.eq(b.map([_ev("b", "STOCK_LOW", {"fixture_id": "fx_1"})], 110).size(), 0, "same shelf inside 30 game seconds")
	t.eq(b.map([_ev("c", "STOCK_LOW", {"fixture_id": "fx_2"})], 110).size(), 1, "another shelf is separate")
	t.eq(b.map([_ev("d", "STOCK_LOW", {"fixture_id": "fx_1"})], 131).size(), 1, "after the cooldown")


func test_event_id_memory_is_bounded(t, _tree) -> void:
	var b := _bridge()
	for i in PresentationEventBridge.SEEN_CAP + 100:
		b.map([_ev("e%d" % i, "UI_COMMAND_SUCCEEDED", {"command_id": "c%d" % i})], 0)
	t.ok(b._seen.size() <= PresentationEventBridge.SEEN_CAP)


# ---------------------------------------------------------------- Domain events

func _state() -> GameState:
	var balance = LegacyPace.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json")))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary) -> CommandResult:
	_n += 1
	var c := {"command_id": "p%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


func _open_store(s: GameState) -> void:
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 24})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 12})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row1", "sku_id": "rice_001", "qty": 12})
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	s.balance["base_potential_visitors_per_day"] = 3000


func _simulate(s: GameState, steps: int, consume: bool, log: Array) -> void:
	var runner := SimulationRunner.new(s)
	for i in steps:
		runner._run_step()
		if consume:
			log.append_array(s.take_events())


func test_a_sale_is_announced_only_after_it_is_booked(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	var seen: Array = []
	_simulate(s, 6000, true, seen)
	var types := {}
	for e in seen:
		types[e["type"]] = int(types.get(e["type"], 0)) + 1
	t.ok(types.get("CUSTOMER_ENTERED", 0) > 0 and types.get("CUSTOMER_RESERVED_ITEM", 0) > 0 and types.get("SALE_COMMITTED", 0) > 0, "the visit is told as events: %s" % str(types))
	var ids := {}
	for e in seen:
		t.ok(not ids.has(e["id"]), "event ids are unique")
		ids[e["id"]] = true
		if e["type"] == "SALE_COMMITTED":
			t.ok(s.ledger.has_event(e["payload"]["transaction_id"]), "SALE_COMMITTED comes with a ledger row")
			t.ok(int(e["payload"]["revenue_yen"]) > 0)
	t.eq(types.get("SALE_COMMITTED", 0), s.visit_stats["purchased"] + int(s.daily_reports.reduce(func(a, r): return a + int(r["purchasing_customers"]), 0)), "one event per completed sale")
	# A customer is entered before it reserves, and reserves before the sale.
	var order := {}
	for i in seen.size():
		var cid = seen[i]["payload"].get("customer_id")
		if cid != null:
			if seen[i]["type"] == "CUSTOMER_ENTERED":
				order[cid] = i
			elif seen[i]["type"] == "SALE_COMMITTED":
				t.ok(order.has(cid) and order[cid] < i, "enter before sale")


func test_consuming_events_changes_nothing_in_the_economy(t, _tree) -> void:
	var a := _state()
	var b := _state()
	_open_store(a)
	_open_store(b)
	var log_a: Array = []
	var log_b: Array = []
	_simulate(a, 5000, true, log_a)
	_simulate(b, 5000, false, log_b)   # nobody listens: only the capped log grows
	t.eq(a.cash_yen, b.cash_yen)
	t.eq(a.ledger.transactions.size(), b.ledger.transactions.size())
	t.eq(a.rng_states, b.rng_states)
	t.eq(a.visit_stats, b.visit_stats)
	t.ok(b.event_log.size() <= GameState.EVENT_LOG_CAP, "an unread log is capped")


func test_events_are_not_saved_and_do_not_replay_after_load(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	var log: Array = []
	_simulate(s, 2000, false, log)
	t.ok(s.event_log.size() > 0)
	var data := SaveGame.to_dict(s, "slot", "2026-01-01T00:00:00Z")
	t.ok(not JSON.stringify(data).contains("ev_0000"), "no envelope in the save file")
	var balance = LegacyPace.apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json")))
	var loaded := SaveGame.from_dict(data, balance, s.fixtures, s.products)
	t.ok(loaded["ok"])
	t.eq(loaded["state"].take_events().size(), 0, "a loaded game starts with a silent log")


func test_stock_and_queue_and_day_events(t, _tree) -> void:
	var s := _state()
	_open_store(s)
	var seen: Array = []
	_simulate(s, 30000, true, seen)
	var types := {}
	for e in seen:
		types[e["type"]] = true
	t.ok(types.has("STOCK_LOW"), "the shelf ran low: %s" % str(types.keys()))
	t.ok(types.has("DAILY_CLOSED") or s.day == 0, "closing a day is announced")
	for e in seen:
		if e["type"] == "STOCK_LOW":
			t.ok(e["payload"].has("fixture_id"))
