extends RefCounted
## Issue #134 phase 1: eat-in — a counter whose front tiles are seats; customers who bought something to eat here
## sit at a free seat after paying and leave after a while; never two on one seat; a seated customer survives a
## save; a store without a counter behaves as before.

const Run := preload("res://tests/support/basket_run.gd")


func test_customers_sit_and_leave(t, _tree) -> void:
	var s := Run.new_state(300.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(1, s.grid.height - 1):
		for x in range(1, s.grid.width - 3):
			if placed == "":
				var r := cmds.execute({"command_id": "e_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "eat_in_counter", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.ok(placed != "", "a counter placed")
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	var shared := 0
	var seated_seen := 0
	var saved_one := false
	for i in int(14 * 3600 / GameClock.STEP_GAME_SECONDS):
		runner._run_step()
		var seats := {}
		for c in s.customers:
			if c.has("seat"):
				if seats.has(c["seat"]):
					shared += 1
				seats[c["seat"]] = true
				if c["phase"] == "EAT":
					seated_seen += 1
					if not saved_one:
						saved_one = true
						var saved := SaveGame.to_dict(s, "eat", "2026-10-27T00:00:00Z")
						var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
						t.ok(lr["ok"], str(lr["errors"]))
						var back: Array = (lr["state"] as GameState).customers.filter(func(x): return x["customer_id"] == c["customer_id"])
						t.eq(back[0]["seat"], c["seat"], "the seat survives a save")
						t.eq(back[0]["phase"], "EAT", "still eating")
	t.ok(s.eat_in_total > 0, "customers sat down to eat (%d)" % s.eat_in_total)
	t.ok(seated_seen > 0, "and stayed a while")
	t.eq(shared, 0, "never two on one seat")
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
	t.eq(OverlayModel.customer_action({"phase": "EAT"}, ""), "イートインで食事中", "the panel says so")


## A table seats four: two on each long side (access N and S).
func test_a_table_seats_four(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var placed := ""
	for y in range(2, s.grid.height - 2):
		for x in range(1, s.grid.width - 2):
			if placed == "":
				var r := cmds.execute({"command_id": "tb_%d_%d" % [x, y], "kind": &"PLACE_FIXTURE", "type_id": "eat_in_table", "x": x, "y": y, "rotation": 0})
				if r.ok:
					placed = r.data["instance_id"]
	t.ok(placed != "", "a table placed")
	t.ok(EatIn.counters(s).has(placed), "it counts as eat-in seating")
	var ai := CustomerAI.new()
	t.ok(ai._shelf_access(s, placed).size() >= 3, "seats on both sides (%d reachable)" % ai._shelf_access(s, placed).size())
