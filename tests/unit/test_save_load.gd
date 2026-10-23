extends RefCounted
## Issue #20: save -> load round trips, rejection of bad files, crash-safe file handling.

const Seeds := preload("res://tests/support/test_seeds.gd")
const TMP_DIR := "user://test_saves"
var _n := 0
var _balance: Dictionary
var _fx: FixtureCatalog
var _pr: ProductCatalog


func _init() -> void:
	_balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	_fx = FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	_pr = ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))


func _state() -> GameState:
	return GameState.from_balance(_balance, Seeds.SEEDS, _fx, _pr)


func _run(cmds: GameCommands, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	_n += 1
	var c := {"command_id": "s%d" % _n, "kind": kind}
	c.merge(payload)
	return cmds.execute(c)


## Busy mid-day store: fixtures, stock, price override, an ad, customers walking/queuing, sales made.
func _busy() -> GameState:
	var s := _state()
	var cmds := GameCommands.new(s)
	var shelf: String = _run(cmds, &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0}).data["instance_id"]
	_run(cmds, &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 30})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row0", "sku_id": "rice_001", "qty": 12})
	_run(cmds, &"RESTOCK", {"instance_id": shelf, "slot_id": "row1", "sku_id": "rice_001", "qty": 12})
	_run(cmds, &"SET_PRICE", {"sku_id": "rice_001", "price_yen": 160})
	_run(cmds, &"SET_NEXT_DAY_AD", {"tier_yen": 1000})
	_run(cmds, &"START_BUSINESS")
	s.time_sec = 11 * 3600
	s.balance["base_potential_visitors_per_day"] = 1500
	s.speed_setting = 4
	var runner := SimulationRunner.new(s)
	var steps := 0
	# Play until the store holds unsold stock, an open reservation and a customer in the queue.
	while steps < 20000:
		steps += runner.process_frame(1.0 / 15.0)
		if steps > 200 and not s.reservations.is_empty() and not s.customers.is_empty() and s.visit_stats["purchased"] >= 2:
			break
	return s


func _json_roundtrip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _load(d: Dictionary) -> Dictionary:
	return SaveGame.from_dict(_json_roundtrip(d), _balance, _fx, _pr)


func _norm(s: GameState) -> String:
	return JSON.stringify(SaveGame.to_dict(s, "x", "2026-01-01T00:00:00Z"), "", true)


func test_empty_sample_loads(t, _tree) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/empty_store.savegame.json"))
	var r := SaveGame.from_dict(data, _balance, _fx, _pr)
	t.ok(r["ok"], str(r["errors"]))
	var s: GameState = r["state"]
	t.eq(s.cash_yen, 500000)
	t.eq(s.business_state, GameState.SETUP)
	t.eq(s.rng_states["arrivals"], 1234)
	t.eq(s.grid.instances.size(), 0)


func test_deep_round_trip_of_a_busy_store(t, _tree) -> void:
	var s := _busy()
	t.ok(not s.customers.is_empty(), "the store has customers mid-walk")
	t.ok(not s.reservations.is_empty() and not s.inventory_segments.is_empty(), "with stock and a live reservation")
	t.ok(s.ledger.transactions.size() > 5)
	var saved := SaveGame.to_dict(s, "slot_1", "2026-10-23T12:00:00Z")
	var r := _load(saved)
	t.ok(r["ok"], str(r["errors"]))
	var l: GameState = r["state"]
	t.eq(_norm(l), _norm(s), "the reloaded state serialises exactly like the original")
	t.eq(l.snapshot()["fixtures"], s.snapshot()["fixtures"])
	t.eq(l.cash_yen, s.cash_yen)
	t.eq(l.rng_states, s.rng_states)
	t.eq(l.reservations, s.reservations)
	t.eq(l.inventory_segments, s.inventory_segments)
	t.eq(l.ledger.transactions, s.ledger.transactions)
	t.eq(l.ledger.applied_event_ids, s.ledger.applied_event_ids)
	t.eq(l.applied_command_ids, s.applied_command_ids)
	t.eq(l.product_price_overrides, {"rice_001": 160})
	t.eq([l.next_fixture_seq, l.next_lot_seq, l.next_segment_seq, l.next_customer_seq], [s.next_fixture_seq, s.next_lot_seq, s.next_segment_seq, s.next_customer_seq])
	t.eq(l.visit_stats, s.visit_stats)
	for i in s.customers.size():
		t.eq(l.customers[i]["customer_id"], s.customers[i]["customer_id"])
		t.eq(l.customers[i]["phase"], s.customers[i]["phase"], "phase %s" % s.customers[i]["customer_id"])
		t.eq(l.customers[i]["tile"], s.customers[i]["tile"])
		t.eq(l.customers[i]["path"], s.customers[i]["path"])


