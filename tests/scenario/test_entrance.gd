extends RefCounted
## Issue #142: customers come along the pavement, step in at the door — or turn back there when the line inside is
## too long — and leave along the pavement; passers-by walk past without entering (presentation only).

const Paths := preload("res://tests/scenario/test_customer_paths.gd")


func _arrive(s: GameState) -> String:
	s.next_customer_seq += 1
	var id := "cust_%05d" % s.next_customer_seq
	s.arrival_queue.append({"customer_id": id, "arrived_at_sec": s.time_sec})
	s.visit_stats["potential"] += 1   # as DemandGenerator counts an arrival
	s.visit_stats["entered"] += 1
	return id


func _find(s: GameState, id: String) -> Dictionary:
	for c in s.customers:
		if c["customer_id"] == id:
			return c
	return {}


func test_pavement_routes(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var door: Vector2i = s.grid.entrance_tiles[0]
	for from_low in [true, false]:
		var r := CustomerAI.outside_route(s.grid, door, from_low)
		t.eq(r.back(), door + CustomerAI.door_normal(s.grid, door), "ends on the tile just outside the door")
		var ok := true
		for i in r.size():
			if s.grid.in_bounds(r[i]):
				ok = false
			if i > 0 and absi(r[i].x - r[i - 1].x) + absi(r[i].y - r[i - 1].y) != 1:
				ok = false
		t.ok(ok, "every tile is outside the store and one step from the last (from_low %s)" % from_low)
		t.ok(r.size() > CustomerAI.OUTSIDE_MARGIN, "it starts past the end of the wall")
		var a := CustomerAI.away_route(s.grid, door, from_low)
		t.eq(a[0], door + CustomerAI.door_normal(s.grid, door), "leaving starts just outside the door")
		t.eq(a.back(), r[0] if from_low else CustomerAI.outside_route(s.grid, door, false)[0], "and ends where an arrival from that end appears")


func test_a_customer_comes_in_from_the_pavement_and_leaves_along_it(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var runner := SimulationRunner.new(s)
	var id := _arrive(s)
	var phases: Array = []
	var entered_at_door := false
	var outside_seen := false
	for i in 4000:
		runner._run_step()
		var c := _find(s, id)
		if c.is_empty():
			break
		if phases.is_empty() or phases.back() != c["phase"]:
			phases.append(c["phase"])
		if c["phase"] in ["APPROACH", "WALK_AWAY"] and not s.grid.in_bounds(c["tile"]):
			outside_seen = true
		for e in s.event_log.slice(maxi(s.event_log.size() - 10, 0)):
			if e["type"] == "CUSTOMER_ENTERED" and e["payload"]["customer_id"] == id and int(e["tick"]) == s.time_sec:
				entered_at_door = s.grid.entrance_tiles.has(c["tile"])
	t.eq(phases[0], "APPROACH", "it appears on the pavement")
	t.ok(phases.has("ENTER") and phases.has("SELECT"), "steps in, then shops: %s" % str(phases))
	t.eq(phases.back(), "WALK_AWAY", "and walks away along the pavement")
	t.ok(outside_seen, "it was seen outside the store")
	t.ok(entered_at_door, "CUSTOMER_ENTERED fires on the entrance tile")
	t.ok(_find(s, id).is_empty(), "then it is gone")


## A line of customers at the register: a new arrival looks in at the door and turns back.
func test_a_long_line_makes_customers_turn_back(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	s.balance["staff_enabled"] = false   # the line alone decides here (closed registers: test_staff.gd)
	s.balance["checkout_base_game_seconds"] = 100000   # the first customer blocks the till
	s.balance["queue_patience_game_seconds"] = 100000  # and nobody in the line gives up
	var runner := SimulationRunner.new(s)
	var ai: CustomerAI = runner._customers
	var steps := 0
	while not ai.should_balk(s) and steps < 20000:
		if steps % 40 == 0:
			_arrive(s)
		runner._run_step()
		steps += 1
	t.ok(ai.should_balk(s), "the line grew long enough to turn people back (%d steps)" % steps)
	s.arrival_queue.clear()
	var guard := 0   # the ones already on their way reach the door (and turn back) first
	while s.customers.any(func(c): return c["phase"] == "APPROACH") and guard < 3000:
		runner._run_step()
		guard += 1
	var before := s.visit_stats.duplicate()
	var rate_before := int(s.rate_stats.get("balked", 0))
	var id := _arrive(s)
	var balked := false
	for i in 1500:
		runner._run_step()
		var c := _find(s, id)
		if c.is_empty():
			break
		if c["phase"] == "WALK_AWAY" and c["outcome"] == "balked":
			balked = true
		if not (c["phase"] in ["APPROACH", "WALK_AWAY"]):
			t.ok(false, "never inside: %s" % c["phase"])
			break
	t.ok(balked, "it turned back at the door")
	t.eq(int(s.visit_stats["balked"]), int(before.get("balked", 0)) + 1, "counted as turned back")
	t.eq(int(s.visit_stats["entered"]), int(before["entered"]) + 1 - 1, "not counted as a visitor")
	t.eq(int(s.visit_stats["lost"]), int(before["lost"]) + 1, "counted as a lost customer")
	t.eq(int(s.visit_stats["potential"]), int(s.visit_stats["entered"]) + int(s.visit_stats["lost"]), "the counters still add up")
	t.eq(int(s.rate_stats["balked"]), rate_before + 1, "and for the reputation")
	var calm := ReputationModel.daily_delta({"entered": 10, "purchased": 10}, {"abandoned": 0, "stockouts": 0})
	var crowded := ReputationModel.daily_delta({"entered": 10, "purchased": 10}, {"abandoned": 0, "stockouts": 0, "balked": 10})
	t.ok(crowded < calm, "turning people back costs reputation: %d < %d" % [crowded, calm])


func test_no_register_turns_everyone_back(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var cmds := GameCommands.new(s)
	s.business_state = GameState.SETUP
	for id in s.grid.instances.keys():
		if String(s.grid.instances[id]["type_id"]).begins_with("register"):
			t.ok(cmds.execute({"command_id": "rm_" + id, "kind": &"REMOVE_FIXTURE", "instance_id": id}).ok, "removed the register")
	s.business_state = GameState.OPEN
	var runner := SimulationRunner.new(s)
	var id := _arrive(s)
	var outcome := ""
	for i in 1500:
		runner._run_step()
		var c := _find(s, id)
		if c.is_empty():
			break
		outcome = c["outcome"]
	t.eq(outcome, "balked", "without a register nobody comes in")


func test_passersby_are_a_pure_function_of_the_clock(t, _tree) -> void:
	var p = Paths.new()
	var s: GameState = p._store(t, 1)
	var walk := float(s.balance["customer_walk_tiles_per_game_second"])
	var ents: Array = s.grid.entrance_tiles.duplicate()
	var total := 0
	var ids := {}
	for minute in range(0, 24 * 60, 5):
		var at := minute * 60
		var v := Passersby.views(at, s.grid.width, s.grid.height, ents, walk, 120)
		t.eq(v, Passersby.views(at, s.grid.width, s.grid.height, ents, walk, 120), "same time, same people")
		for x in v:
			ids[x["customer_id"]] = true
			if s.grid.in_bounds(x["tile"]):
				t.ok(false, "a passer-by inside the store at %s" % x["tile"])
			t.ok(bool(x["passerby"]), "flagged as a passer-by")
	total = ids.size()
	t.ok(total > 60 and total < 200, "about 120 a day walk past: %d" % total)   # (the test asks for 120 a day)
	t.eq(Passersby.views(3600, s.grid.width, s.grid.height, ents, walk, 0), [], "none when switched off")
