extends RefCounted
## P0 customer intent on screen (issues #15, #16, #23, #30). A fixed-seed run of the real simulation on the
## path-test store, with the presentation fed from the same events and snapshots the app uses:
##   (a) every pick cue (CUSTOMER_RESERVED_ITEM -> product_pickup) belongs to a customer that holds that
##       reservation at that fixture and SKU in the same step;
##   (b) every checkout pop (SALE_COMMITTED -> checkout_success) matches exactly one SALE ledger row with the
##       same transaction, price and product name, and the pop text reads "<name> ¥<price>";
##   (c) queues: at most QUEUE_MAX customers per register, never two customers in one slot or on one tile,
##       never a customer in a slot while waiting for one (WAIT_QUEUE), never on a blocked tile;
##   (d) the presentation is read-only: the same run with the presentation switched off gives identical cash,
##       ledger, customer and RNG states.

const Paths := preload("res://tests/scenario/test_customer_paths.gd")
const CUES_PATH := "res://data/presentation/cues_v1.json"
const RUN_UNTIL_SEC := 3600
const ARRIVE_EVERY_STEPS := 3   # busier than the path test, so the register lines fill up
const PRESENT_EVERY_STEPS := 10 # the presenter's compose() is heavier than the logic step


func _cues() -> Array[Dictionary]:
	var problems: Array[String] = []
	var cues := PresentationEventBridge.load_cues(JSON.parse_string(FileAccess.get_file_as_string(CUES_PATH)), problems)
	assert(problems.is_empty(), str(problems))
	return cues


## One run. `presentation` = true drives the bridge, the sale pop-up policy and the presenter like the app does.
func _run(t, presentation: bool, label: String) -> Dictionary:
	var helper = Paths.new()
	var s: GameState = helper._store(t, 1)
	var runner := SimulationRunner.new(s)
	var blocked := s.grid.blocked_cells()
	var bridge := PresentationEventBridge.new()
	bridge.setup(_cues())
	var fake = Paths.FakeWorld.new()
	var pres = Paths.Presenter.new()
	fake.fixtures = s.grid.to_save()["fixture_instances"]
	fake.fixture_catalog = s.fixtures
	fake.product_catalog = s.products
	fake.speed_setting = 1
	pres._world = fake
	var st := {"picks": 0, "pick_orphans": 0, "sales": 0, "sale_mismatch": [] as Array, "pop_mismatch": [] as Array,
		"queue_viol": [] as Array, "max_slot": -1, "max_waiting": 0, "wait_queue_seen": 0, "bubbles": 0, "pops": 0}
	var step_no := 0
	while s.time_sec < RUN_UNTIL_SEC:
		step_no += 1
		if step_no % ARRIVE_EVERY_STEPS == 0:
			s.next_customer_seq += 1
			s.arrival_queue.append({"customer_id": "cust_%05d" % s.next_customer_seq, "arrived_at_sec": s.time_sec})
		runner._run_step()
		var events := s.take_events()   # both runs drain the log, so the logs never differ by presentation
		_check_queues(s, blocked, st)
		if presentation:
			var requests := bridge.map(events, s.time_sec)
			for r in requests:
				var payload: Dictionary = r["payload"]
				if r["cue_id"] == "product_pickup":
					st["bubbles"] = int(st["bubbles"]) + 1
					pres.note_pick(String(payload.get("customer_id", "")), String(payload.get("fixture_id", "")))
				elif r["cue_id"] == "checkout_success":
					st["pops"] = int(st["pops"]) + 1
					_check_pop(s, payload, st)
			if step_no % PRESENT_EVERY_STEPS == 0:
				fake.customers = s._customer_views()
				pres._sync_customers(1.0 / 60.0)
				pres.compose()
		for e in events:
			if e["type"] == "CUSTOMER_RESERVED_ITEM":
				_check_pick(s, e["payload"], st)
			elif e["type"] == "SALE_COMMITTED":
				st["sales"] = int(st["sales"]) + 1
				_check_sale_row(s, e["payload"], st)
	st["cash"] = s.ledger.cash_yen
	st["sale_rows"] = _count_sale_rows(s)
	st["rng"] = s.rng_states.duplicate()
	st["purchased"] = int(s.visit_stats.get("purchased", 0))
	st["customers"] = s.customers.size()
	st["ledger_size"] = s.ledger.transactions.size()
	st["label"] = label
	return st