func test_playing_on_after_loading_matches_never_having_saved(t, _tree) -> void:
	var a := _busy()
	var r := _load(SaveGame.to_dict(a, "s", "t"))
	var b: GameState = r["state"]
	b.balance["base_potential_visitors_per_day"] = 1500
	var ra := SimulationRunner.new(a)
	var rb := SimulationRunner.new(b)
	var steps_a := 0
	var steps_b := 0
	while steps_a < 1500:
		steps_a += ra.process_frame(1.0 / 15.0)
	while steps_b < 1500:
		steps_b += rb.process_frame(1.0 / 15.0)
	t.eq(_norm(a), _norm(b), "same ticks after the load -> identical economy and customers")
	var sales_a := 0
	for tx in a.ledger.transactions:
		if tx["event_type"] == "SALE":
			sales_a += 1
	t.ok(sales_a > 0)


func test_command_ids_survive_a_load(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var c := {"command_id": "order_1", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 4}
	t.ok(cmds.execute(c).ok)
	var l: GameState = _load(SaveGame.to_dict(s, "s", "t"))["state"]
	var cmds2 := GameCommands.new(l)
	t.eq(cmds2.execute(c).code, &"ALREADY_APPLIED", "the same command id is not applied twice")
	t.eq(l.backroom_available("rice_001"), 4)
	t.eq(l.cash_yen, 500000 - 400)
	c["command_id"] = "order_2"
	t.ok(cmds2.execute(c).ok, "a new id orders again")
	t.eq(l.backroom_available("rice_001"), 8)


func test_no_double_charge_or_sale_after_loading(t, _tree) -> void:
	var s := _busy()
	var charges_before := 0
	for tx in s.ledger.transactions:
		if ["AD", "DAILY_FIXED", "ELECTRICITY"].has(tx["event_type"]):
			charges_before += 1
	var l: GameState = _load(SaveGame.to_dict(s, "s", "t"))["state"]
	t.eq(BusinessService.day_charged(l, 0), true)
	t.eq(BusinessService.charge_day(l, 0, false), 0, "booking day 0 again is a no-op")
	var charges_after := 0
	for tx in l.ledger.transactions:
		if ["AD", "DAILY_FIXED", "ELECTRICITY"].has(tx["event_type"]):
			charges_after += 1
	t.eq(charges_after, charges_before)
	for r in l.reservations:
		var sale := InventoryService.complete_sale(l, "sale:%s" % r["reservation_id"], r["reservation_id"])
		if not sale["ok"]:
			continue
		var again := InventoryService.complete_sale(l, "sale:%s" % r["reservation_id"], r["reservation_id"])
		t.ok(not again["ok"], "an already settled sale cannot be settled again")
		break


func test_expiry_after_loading_is_booked_once(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 5})
	var l: GameState = _load(SaveGame.to_dict(s, "s", "t"))["state"]
	l.time_sec = 86400
	t.eq(InventoryService.sweep_expired(l).size(), 1)
	var wasted := 0
	for tx in l.ledger.transactions:
		if tx["event_type"] == "WASTAGE":
			wasted += tx["expense_delta_yen"]
	t.eq(wasted, 500)
	# Saved after the discard and loaded again: the event id is remembered, nothing is re-booked.
	var l2: GameState = _load(SaveGame.to_dict(l, "s", "t"))["state"]
	t.eq(InventoryService.sweep_expired(l2).size(), 0)
	t.eq(l2.ledger.transactions.size(), l.ledger.transactions.size())


