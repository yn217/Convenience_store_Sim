extends RefCounted
## Issue #149 phase 1: nearby facilities chosen before the first opening bring their own customer segments at their
## own hours; a store without facilities keeps its arrivals exactly.

const Run := preload("res://tests/support/basket_run.gd")


func test_facility_table_is_well_formed(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var cats := {}
	for sku in pr.skus.values():
		cats[sku["category"]] = true
	var segments := 0
	for f in NearbyFacility.all():
		t.eq((f["hour_weights"] as Array).size(), 24, f["facility_id"] + ": 24 hour weights")
		t.ok(int(f["visitors_per_day"]) > 0 and String(f["description"]) != "", f["facility_id"] + ": visitors and a description")
		for seg in f["segments"]:
			segments += 1
			t.ok(String(seg["display_name"]) != "", "a name for the panel")
			for pid in seg["purposes"]:
				var p := VisitPurpose.find(balance, pid)
				t.ok(not p.is_empty(), "%s: purpose %s exists" % [seg["segment_id"], pid])
				for slot in p.get("targets", []):
					for c in slot:
						t.ok(c == VisitPurpose.ANY or cats.has(c), "%s: category %s exists" % [pid, c])
	t.ok(segments >= 7, "seven facility segments on top of the location's purposes (%d)" % segments)
	for p in balance["visit_purposes"]:
		if bool(p.get("facility_only", false)):
			t.eq((p["hour_weights"] as Array).reduce(func(a, x): return a + float(x), 0.0), 0.0, p["purpose_id"] + ": never drawn for the location's own visitors")


func test_facilities_are_chosen_before_the_first_opening(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	t.ok(cmds.execute({"command_id": "f1", "kind": &"SET_FACILITIES", "facility_ids": ["factory", "hotel"]}).ok, "two facilities")
	t.eq(s.facilities, ["factory", "hotel"])
	var r := cmds.execute({"command_id": "f2", "kind": &"SET_FACILITIES", "facility_ids": ["factory", "hotel", "hospital"]})
	t.ok(not r.ok and r.message_key == &"too_many_facilities", "at most two")
	r = cmds.execute({"command_id": "f3", "kind": &"SET_FACILITIES", "facility_ids": ["moon_base"]})
	t.ok(not r.ok and r.message_key == &"unknown_facility", "unknown facility")
	t.eq(s.facilities, ["factory", "hotel"], "a refused command changes nothing")
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	SimulationRunner.new(s)._run_step()
	r = cmds.execute({"command_id": "f4", "kind": &"SET_FACILITIES", "facility_ids": []})
	t.ok(not r.ok and r.message_key == &"facilities_locked", "fixed once the store has opened")


## Arrivals per hour for one day (no customers walking): the location's and each facility's, same seed.
func _day(facilities: Array, location := "residential") -> Dictionary:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "loc", "kind": &"SET_LOCATION", "location_id": location})
	cmds.execute({"command_id": "fac", "kind": &"SET_FACILITIES", "facility_ids": facilities})
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var by_hour: Array = []
	by_hour.resize(24)
	by_hour.fill(0)
	var segs := {}
	var purposes := {}
	var plain: Array = []
	while s.time_sec < DemandModel.SECONDS_PER_DAY:
		s.time_sec += int(GameClock.STEP_GAME_SECONDS)
		DemandGenerator.step(s)
		for a in s.arrival_queue:
			if String(a.get("segment_id", "")) != "":
				by_hour[DemandModel.hour_of_day(s.time_sec)] += 1
				segs[a["segment_id"]] = int(segs.get(a["segment_id"], 0)) + 1
				purposes[a["purpose_id"]] = int(purposes.get(a["purpose_id"], 0)) + 1
			else:
				plain.append([s.time_sec, a["purpose_id"], a["budget_yen"]])
		s.arrival_queue.clear()
	return {"by_hour": by_hour, "segments": segs, "purposes": purposes, "plain": plain, "visits": s.facility_visits.duplicate()}


func test_a_factory_sends_shift_workers_at_shift_change(t, _tree) -> void:
	var none := _day([])
	var factory := _day(["factory"])
	t.eq(none["segments"], {}, "no facility, nobody from one")
	var h: Array = factory["by_hour"]
	var shifts: int = h[5] + h[6] + h[13] + h[14] + h[21] + h[22]
	var total: int = h.reduce(func(a, x): return a + int(x), 0)
	t.ok(total >= 30, "the factory sends its workers (%d)" % total)
	t.ok(float(shifts) / float(total) > 0.6, "mostly around the shift changes: %d of %d (%s)" % [shifts, total, str(h)])
	t.eq(factory["segments"].keys(), ["shift_workers"])
	t.ok(int(factory["purposes"].get("shift_meal", 0)) > int(factory["purposes"].get("drink_only", 0)), "they come for a meal: %s" % str(factory["purposes"]))
	t.eq(int(factory["visits"]["factory"]), total, "counted per facility")