## (a) the customer that reserved the item holds that reservation at that fixture and SKU, in the same step.
func _check_pick(s: GameState, payload: Dictionary, st: Dictionary) -> void:
	st["picks"] = int(st["picks"]) + 1
	for c in s.customers:
		if c["customer_id"] == payload.get("customer_id", ""):
			# Issue #128: a basket holds several reservations; the pick is one of them (the customer's current
			# target has moved on to the next item by the time the pick cue is read in the same step).
			if (c["reservation_ids"] as Array).has(payload.get("reservation_id", "")):
				return
	st["pick_orphans"] = int(st["pick_orphans"]) + 1


## (b) one SALE row per committed sale, same price and product; the pop's text names the same product and price.
func _check_sale_row(s: GameState, payload: Dictionary, st: Dictionary) -> void:
	# Issue #128: one basket = one row per item, all carrying the basket's transaction id in details.
	var rows := 0
	var revenue := 0
	var first: Dictionary = {}
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE" and String(tx["details"].get("transaction_id", "")) == String(payload.get("transaction_id", "")):
			rows += 1
			revenue += int(tx["cash_delta_yen"])
			if first.is_empty():
				first = tx
	var name := String(payload.get("name", ""))
	var display := String(s.products.get_sku(payload.get("sku_id", ""))["display_name"])
	var ok: bool = rows == int(payload.get("items", 1)) and rows >= 1 and revenue == int(payload["revenue_yen"])
	ok = ok and String(first.get("details", {}).get("sku_id", "")) == String(payload.get("sku_id", ""))
	ok = ok and (name == display or name.begins_with("%s 他" % display))
	if not ok:
		(st["sale_mismatch"] as Array).append(payload)


func _check_pop(s: GameState, payload: Dictionary, st: Dictionary) -> void:
	var name := String(payload.get("name", ""))
	var expect := "%s %s" % [name, GameHud.format_yen(int(payload.get("revenue_yen", 0)))]
	var pop := NotificationPolicy.add_sale([], String(payload.get("register_id", "")), int(payload.get("revenue_yen", 0)), name)
	if pop["text"] != expect or pop["text"].find(name) < 0:
		(st["pop_mismatch"] as Array).append(pop["text"])


func _count_sale_rows(s: GameState) -> int:
	var n := 0
	for tx in s.ledger.transactions:
		if tx["event_type"] == "SALE":
			n += 1
	return n


func _check_queues(s: GameState, blocked: Dictionary, st: Dictionary) -> void:
	var slots := {}     # register_id -> {slot: customer_id}
	var standing := {}  # tile -> customer_id, for everyone standing still in the line (waiting, queued, at the till)
	var walking := {}   # tile -> customer (walkers in the line area; stacking is counted, not an error)
	var waiting := {}
	for c in s.customers:
		var reg := String(c["register_id"])
		var phase := String(c["phase"])
		var slot := int(c["queue_slot"])
		var tile: Vector2i = c["tile"]
		var in_line: bool = phase in ["WAIT_QUEUE", "QUEUE", "CHECKOUT"] or (phase == "WALK_REGISTER" and slot >= 0)
		if phase == "WAIT_QUEUE":
			if slot != -1:
				(st["queue_viol"] as Array).append("%s waits for a slot but holds %d" % [c["customer_id"], slot])
			waiting[reg] = int(waiting.get(reg, 0)) + 1
			st["wait_queue_seen"] = int(st["wait_queue_seen"]) + 1
		if blocked.has(tile) and reg != "":
			(st["queue_viol"] as Array).append("%s stands on a fixture cell %s" % [c["customer_id"], tile])
		if slot >= 0:
			st["max_slot"] = maxi(int(st["max_slot"]), slot)
			if slot >= AccessService.QUEUE_MAX:
				(st["queue_viol"] as Array).append("%s in slot %d (max %d)" % [c["customer_id"], slot, AccessService.QUEUE_MAX])
			if not slots.has(reg):
				slots[reg] = {}
			if slots[reg].has(slot):
				(st["queue_viol"] as Array).append("two customers in slot %d of %s" % [slot, reg])
			slots[reg][slot] = c["customer_id"]
		if not in_line:
			continue
		if (c["path"] as Array).is_empty():
			# Two customers standing still on one tile is the error (line, till or waiting spot).
			if standing.has(tile):
				(st["queue_viol"] as Array).append("%s and %s share tile %s (%s)" % [c["customer_id"], standing[tile], tile, phase])
			standing[tile] = c["customer_id"]
		else:
			if walking.has(tile):
				st["stacked"] = int(st.get("stacked", 0)) + 1
				if not st.has("stacked_sample"):
					st["stacked_sample"] = []
				var other: Dictionary = walking[tile]
				if (st["stacked_sample"] as Array).size() < 4:
					(st["stacked_sample"] as Array).append("%s %s s%d p%d + %s %s s%d p%d @%s" % [c["customer_id"], phase, slot, (c["path"] as Array).size(), other["customer_id"], other["phase"], int(other["queue_slot"]), (other["path"] as Array).size(), tile])
			walking[tile] = c
	for reg in waiting:
		st["max_waiting"] = maxi(int(st["max_waiting"]), int(waiting[reg]))
	for reg in slots:
		st["max_waiting"] = maxi(int(st["max_waiting"]), int(slots[reg].size()))