func _bad(t, label: String, mutate: Callable) -> void:
	var good := SaveGame.to_dict(_busy_cached(), "s", "t")
	var d := _json_roundtrip(good)
	mutate.call(d)
	var r := SaveGame.from_dict(d, _balance, _fx, _pr)
	t.ok(not r["ok"], "rejects: %s" % label)
	t.ok(r["state"] == null, "no state for: %s" % label)
	t.ok(not r["errors"].is_empty(), "explains: %s" % label)


var _cached: GameState


func _busy_cached() -> GameState:
	if _cached == null:
		_cached = _busy()
	return _cached


func test_broken_files_are_rejected(t, _tree) -> void:
	var s := _busy_cached()
	_bad(t, "missing key", func(d): d.erase("economy"))
	_bad(t, "unknown key", func(d): d["surprise"] = 1)
	_bad(t, "wrong type", func(d): d["game_time_seconds"] = "soon")
	_bad(t, "old/invalid version", func(d): d["schema_version"] = 0)
	_bad(t, "negative cash", func(d): d["economy"]["cash_yen"] = -1)
	_bad(t, "fractional money", func(d): d["economy"]["cash_yen"] = 10.5)
	_bad(t, "bad speed", func(d): d["speed_setting"] = 3)
	_bad(t, "bad state", func(d): d["business_state"] = "PARTY")
	_bad(t, "negative stock", func(d): d["inventory_segments"][0]["physical_qty"] = -1)
	_bad(t, "unknown sku", func(d): d["inventory_segments"][0]["sku_id"] = "ghost_sku")
	_bad(t, "reserved over physical", func(d): d["inventory_segments"][0]["reserved_qty"] = 99)
	_bad(t, "reserved != reservations", func(d): d["inventory_segments"][0]["reserved_qty"] = d["inventory_segments"][0]["reserved_qty"] + 1 if d["inventory_segments"][0]["physical_qty"] > d["inventory_segments"][0]["reserved_qty"] else 0)
	_bad(t, "unknown fixture type", func(d): d["fixture_instances"][0]["type_id"] = "ghost_fixture")
	_bad(t, "overlapping fixtures", func(d): d["fixture_instances"][1]["x"] = d["fixture_instances"][0]["x"]; d["fixture_instances"][1]["y"] = d["fixture_instances"][0]["y"])
	_bad(t, "duplicate fixture id", func(d): d["fixture_instances"][1]["instance_id"] = d["fixture_instances"][0]["instance_id"])
	_bad(t, "reservation of a missing segment", func(d): d["reservations"][0]["segment_id"] = "seg_9999")
	_bad(t, "bad rng", func(d): d["rng_states"]["arrivals"] = -5)
	_bad(t, "bad reputation", func(d): d["store_reputation"] = 101)
	_bad(t, "bad price override", func(d): d["product_price_overrides"]["rice_001"] = 0)
	_bad(t, "duplicate command ids", func(d): d["applied_command_ids"] = ["a", "a"])
	_bad(t, "unlisted ledger event", func(d): d["applied_event_ids"] = [])
	_bad(t, "duplicate daily charge", func(d): d["economy"]["ledger_transactions"].append(d["economy"]["ledger_transactions"][d["economy"]["ledger_transactions"].size() - 1].duplicate(true)))
	_bad(t, "SETUP with customers", func(d): d["business_state"] = "SETUP")
	_bad(t, "customer unknown phase", func(d): d["customers"][0]["phase"] = "DANCING")
	var future := SaveGame.to_dict(s, "s", "t")
	future["schema_version"] = 2
	var r := SaveGame.from_dict(_json_roundtrip(future), _balance, _fx, _pr)
	t.ok(not r["ok"])
	t.ok(r["unsupported_version"], "a newer version is flagged, not guessed at")
	t.ok(not SaveGame.from_dict([], _balance, _fx, _pr)["ok"], "not even an object")
	t.ok(not SaveGame.from_dict(null, _balance, _fx, _pr)["ok"])


