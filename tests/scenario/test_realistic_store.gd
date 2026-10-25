extends RefCounted
## A realistic store (data/layouts/realistic_store_v1.json, large 20x16) under the real balance — slow walking, staff,
## outdoor approach — at three times the station's visitors: nobody stands still in a walking phase, walks in circles
## or stays for hours, no staff member flaps between jobs, the till never closes while people wait, and empty shelves
## with stock in the backroom get refilled. The full multi-day run is tools/soak_store.gd.

const Soak := preload("res://tools/soak_store.gd")


func test_a_realistic_store_runs_half_a_day_cleanly(t, _tree) -> void:
	var b := Soak.build("station", 4, 3.0)
	t.eq(b["failed"], [], "every fixture of the layout is placed")
	var s: GameState = b["state"]
	var runner := SimulationRunner.new(s)
	var w := Soak.Watch.new()
	while s.time_sec < 14 * 3600:
		runner._run_step()
		w.observe(s)
	t.eq(w.counts, {}, "no stuck, looping or long-staying customer and no flapping staff: %s" % str(w.issues))
	t.eq(w.closed_wait_steps, 0, "nobody waited at a closed till")
	t.eq(w.starve_steps, 0, "no empty shelf waited for idle staff")
	t.ok(w.finished.size() >= 40, "customers came and went (%d)" % w.finished.size())
	t.ok(int(s.visit_stats["purchased"]) >= 30, "and bought (%d)" % int(s.visit_stats["purchased"]))