func _assert_common(t, st: Dictionary) -> void:
	t.ok(int(st["picks"]) > 0, "%s: the run has picks (%d)" % [st["label"], int(st["picks"])])
	t.ok(int(st["sales"]) > 0, "%s: the run has sales (%d)" % [st["label"], int(st["sales"])])
	t.eq(int(st["pick_orphans"]), 0, "%s (a): every pick cue has its reservation at that fixture and SKU" % st["label"])
	t.eq(st["sale_mismatch"], [] as Array, "%s (b): every sale pop has exactly one SALE row with the same price and name" % st["label"])
	t.eq(st["pop_mismatch"], [] as Array, "%s (b): every pop reads '<name> ¥<price>'" % st["label"])
	t.eq(int(st["sales"]), int(st["sale_rows"]), "%s (b): SALE_COMMITTED events == SALE ledger rows" % st["label"])
	t.eq(int(st["pops"]), int(st["sales"]), "%s (b): one checkout pop per committed sale" % st["label"])
	t.eq(int(st["bubbles"]), int(st["picks"]), "%s (a): one pick bubble per reservation" % st["label"])
	t.eq(st["queue_viol"], [] as Array, "%s (c): no queue rule broken in any step" % st["label"])
	t.ok(int(st["max_slot"]) <= AccessService.QUEUE_MAX - 1, "%s (c): slots stay within 0..%d (max %d)" % [st["label"], AccessService.QUEUE_MAX - 1, int(st["max_slot"])])


func test_pick_and_sale_cues_match_real_events(t, _tree) -> void:
	var st := _run(t, true, "presentation on")
	_assert_common(t, st)
	t.ok(int(st["max_waiting"]) >= 2, "the line forms: at least two customers waited at one register (%d)" % int(st["max_waiting"]))
	t.ok(int(st["wait_queue_seen"]) > 0, "a full line is exercised: customers waited for a slot (%d customer-steps)" % int(st["wait_queue_seen"]))
	print("INTENT picks=%d sales=%d bubbles=%d pops=%d max_waiting=%d wait_queue_steps=%d walkers_on_parked_tile=%d stacked=%d %s" % [
		int(st["picks"]), int(st["sales"]), int(st["bubbles"]), int(st["pops"]), int(st["max_waiting"]), int(st["wait_queue_seen"]), int(st.get("transit_pass", 0)), int(st.get("stacked", 0)), str(st.get("stacked_sample", []))])


func test_presentation_switch_changes_no_state(t, _tree) -> void:
	var on := _run(t, true, "presentation on")
	var off := _run(t, false, "presentation off")
	t.eq(int(on["cash"]), int(off["cash"]), "cash is identical with the presentation on and off")
	t.eq(int(on["ledger_size"]), int(off["ledger_size"]), "ledger rows are identical")
	t.eq(int(on["purchased"]), int(off["purchased"]), "purchases are identical")
	t.eq(on["rng"], off["rng"], "RNG states are identical")
	t.eq(int(on["customers"]), int(off["customers"]), "customers in the store are identical")