func test_rejection_never_touches_the_running_state(t, _tree) -> void:
	var s := _busy_cached()
	var before := _norm(s)
	var d := _json_roundtrip(SaveGame.to_dict(s, "s", "t"))
	d["economy"]["cash_yen"] = -1
	SaveGame.from_dict(d, _balance, _fx, _pr)
	t.eq(_norm(s), before, "the live state is exactly as before")


func _clean() -> void:
	for f in ["slot_1.json", "slot_1.json.tmp", "slot_1.json.bak", "slot_2.json"]:
		var p := "%s/%s" % [TMP_DIR, f]
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_file_store_keeps_two_generations_and_no_temp(t, _tree) -> void:
	_clean()
	var s := _state()
	var first := SaveGame.to_dict(s, "gen1", "t")
	t.ok(SaveStore.write("slot_1", first, TMP_DIR)["ok"])
	t.ok(SaveStore.has_save("slot_1", TMP_DIR))
	t.ok(not SaveStore.has_backup("slot_1", TMP_DIR), "nothing to back up yet")
	var cmds := GameCommands.new(s)
	_run(cmds, &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 3})
	var second := SaveGame.to_dict(s, "gen2", "t")
	t.ok(SaveStore.write("slot_1", second, TMP_DIR)["ok"])
	t.ok(SaveStore.has_backup("slot_1", TMP_DIR))
	t.ok(not FileAccess.file_exists(SaveStore.path_for("slot_1", TMP_DIR) + ".tmp"), "no temp file left behind")
	t.eq(SaveStore.read("slot_1", false, TMP_DIR)["data"]["save_id"], "gen2")
	t.eq(SaveStore.read("slot_1", true, TMP_DIR)["data"]["save_id"], "gen1", "the previous generation is the backup")
	var loaded := SaveGame.from_dict(SaveStore.read("slot_1", false, TMP_DIR)["data"], _balance, _fx, _pr)
	t.ok(loaded["ok"], str(loaded["errors"]))
	t.eq(loaded["state"].cash_yen, s.cash_yen)
	_clean()


func test_file_store_reports_corruption_and_never_overwrites_silently(t, _tree) -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	var p := SaveStore.path_for("slot_2", TMP_DIR)
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var r := SaveStore.read("slot_2", false, TMP_DIR)
	t.ok(not r["ok"])
	t.eq(r["error"], "corrupt_json")
	t.eq(FileAccess.get_file_as_string(p), "{ this is not json", "reading leaves the broken file alone")
	t.eq(SaveStore.read("slot_3", false, TMP_DIR)["error"], "no_save")
	t.eq(SaveStore.read("nope", false, TMP_DIR)["error"], "unknown_slot")
	t.eq(SaveStore.write("nope", {}, TMP_DIR)["error"], "unknown_slot")
	_clean()


func test_a_closed_day_survives_a_trip_through_the_file(t, _tree) -> void:
	# Regression (found by the #25 scenario): JSON gives whole numbers back as floats, and a saved
	# daily report used to be rejected as "not_integer", so no save made after a day closed could load.
	var s := _busy()
	s.close_day_once(0)
	t.eq(s.daily_reports.size(), 1)
	var written := SaveStore.write("slot_3", SaveGame.to_dict(s, "slot_3", "2026-01-01T00:00:00Z"), TMP_DIR)
	t.ok(written["ok"], str(written))
	var read := SaveStore.read("slot_3", false, TMP_DIR)
	t.ok(read["ok"])
	var back := SaveGame.from_dict(read["data"], _balance, _fx, _pr)
	t.ok(back["ok"], str(back.get("errors", "")))
	if back["ok"]:
		t.eq(back["state"].daily_reports, s.daily_reports)
		for k in DailyReport.FIELDS:
			t.eq(typeof(back["state"].daily_reports[0][k]), TYPE_INT, "%s is an int again" % k)
	for ext in [".json", ".json.bak", ".json.tmp"]:
		if FileAccess.file_exists("%s/slot_3%s" % [TMP_DIR, ext]):
			DirAccess.remove_absolute("%s/slot_3%s" % [TMP_DIR, ext])
	t.ok(not DailyReport.errors({"day_index": 1.5}).is_empty(), "a real fraction is still rejected")
