extends RefCounted
## A realistic store (data/layouts/realistic_store_v1.json, large 20x16, two registers) under the real balance — slow
## walking, staff, outdoor approach: nobody stands still in a walking phase, walks in circles or stays for hours, no
## staff member flaps between jobs, no till is closed while people stand in its line, and a busy store opens the
## second till. The full multi-day run is tools/soak_store.gd.

const Soak := preload("res://tools/soak_store.gd")
const Run := preload("res://tests/support/basket_run.gd")


func _regs(s: GameState) -> Array:
	var ids: Array = s.grid.instances.keys().filter(func(id): return AccessService.is_register(s.fixtures.get_type(s.grid.instances[id]["type_id"])))
	ids.sort()
	return ids


func test_a_realistic_store_runs_half_a_day_cleanly(t, _tree) -> void:
	var b := Soak.build("station", 4, 3.0)
	t.eq(b["failed"], [], "every fixture of the layout is placed")
	var s: GameState = b["state"]
	var runner := SimulationRunner.new(s)
	var w := Soak.Watch.new()
	while s.time_sec < 14 * 3600:
		runner._run_step()
		w.observe(s)
	t.eq(w.counts, {}, "no stuck, looping or long-staying customer, no flapping staff, no line at a closed till: %s" % str(w.issues))
	t.eq(w.closed_wait_steps, 0, "nobody stood in the line of a closed till")
	t.eq(w.starve_steps, 0, "no empty shelf waited for idle staff")
	t.ok(w.finished.size() >= 40, "customers came and went (%d)" % w.finished.size())
	t.ok(int(s.visit_stats["purchased"]) >= 30, "and bought (%d)" % int(s.visit_stats["purchased"]))
	var regs := _regs(s)
	t.eq(regs.size(), 2, "two registers")
	t.ok(int(w.checkouts.get(regs[0], 0)) > 0 and int(w.checkouts.get(regs[1], 0)) > 0, "the busy morning opened the second till: %s" % str(w.checkouts))


## With two tills a tired cashier still waits for relief at its own till: a fresh cashier at the other till is no
## relief (the handover of 2026-10-25, per register).
func test_handovers_keep_each_till_open(t, _tree) -> void:
	var b := Soak.build("station", 4, 5.0)
	var s: GameState = b["state"]
	s.balance["staff_fatigue_per_hour"] = {"register": 60, "restock": 20, "walk": 20, "idle": 10, "rest": -120}
	var runner := SimulationRunner.new(s)
	var cells := {}
	for id in _regs(s):
		cells[id] = StaffAI.cashier_cell(s, id)
	var was := {}
	var handovers := 0
	var bad: Array = []
	while s.time_sec < 14 * 3600 and handovers < 6:
		runner._run_step()
		for st in s.staff:
			var prev: Array = was.get(st["staff_id"], ["", Vector2i(-1, -1)])
			if prev[0] == "REGISTER" and st["phase"] in ["TO_REST", "REST"] and float(st["fatigue"]) < StaffAI.FORCED:
				handovers += 1
				var relieved := s.staff.any(func(o): return o["staff_id"] != st["staff_id"] and o["phase"] == "REGISTER" and o["tile"] == prev[1])
				if not relieved:
					bad.append("%s left %s at %d" % [st["staff_id"], prev[1], s.time_sec])
			was[st["staff_id"]] = [st["phase"], st["tile"]]
	t.ok(handovers >= 2, "cashiers handed over for a rest (%d times)" % handovers)
	t.eq(bad, [], "each time someone else already stood at that same till")


## A save taken while a customer is in the second till's line loads and runs on exactly like the original.
func test_a_save_in_the_second_line_replays(t, _tree) -> void:
	var b := Soak.build("station", 4, 5.0)
	var s: GameState = b["state"]
	var runner := SimulationRunner.new(s)
	var second: String = _regs(s)[1]
	var found := false
	while s.time_sec < 14 * 3600 and not found:
		runner._run_step()
		found = s.customers.any(func(c): return c["register_id"] == second and int(c["queue_slot"]) >= 1)
	t.ok(found, "someone stands in the second till's line (at %d)" % s.time_sec)
	if not found:
		return
	var saved := SaveGame.to_dict(s, "two_tills", "2026-10-26T00:00:00Z")
	var loaded := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(loaded["ok"], "the save loads: %s" % str(loaded["errors"]))
	if not loaded["ok"]:
		return
	var c: GameState = loaded["state"]
	var runner_c := SimulationRunner.new(c)
	for i in 900:
		runner._run_step()
		runner_c._run_step()
	t.eq(Run.fingerprint(c), Run.fingerprint(s), "loaded and uninterrupted runs agree after 900 more steps")
	t.eq(c.staff.map(func(x): return [x["phase"], x["tile"]]), s.staff.map(func(x): return [x["phase"], x["tile"]]), "the staff too")
