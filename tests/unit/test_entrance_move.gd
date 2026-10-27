extends RefCounted
## Issue #121: moving the entrance — only onto an outer wall (not a corner), only while closed, for a building cost;
## refused on a fixture or when a fixture or the register would be cut off; customers then come in through the new
## door; the new entrance survives a save.

const Run := preload("res://tests/support/basket_run.gd")


func test_where_the_entrance_can_go(t, _tree) -> void:
	t.eq(EntranceRules.tiles_at(16, 12, 3, 11), [Vector2i(3, 11), Vector2i(4, 11)] as Array[Vector2i], "the front wall, along it")
	t.eq(EntranceRules.tiles_at(16, 12, 15, 4), [Vector2i(15, 4), Vector2i(15, 5)] as Array[Vector2i], "the right wall, along it")
	t.eq(EntranceRules.tiles_at(16, 12, 0, 0), [] as Array[Vector2i], "never a corner")
	t.eq(EntranceRules.tiles_at(16, 12, 14, 11), [] as Array[Vector2i], "nor touching one")
	t.eq(EntranceRules.tiles_at(16, 12, 5, 5), [] as Array[Vector2i], "only on an outer wall")
	var all := EntranceRules.candidates(16, 12)
	t.ok(all.all(func(at): return not EntranceRules.tiles_at(16, 12, at.x, at.y).is_empty()), "every candidate is a valid place")
	t.eq(EntranceRules.label(16, 12, Vector2i(3, 11)), "手前の壁 4〜5列目")


func test_moving_the_entrance(t, _tree) -> void:
	var s := Run.new_state(200.0)
	var cmds := Run.place_layout(s)
	var old := s.grid.entrance_tiles.duplicate()
	var r := cmds.execute({"command_id": "m0", "kind": &"MOVE_ENTRANCE", "x": 5, "y": 5})
	t.ok(not r.ok and r.message_key == &"entrance_not_on_wall", "not inside the store")
	r = cmds.execute({"command_id": "m1", "kind": &"MOVE_ENTRANCE", "x": old[0].x, "y": old[0].y})
	t.ok(not r.ok and r.message_key == &"entrance_unchanged", "not where it already is")
	var moved_to := Vector2i(-1, -1)
	var cash := s.ledger.cash_yen
	for at in EntranceRules.candidates(s.grid.width, s.grid.height):
		if moved_to == Vector2i(-1, -1) and at.y == s.grid.height - 1 and absi(at.x - old[0].x) >= 4:
			if cmds.execute({"command_id": "m_%d_%d" % [at.x, at.y], "kind": &"MOVE_ENTRANCE", "x": at.x, "y": at.y}).ok:
				moved_to = at
	t.ok(moved_to != Vector2i(-1, -1), "moved along the front wall")
	t.eq(s.grid.entrance_tiles[0], moved_to, "the entrance is there now")
	t.eq(cash - s.ledger.cash_yen, 150000, "the building work is paid")
	t.eq(s.snapshot()["entrance_tiles"][0], moved_to, "the screen follows")
	var saved := SaveGame.to_dict(s, "door", "2026-10-28T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).grid.entrance_tiles, s.grid.entrance_tiles, "the new entrance survives a save")
	var r2 := Run.run_days(s, cmds, 1)
	t.ok(int(r2["units"][0]) > 0, "customers come in through the new door and buy (%d)" % int(r2["units"][0]))
	t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the store stays consistent")
	r = cmds.execute({"command_id": "m_open", "kind": &"MOVE_ENTRANCE", "x": old[0].x, "y": old[0].y})
	t.ok(not r.ok, "not while open")


func test_a_door_that_would_cut_off_a_shelf_is_refused(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := GameCommands.new(s)
	t.ok(cmds.execute({"command_id": "p1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_snack", "x": 0, "y": 3, "rotation": 0}).ok, "a shelf on the left wall")
	var r := cmds.execute({"command_id": "d1", "kind": &"MOVE_ENTRANCE", "x": 0, "y": 3})
	t.ok(not r.ok and r.message_key == &"entrance_blocked", "not through a fixture")
	t.ok(CommandMessages.text(&"INVALID_OPERATION", &"entrance_cuts_off").contains("たどり着けなく"), "the reason is told")
