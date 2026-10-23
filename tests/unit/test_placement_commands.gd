extends RefCounted
## Issue #6: placement/move/remove/undo/redo commands, rules, ledger (04 §8, 08 §4, 12 §3).

const Seeds := preload("res://tests/support/test_seeds.gd")


func _state(cash: int = -1) -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	if cash >= 0:
		s.ledger.cash_yen = cash
	return s


var _n := 0


func _cmd(kind: StringName, payload: Dictionary = {}) -> Dictionary:
	_n += 1
	var c := {"command_id": "c%d" % _n, "kind": kind}
	c.merge(payload)
	return c


func _place(cmds: GameCommands, type_id: String, x: int, y: int, r: int = 0) -> CommandResult:
	return cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": type_id, "x": x, "y": y, "rotation": r}))


func _layout(s: GameState) -> Dictionary:
	return {"snapshot": s.snapshot()["fixtures"], "cash": s.cash_yen}


# ------------------------------------------------------------------ rotation / access goldens

func test_access_cells_follow_rotation(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("shelf_general")
	var expect := [
		[0, [Vector2i(5, 5), Vector2i(5, 6)]],
		[1, [Vector2i(4, 6), Vector2i(5, 6)]],
		[2, [Vector2i(3, 5), Vector2i(3, 6)]],
		[3, [Vector2i(4, 4), Vector2i(5, 4)]],
	]
	for e in expect:
		t.eq(PlacementRules.access_candidates(def, 4, 5, e[0]), e[1] as Array[Vector2i], "front cells r%d" % e[0])
	t.eq(PlacementRules.rotate_edge("E", 1), "S")
	t.eq(PlacementRules.rotate_edge("W", 1), "N")
	t.eq(PlacementRules.access_candidates(s.fixtures.get_type("warmer_oden"), 4, 5, 0), [Vector2i(4, 4)] as Array[Vector2i], "1x1 oden front N")
	t.eq(PlacementRules.access_candidates(s.fixtures.get_type("freezer_ice"), 4, 5, 0).size(), 8, "2x2 ice: all four sides")


func test_1x2_rotates_to_2x1(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var r := _place(cmds, "shelf_general", 4, 5, 1)
	t.ok(r.ok, "place rotated")
	t.eq(s.grid.cells_of(r.data["instance_id"], s.fixtures), [Vector2i(4, 5), Vector2i(5, 5)] as Array[Vector2i], "occupies 2x1")


# ------------------------------------------------------------------ place

func test_place_charges_cost_and_records_capex(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var r := _place(cmds, "register_basic", 6, 4)
	t.ok(r.ok and r.code == &"OK")
	t.eq(r.data["instance_id"], "fx_0001")
	t.eq(s.cash_yen, 500000 - 90000, "register costs 90,000")
	t.eq(s.revision, 1)
	var tx := s.ledger.transactions[0]
	t.eq(tx["event_type"], "FIXTURE_PURCHASE")
	t.eq(tx["cash_delta_yen"], -90000)
	t.eq(tx["expense_delta_yen"], 0, "capex is not an operating expense")
	t.eq(s.time_sec, 0, "command phase does not advance the clock")
	t.eq(s.fixtures.get_type("register_basic")["placement_cost_yen"], 90000)


func test_place_rejection_table_changes_nothing(t, _tree) -> void:
	var s := _state(100000)
	var cmds := GameCommands.new(s)
	t.ok(_place(cmds, "shelf_general", 4, 5).ok, "baseline ok (40,000)")
	var before := _layout(s)
	var rev := s.revision
	var cases := [
		["overlap", "shelf_general", 4, 6, 0, &"OCCUPIED"],
		["outside west", "shelf_general", -1, 2, 0, &"OUT_OF_BOUNDS"],
		["outside east", "shelf_general", 16, 2, 0, &"OUT_OF_BOUNDS"],
		["1x2 past bottom", "shelf_general", 8, 11, 0, &"OUT_OF_BOUNDS"],
		["rotated past right", "shelf_general", 15, 2, 1, &"OUT_OF_BOUNDS"],
		["entrance tile", "shelf_general", 0, 5, 0, &"ENTRANCE_BLOCKED"],
		["no money", "fridge_drink", 9, 2, 0, &"INSUFFICIENT_CASH"],
		["unknown type", "vending", 9, 2, 0, &"INVALID_OPERATION"],
		["bad rotation", "shelf_general", 9, 2, 4, &"INVALID_OPERATION"],
	]
	for c in cases:
		var r := _place(cmds, c[1], c[2], c[3], c[4])
		t.ok(not r.ok, c[0] + " rejected")
		t.eq(r.code, c[5], c[0])
		t.eq(r.new_revision, rev, c[0] + " keeps revision")
	t.eq(_layout(s), before, "no rejected placement changed fixtures or cash")
	t.eq(s.ledger.transactions.size(), 1, "no ledger rows for rejections")


func test_shelf_with_no_access_is_rejected(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.eq(_place(cmds, "warmer_oden", 5, 0, 0).code, &"UNREACHABLE_ACCESS", "oden front N at y=0 leaves the store")
	t.eq(_place(cmds, "shelf_general", 15, 2, 0).code, &"UNREACHABLE_ACCESS", "E front at x=16 is outside the store")
	t.eq(_place(cmds, "register_basic", 15, 2, 0).code, &"REGISTER_BLOCKED", "a register with no access reports REGISTER_BLOCKED")
	t.ok(_place(cmds, "shelf_general", 15, 2, 2).ok, "rotated so the W front is inside the store")
	t.eq(s.grid.instances.size(), 1, "only the valid one was built")


func test_placing_next_to_a_register_cannot_block_its_only_access(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	# Register at the right edge: its E front would be x=16 (outside), so use W-facing space.
	var reg := _place(cmds, "register_basic", 14, 4, 0)   # front E = x=15, y=4..5
	t.ok(reg.ok, "register with E front (15,4),(15,5)")
	var one := _place(cmds, "warmer_oden", 15, 4, 2)      # takes (15,4)
	t.ok(one.ok, "one access tile left")
	var two := _place(cmds, "warmer_oden", 15, 5, 2)      # would take the last one
	t.eq(two.code, &"REGISTER_BLOCKED", "last access tile of a register is protected")
	t.eq(s.grid.instances.size(), 2)


func test_commands_rejected_outside_setup(t, _tree) -> void:
	for st in [GameState.OPEN, GameState.CLOSING, GameState.PAYMENT_BLOCKED]:
		var s := _state()
		var cmds := GameCommands.new(s)
		var placed := _place(cmds, "shelf_general", 4, 5)
		var rev := s.revision
		s.business_state = st
		s.speed_setting = 0   # OPEN + pause is NOT a construction window
		var before := _layout(s)
		var r := _place(cmds, "shelf_general", 8, 8)
		t.eq(r.code, &"NOT_IN_SETUP", "place in %s" % st)
		t.eq(cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": placed.data["instance_id"], "x": 8, "y": 8, "rotation": 0})).code, &"NOT_IN_SETUP")
		t.eq(cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": placed.data["instance_id"]})).code, &"NOT_IN_SETUP")
		t.eq(cmds.execute(_cmd(&"UNDO_LAYOUT")).code, &"NOT_IN_SETUP")
		t.eq(cmds.validate_placement("shelf_general", 8, 8, 0).code, &"NOT_IN_SETUP", "preview also refuses")
		t.eq(s.revision, rev)
		t.eq(_layout(s), before, "nothing changed in %s" % st)


func test_setup_allows_building_while_clock_is_stopped(t, _tree) -> void:
	var s := _state()
	t.eq(s.speed_setting, 0)
	t.ok(_place(GameCommands.new(s), "shelf_general", 4, 5).ok)
	t.eq(s.time_sec, 0)


func test_no_register_is_still_buildable(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.ok(_place(cmds, "shelf_general", 4, 5).ok, "shelf without any register")
	t.eq(s.grid.instances.size(), 1)


func test_preview_is_read_only(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var p := cmds.validate_placement("register_basic", 6, 4, 0)
	t.ok(p.ok)
	t.eq(p.cost_yen, 90000)
	t.eq(p.cells, [Vector2i(6, 4), Vector2i(6, 5)] as Array[Vector2i])
	t.eq(p.access_cells, [Vector2i(7, 4), Vector2i(7, 5)] as Array[Vector2i])
	t.eq(s.cash_yen, 500000, "preview spends nothing")
	t.eq(s.revision, 0)
	t.eq(s.grid.instances.size(), 0)
	t.eq(cmds.validate_placement("register_basic", 6, 4, 0).code, &"OK", "repeatable")


func test_duplicate_command_id_is_idempotent(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var c := _cmd(&"PLACE_FIXTURE", {"type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0})
	t.ok(cmds.execute(c).ok)
	var again := cmds.execute(c)
	t.eq(again.code, &"ALREADY_APPLIED")
	t.eq(s.grid.instances.size(), 1)
	t.eq(s.cash_yen, 460000, "charged once")


# ------------------------------------------------------------------ move

func test_move_and_rotate_cost_nothing_and_validate(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var a: String = _place(cmds, "shelf_general", 4, 5).data["instance_id"]
	_place(cmds, "shelf_bread", 8, 5)
	var cash := s.cash_yen
	t.ok(cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": a, "x": 4, "y": 5, "rotation": 1})).ok, "rotate in place 1x2 -> 2x1")
	t.eq(s.grid.cells_of(a, s.fixtures), [Vector2i(4, 5), Vector2i(5, 5)] as Array[Vector2i])
	t.eq(s.grid.occupant_at(Vector2i(4, 6)), "", "old second cell freed")
	t.ok(cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": a, "x": 4, "y": 6, "rotation": 0})).ok, "move onto cells it partly vacated")
	t.eq(s.cash_yen, cash, "moves are free")
	var bad := [
		[{"x": 8, "y": 5, "rotation": 0}, &"OCCUPIED"],
		[{"x": 99, "y": 0, "rotation": 0}, &"OUT_OF_BOUNDS"],
		[{"x": 4, "y": 6, "rotation": 0}, &"INVALID_OPERATION"],
	]
	var snap := _layout(s)
	for b in bad:
		var p := {"instance_id": a}
		p.merge(b[0])
		t.eq(cmds.execute(_cmd(&"MOVE_FIXTURE", p)).code, b[1], "move %s" % str(b[0]))
	t.eq(_layout(s), snap, "failed moves change nothing")
	t.eq(cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": "ghost", "x": 1, "y": 1, "rotation": 0})).code, &"INVALID_OPERATION")


# ------------------------------------------------------------------ remove

func test_remove_returns_stock_to_backroom_and_refunds_nothing(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var id: String = _place(cmds, "fridge_drink", 6, 2).data["instance_id"]
	s.inventory_segments.append({
		"segment_id": "seg1", "lot_id": "lot1", "sku_id": "drink_001", "unit_cost_yen": 75, "expires_at_sec": null,
		"physical_qty": 6, "reserved_qty": 0, "location": {"kind": "FIXTURE", "fixture_id": id, "slot_id": "row0"},
	})
	var cash := s.cash_yen
	t.ok(cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": id})).ok)
	t.eq(s.cash_yen, cash, "no refund (balance default 0)")
	t.eq(s.inventory_segments[0]["location"], {"kind": "BACKROOM"}, "stock goes to the backroom")
	t.eq(s.inventory_segments[0]["physical_qty"], 6, "stock is not lost")
	t.eq(s.grid.instances.size(), 0)
	t.ok(cmds.execute(_cmd(&"UNDO_LAYOUT")).ok, "undo remove")
	t.eq(s.inventory_segments[0]["location"], {"kind": "FIXTURE", "fixture_id": id, "slot_id": "row0"}, "stock back on the shelf")


func test_remove_refused_while_reserved(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var id: String = _place(cmds, "fridge_drink", 6, 2).data["instance_id"]
	s.inventory_segments.append({
		"segment_id": "seg1", "lot_id": "lot1", "sku_id": "drink_001", "unit_cost_yen": 75, "expires_at_sec": null,
		"physical_qty": 6, "reserved_qty": 1, "location": {"kind": "FIXTURE", "fixture_id": id, "slot_id": "row0"},
	})
	s.reservations.append({"reservation_id": "r1", "segment_id": "seg1", "qty": 1})
	t.eq(cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": id})).code, &"RESERVATION_ACTIVE")
	t.eq(cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": id, "x": 9, "y": 9, "rotation": 0})).code, &"RESERVATION_ACTIVE")
	t.eq(s.grid.instances.size(), 1)


func test_last_register_can_be_removed_in_setup(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var id: String = _place(cmds, "register_basic", 6, 4).data["instance_id"]
	t.ok(cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": id})).ok)


# ------------------------------------------------------------------ undo / redo

func test_place_undo_redo_money_and_occupancy(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var start := _layout(s)
	_place(cmds, "register_basic", 6, 4)
	var placed := _layout(s)
	t.eq(s.cash_yen, 410000)
	t.ok(cmds.execute(_cmd(&"UNDO_LAYOUT")).ok)
	t.eq(_layout(s), start, "undo restores cash and occupancy")
	t.eq(s.grid.occupant_at(Vector2i(6, 4)), "")
	t.eq(s.ledger.transactions.size(), 2, "history is kept; undo is a REVERSAL row")
	t.eq(s.ledger.transactions[1]["event_type"], "REVERSAL")
	t.eq(s.ledger.transactions[1]["cash_delta_yen"], 90000)
	t.ok(cmds.execute(_cmd(&"REDO_LAYOUT")).ok)
	t.eq(_layout(s), placed, "redo buys it again")
	t.eq(s.ledger.transactions.size(), 3)
	var net := 0
	for tx in s.ledger.transactions:
		net += tx["cash_delta_yen"]
	t.eq(500000 + net, s.cash_yen, "ledger sum equals cash")


func test_place_move_undo_redo_states_match(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var s0 := _layout(s)
	var id: String = _place(cmds, "shelf_general", 4, 5).data["instance_id"]
	var s1 := _layout(s)
	cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": id, "x": 9, "y": 3, "rotation": 1}))
	var s2 := _layout(s)
	t.ok(cmds.execute(_cmd(&"UNDO_LAYOUT")).ok)
	t.eq(_layout(s), s1, "undo move")
	t.ok(cmds.execute(_cmd(&"UNDO_LAYOUT")).ok)
	t.eq(_layout(s), s0, "undo place")
	t.ok(cmds.execute(_cmd(&"REDO_LAYOUT")).ok)
	t.eq(_layout(s), s1, "redo place")
	t.ok(cmds.execute(_cmd(&"REDO_LAYOUT")).ok)
	t.eq(_layout(s), s2, "redo move")
	t.eq(cmds.execute(_cmd(&"REDO_LAYOUT")).code, &"INVALID_OPERATION", "nothing left to redo")


func test_redo_is_revalidated_with_current_cash_and_space(t, _tree) -> void:
	var s := _state(100000)
	var cmds := GameCommands.new(s)
	_place(cmds, "register_basic", 6, 4)          # 90,000 -> 10,000 left
	cmds.execute(_cmd(&"UNDO_LAYOUT"))             # back to 100,000
	s.ledger.cash_yen -= 50000                     # cash drops by other means
	var r := cmds.execute(_cmd(&"REDO_LAYOUT"))
	t.eq(r.code, &"INSUFFICIENT_CASH", "redo re-checks money")
	t.eq(s.grid.instances.size(), 0)
	s.ledger.cash_yen += 50000
	s.grid.add_instance({"instance_id": "intruder", "type_id": "shelf_general", "x": 6, "y": 4, "rotation": 0, "enabled": true}, s.fixtures)
	t.eq(cmds.execute(_cmd(&"REDO_LAYOUT")).code, &"OCCUPIED", "redo re-checks space")
	t.eq(s.cash_yen, 100000, "failed redo spends nothing")


func test_new_edit_clears_redo_and_other_commands_clear_history(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_place(cmds, "shelf_general", 4, 5)
	cmds.execute(_cmd(&"UNDO_LAYOUT"))
	t.ok(s.layout_history.can_redo())
	_place(cmds, "shelf_bread", 8, 5)
	t.ok(not s.layout_history.can_redo(), "a new edit drops redo")
	t.ok(s.layout_history.can_undo())
	t.ok(cmds.execute(_cmd(&"SET_SPEED", {"speed": 0})).ok)
	t.ok(not s.layout_history.can_undo(), "a non-layout command ends the session")
	t.eq(cmds.execute(_cmd(&"UNDO_LAYOUT")).code, &"INVALID_OPERATION", "nothing to undo")
	_place(cmds, "shelf_snack", 12, 5)
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	SimulationRunner.new(s).process_frame(1.0)
	t.ok(not s.layout_history.can_undo(), "time passing clears history")


func test_undo_twice_never_double_refunds(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	_place(cmds, "register_basic", 6, 4)
	cmds.execute(_cmd(&"UNDO_LAYOUT"))
	t.ok(not cmds.execute(_cmd(&"UNDO_LAYOUT")).ok, "second undo has nothing to undo")
	t.eq(s.cash_yen, 500000, "refunded exactly once")
	t.ok(s.cash_yen >= 0)


func test_property_random_edits_keep_invariants(t, _tree) -> void:
	var s := _state(2000000)
	var cmds := GameCommands.new(s)
	var rng := Lcg32.new(Seeds.VISUALS)
	var types := ["shelf_general", "register_basic", "warmer_oden", "freezer_ice", "fridge_drink"]
	for i in 300:
		var roll := int(rng.uniform_0_1() * 6.0)
		var x := int(rng.uniform_0_1() * 16.0)
		var y := int(rng.uniform_0_1() * 12.0)
		var r := int(rng.uniform_0_1() * 4.0)
		var ids := s.grid.instances.keys()
		ids.sort()
		var pick: String = ids[int(rng.uniform_0_1() * ids.size())] if not ids.is_empty() else ""
		match roll:
			0, 1:
				_place(cmds, types[int(rng.uniform_0_1() * types.size())], x, y, r)
			2:
				if pick != "":
					cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": pick, "x": x, "y": y, "rotation": r}))
			3:
				if pick != "":
					cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": pick}))
			4:
				cmds.execute(_cmd(&"UNDO_LAYOUT"))
			5:
				cmds.execute(_cmd(&"REDO_LAYOUT"))
		_assert_invariants(t, s, i)


func _assert_invariants(t, s: GameState, step: int) -> void:
	var seen := {}
	for id in s.grid.instances:
		for c in s.grid.cells_of(id, s.fixtures):
			t.ok(s.grid.in_bounds(c), "step %d: %s inside store" % [step, id])
			t.ok(not seen.has(c), "step %d: no overlap at %s" % [step, str(c)])
			t.ok(not s.grid.entrance_tiles.has(c), "step %d: entrance free" % step)
			seen[c] = id
			t.eq(s.grid.occupant_at(c), id, "step %d: occupancy map agrees" % step)
	t.eq(seen.size(), s.grid._occupancy.size(), "step %d: no stale occupancy" % step)
	t.ok(s.cash_yen >= 0, "step %d: cash never negative" % step)
	var net := 0
	for tx in s.ledger.transactions:
		net += tx["cash_delta_yen"]
	t.eq(2000000 + net, s.cash_yen, "step %d: ledger sums to cash" % step)
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		var inst: Dictionary = s.grid.instances[id]
		var access := PlacementRules.walkable_access(s.grid, PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"]), s.grid.blocked_cells())
		t.ok(def["access_edges"].is_empty() or not access.is_empty(), "step %d: %s keeps an access tile" % [step, id])