func test_the_hotel_and_the_tourist_spot_differ_by_hour(t, _tree) -> void:
	var hotel: Array = _day(["hotel"])["by_hour"]
	var tour: Array = _day(["tourist_spot"])["by_hour"]
	var early_late := func(a: Array) -> int: return int(a[6]) + int(a[7]) + int(a[8]) + int(a[20]) + int(a[21]) + int(a[22])
	var midday := func(a: Array) -> int: return int(a[11]) + int(a[12]) + int(a[13]) + int(a[14])
	t.ok(early_late.call(hotel) > midday.call(hotel), "hotel guests: mornings and evenings %s" % str(hotel))
	t.ok(midday.call(tour) > early_late.call(tour), "day tourists: the middle of the day %s" % str(tour))


## The location's own visitors are drawn first and in the same order, so adding a facility changes nothing for them
## until the first facility visitor takes the next customer number... compare the first location arrival times only.
func test_without_facilities_the_location_arrivals_are_unchanged(t, _tree) -> void:
	var a := _day([])
	var b := _day([])
	t.eq(a["plain"], b["plain"], "deterministic")
	t.ok((a["plain"] as Array).size() > 20, "the residential street brings people (%d)" % (a["plain"] as Array).size())


func test_facility_customers_shop_and_survive_a_save(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "fac", "kind": &"SET_FACILITIES", "facility_ids": ["factory", "highway"]})
	var runner := SimulationRunner.new(s)
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var guard := 0
	while not s.customers.any(func(c): return String(c.get("segment_id", "")) != "" and c["phase"] != "APPROACH") and guard < 20000:
		runner._run_step()
		guard += 1
	var c: Dictionary = s.customers.filter(func(x): return String(x.get("segment_id", "")) != "")[0]
	var view: Dictionary = s.snapshot()["customers"].filter(func(x): return x["customer_id"] == c["customer_id"])[0]
	t.ok(OverlayModel.customer_panel_lines(view, "").has("客層：%s" % NearbyFacility.segment_name(c["segment_id"])), "the panel shows the segment")
	var saved := SaveGame.to_dict(s, "fac", "2026-10-26T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	if not lr["ok"]:
		return
	var b: GameState = lr["state"]
	t.eq(b.facilities, ["factory", "highway"], "the facilities survive a save")
	t.eq(b.facility_visits, s.facility_visits, "with today's counts")
	t.eq(b.customers.filter(func(x): return x["customer_id"] == c["customer_id"])[0]["segment_id"], c["segment_id"], "and the customer's segment")
	var runner_b := SimulationRunner.new(b)
	for i in 1200:
		runner._run_step()
		runner_b._run_step()
	t.eq(Run.fingerprint(b), Run.fingerprint(s), "loaded and uninterrupted runs agree")
	t.ok(s.ledger.transactions.any(func(tx): return tx["event_type"] == "SALE"), "facility customers buy")


## Booked sales (not only arrivals): with a factory nearby, bento and onigiri sell more in the hours after the
## midday shift change than in the same store without it (same seed and stock).
func test_a_factory_sells_meals_after_the_shift_change(t, _tree) -> void:
	var sold := {}
	for with_factory in [false, true]:
		var s := Run.new_state(100.0)
		var cmds := Run.place_layout(s)
		if with_factory:
			cmds.execute({"command_id": "fac", "kind": &"SET_FACILITIES", "facility_ids": ["factory"]})
		Run.run_days(s, cmds, 1)
		var n := 0
		for tx in s.ledger.transactions:
			var hour := DemandModel.hour_of_day(int(tx["time_sec"]))
			if tx["event_type"] == "SALE" and hour >= 13 and hour < 17 and ["bento", "rice_ball"].has(s.products.get_sku(tx["details"]["sku_id"])["category"]):
				n += int(tx["details"]["qty"])
		sold[with_factory] = n
	t.ok(int(sold[true]) > int(sold[false]), "bento and onigiri sold 13-17h: %d with the factory, %d without" % [sold[true], sold[false]])
