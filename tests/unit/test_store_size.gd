extends RefCounted
## Issue #145: store sizes (small 12x10, medium 16x12, large 20x16) chosen before the first opening, and extending
## one size up while closed. The entrance wall stays: rows move down by the added height, columns stay.

const Run := preload("res://tests/support/basket_run.gd")


func _state() -> GameState:
	return Run.new_state(100.0)


func test_sizes_and_the_current_one(t, _tree) -> void:
	var s := _state()
	var ids: Array = StoreSize.all(s.balance).map(func(x): return x["size_id"])
	t.eq(ids, ["small", "medium", "large"], "three sizes")
	t.eq(String(StoreSize.of_grid(s.balance, s.grid)["size_id"]), "medium", "the store starts at the medium size")
	t.eq(String(StoreSize.next(s.balance, s.grid)["size_id"]), "large", "the next size up")


func test_choose_a_size_before_opening(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	var r := cmds.execute({"command_id": "p1", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 11, "y": 9, "rotation": 2})
	t.ok(r.ok, "a register near the door")
	var cash := s.cash_yen
	r = cmds.execute({"command_id": "sz1", "kind": &"SET_STORE_SIZE", "size_id": "small"})
	t.ok(r.ok, "small chosen: %s" % r.message_key)
	t.eq([s.grid.width, s.grid.height], [12, 10])
	t.eq(s.cash_yen, cash, "choosing is free")
	t.eq(s.grid.entrance_tiles[0].y, 9, "the entrance stays on the front wall")
	var reg: Dictionary = s.grid.instances.values()[0]
	t.eq([int(reg["x"]), int(reg["y"])], [11, 7], "the register keeps its distance to the entrance wall")
	r = cmds.execute({"command_id": "sz2", "kind": &"SET_STORE_SIZE", "size_id": "huge"})
	t.ok(not r.ok, "an unknown size is refused")
	cmds.execute({"command_id": "p2", "kind": &"PLACE_FIXTURE", "type_id": "shelf_general", "x": 1, "y": 0, "rotation": 0})
	r = cmds.execute({"command_id": "sz3", "kind": &"SET_STORE_SIZE", "size_id": "medium"})
	t.ok(r.ok, "growing back to medium is fine")
	t.eq([s.grid.width, s.grid.height], [16, 12])


func test_a_size_the_fixtures_do_not_fit_is_refused(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.ok(cmds.execute({"command_id": "p1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_general", "x": 14, "y": 2, "rotation": 0}).ok, "a shelf at the far right")
	var r := cmds.execute({"command_id": "sz", "kind": &"SET_STORE_SIZE", "size_id": "small"})
	t.ok(not r.ok and r.message_key == &"fixtures_do_not_fit", "the small store would cut it off: %s" % r.message_key)
	t.eq(s.grid.width, 16, "nothing changed")


func test_extend_while_closed(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner := SimulationRunner.new(s)
	for i in 50:
		runner._run_step()
	var r := cmds.execute({"command_id": "sz", "kind": &"SET_STORE_SIZE", "size_id": "large"})
	t.ok(not r.ok and r.message_key == &"store_size_locked", "after opening the size is not a free choice")
	r = cmds.execute({"command_id": "ex1", "kind": &"EXPAND_STORE"})
	t.ok(not r.ok, "no building work while open")
	s.business_state = GameState.SETUP
	s.customers.clear()
	s.reservations.clear()
	var before := {}
	for id in s.grid.instances:
		before[id] = Vector2i(int(s.grid.instances[id]["x"]), int(s.grid.instances[id]["y"]))
	var cash := s.cash_yen
	r = cmds.execute({"command_id": "ex2", "kind": &"EXPAND_STORE"})
	t.ok(r.ok, "extended to large: %s %s" % [r.code, r.message_key])
	t.eq([s.grid.width, s.grid.height], [20, 16])
	t.eq(cash - s.cash_yen, int(StoreSize.find(s.balance, "large")["expand_cost_yen"]), "the building work is paid")
	for id in before:
		var now := Vector2i(int(s.grid.instances[id]["x"]), int(s.grid.instances[id]["y"]))
		t.eq(now, before[id] + Vector2i(0, 4), "%s moved with the rows" % id)
	t.ok(not cmds.execute({"command_id": "ex3", "kind": &"EXPAND_STORE"}).ok, "large is the biggest")
	t.ok(cmds.execute({"command_id": "room", "kind": &"PLACE_FIXTURE", "type_id": "staff_room_l", "x": 16, "y": 0, "rotation": 0}).ok, "a large store takes the large staff room")
	# customers still find their way
	cmds.execute({"command_id": "open2", "kind": &"START_BUSINESS"})
	s.balance["staff_enabled"] = false
	var bought := int(s.visit_stats["purchased"])
	for i in 6000:
		runner._run_step()
	t.ok(int(s.visit_stats["purchased"]) > bought, "the bigger store sells")
	var saved := SaveGame.to_dict(s, "big", "2026-10-25T00:00:00Z")
	var lr := SaveGame.from_dict(saved, s.balance, s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).grid.width, 20, "the size survives a save")
