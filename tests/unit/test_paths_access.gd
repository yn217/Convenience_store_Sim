extends RefCounted
## Issue #7: entrance reachability, shelf access, register service cell + queue, path cache.

const Seeds := preload("res://tests/support/test_seeds.gd")


## The layouts below are drawn around the west door (0,5)-(0,6), so this fixture pins that door explicitly.
## The default door is on the south wall and is covered by test_default_entrance_on_the_south_wall.
const WEST_DOOR: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 6)]


func _state() -> GameState:
	var s := _default_state()
	s.grid.entrance_tiles = WEST_DOOR.duplicate()
	return s


func _default_state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


## Puts fixtures straight into the grid (no validation) to build arbitrary starting layouts.
func _put(s: GameState, id: String, type_id: String, x: int, y: int, r: int = 0) -> void:
	assert(s.grid.add_instance({"instance_id": id, "type_id": type_id, "x": x, "y": y, "rotation": r, "enabled": true}, s.fixtures) == &"OK")


func _check(s: GameState, type_id: String, x: int, y: int, r: int = 0, ignore: String = "") -> PlacementResult:
	return PlacementRules.validate(s.grid, s.fixtures, type_id, x, y, r, 10000000, ignore, ignore.is_empty())


var _n := 0


func _cmd(kind: StringName, payload: Dictionary = {}) -> Dictionary:
	_n += 1
	var c := {"command_id": "p%d" % _n, "kind": kind}
	c.merge(payload)
	return c


# ------------------------------------------------------------------ BFS / paths

func test_distances_from_the_entrance(t, _tree) -> void:
	var s := _state()
	var d := PathService.distances(s.grid, {})
	t.eq(d[Vector2i(0, 5)], 0, "entrance tile")
	t.eq(d[Vector2i(0, 6)], 0, "second entrance tile")
	t.eq(d[Vector2i(3, 5)], 3)
	t.eq(d[Vector2i(15, 11)], 15 + 5, "far corner: 15 east, 5 south of the nearest entrance tile")
	t.eq(d.size(), 192, "every cell of an empty store is reachable")


## The new-game door is on the south wall (y = 11). Golden values for the default store: the door tiles are 0 steps,
## the cell straight in front of the first one is 1 step, the far corner (0,0) is 8 + 11 = 19 steps from the nearest
## door tile (8,11), and the whole 16x12 floor is reachable.
func test_default_entrance_on_the_south_wall(t, _tree) -> void:
	var s := _default_state()
	t.eq(s.grid.entrance_tiles, [Vector2i(8, 11), Vector2i(9, 11)] as Array[Vector2i], "default door on the south wall")
	var d := PathService.distances(s.grid, {})
	t.eq(d[Vector2i(8, 11)], 0, "door tile")
	t.eq(d[Vector2i(9, 11)], 0, "second door tile")
	t.eq(d[Vector2i(8, 10)], 1, "one step in from the door")
	t.eq(d[Vector2i(0, 0)], 8 + 11, "far corner (0,0): 8 west and 11 north of the door tile (8,11)")
	t.eq(d.size(), 192, "every cell of an empty store is reachable")


func test_path_is_shortest_and_deterministic(t, _tree) -> void:
	var s := _state()
	t.eq(PathService.find_path(s.grid, {}, Vector2i(0, 0), Vector2i(2, 2)),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)] as Array[Vector2i], "ties resolve N, E, S, W")
	var again := PathService.find_path(s.grid, {}, Vector2i(0, 0), Vector2i(2, 2))
	t.eq(again.size(), 5, "repeatable")
	t.eq(PathService.find_path(s.grid, {}, Vector2i(3, 3), Vector2i(3, 3)), [Vector2i(3, 3)] as Array[Vector2i], "start == goal")


func test_closed_loop_detour_around_an_obstacle(t, _tree) -> void:
	var s := _state()
	var blocked := {Vector2i(2, 5): true}
	var p := PathService.find_path(s.grid, blocked, Vector2i(0, 5), Vector2i(4, 5))
	t.eq(p, [Vector2i(0, 5), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5)] as Array[Vector2i], "north is tried first, so the detour goes over the top")
	t.ok(not p.has(Vector2i(2, 5)), "never through the obstacle")


func test_dead_end_and_unreachable_goals(t, _tree) -> void:
	var s := _state()
	var pocket := {Vector2i(9, 4): true, Vector2i(11, 4): true, Vector2i(10, 3): true, Vector2i(10, 5): true}
	t.eq(PathService.find_path(s.grid, pocket, Vector2i(0, 5), Vector2i(10, 4)), [] as Array[Vector2i], "sealed pocket has no path")
	t.eq(PathService.find_path(s.grid, pocket, Vector2i(0, 5), Vector2i(9, 4)), [] as Array[Vector2i], "blocked goal has no path")
	var d := PathService.distances(s.grid, pocket)
	t.ok(not d.has(Vector2i(10, 4)), "pocket is not in the reachability map")
	var dead_end := {}
	for y in range(0, 12):
		if y != 6:
			dead_end[Vector2i(6, y)] = true       # wall with a one-tile door at y=6
	var through := PathService.find_path(s.grid, dead_end, Vector2i(0, 6), Vector2i(10, 6))
	t.ok(not through.is_empty() and through.has(Vector2i(6, 6)), "one-tile corridor is passable")
	dead_end[Vector2i(6, 6)] = true
	t.eq(PathService.find_path(s.grid, dead_end, Vector2i(0, 6), Vector2i(10, 6)), [] as Array[Vector2i], "closing the door cuts the store in two")


func test_path_cache_recomputes_only_when_the_layout_changes(t, _tree) -> void:
	var s := _state()
	var svc := PathService.new()
	var cmds := GameCommands.new(s)
	svc.current_distances(s.grid)
	svc.current_distances(s.grid)
	t.eq(svc.recompute_count, 1, "cached while nothing changes")
	var id: String = cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0})).data["instance_id"]
	t.ok(not svc.current_distances(s.grid).has(Vector2i(4, 5)), "new fixture cell is no longer walkable")
	t.eq(svc.recompute_count, 2, "placement invalidates the cache")
	cmds.execute(_cmd(&"MOVE_FIXTURE", {"instance_id": id, "x": 9, "y": 2, "rotation": 1}))
	var d := svc.current_distances(s.grid)
	t.ok(d.has(Vector2i(4, 5)) and not d.has(Vector2i(9, 2)), "move frees the old cells and blocks the new ones")
	t.eq(svc.recompute_count, 3, "move invalidates the cache")
	cmds.execute(_cmd(&"REMOVE_FIXTURE", {"instance_id": id}))
	t.ok(svc.current_distances(s.grid).has(Vector2i(9, 2)))
	t.eq(svc.recompute_count, 4, "removal invalidates the cache")
	svc.current_distances(s.grid)
	t.eq(svc.recompute_count, 4, "and it is stable again")


# ------------------------------------------------------------------ shelf access

func test_shelf_facing_a_wall_cannot_be_placed_in_any_rotation(t, _tree) -> void:
	var s := _state()
	var cases := [
		["E front at the east wall", 15, 2, 0],
		["S front at the south wall (2x1)", 4, 11, 1],
		["W front at the west wall", 0, 2, 2],
		["N front at the north wall (2x1)", 4, 0, 3],
	]
	for c in cases:
		var r := _check(s, "shelf_general", c[1], c[2], c[3])
		t.eq(r.code, &"UNREACHABLE_ACCESS", c[0])
		t.eq(r.message_key, &"no_access_tile", c[0])
	t.ok(_check(s, "shelf_general", 14, 2, 0).ok, "one tile off the wall works")
	t.ok(_check(s, "shelf_general", 4, 10, 1).ok, "2x1 facing S with room")
	t.ok(_check(s, "shelf_general", 4, 1, 3).ok, "2x1 facing N with room")
	t.ok(_check(s, "shelf_general", 1, 2, 2).ok, "facing W with room")


func test_free_but_unreachable_access_is_refused(t, _tree) -> void:
	var s := _state()
	# (14,5),(14,6) are free but sealed in by four ovens; the shelf at (13,5) would face them.
	for p in [["a", 14, 4], ["b", 14, 7], ["c", 15, 5], ["d", 15, 6]]:
		_put(s, p[0], "warmer_oden", p[1], p[2], 0)
	var r := _check(s, "shelf_general", 13, 5, 0)
	t.eq(r.code, &"UNREACHABLE_ACCESS")
	t.eq(r.message_key, &"access_unreachable", "free tiles exist, but customers cannot walk to them")
	t.ok(_check(s, "shelf_general", 4, 5, 0).ok, "an open spot is fine")


func test_multi_side_access_for_the_ice_case(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("freezer_ice")
	var reach := PathService.distances(s.grid, {})
	t.eq(AccessService.reachable_access(s.grid, def, 5, 5, 0, reach).size(), 8, "2x2 ice case: two tiles on each side")
	var r := _check(s, "freezer_ice", 14, 10, 0)
	t.ok(r.ok, "still reachable from its free sides in a corner")
	t.eq(r.access_cells.size(), 4, "only the in-store N and W sides remain: " + str(r.access_cells))


func test_access_tiles_are_ordered_by_distance_then_y_then_x(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("freezer_ice")
	var reach := PathService.distances(s.grid, {})
	var cells := AccessService.reachable_access(s.grid, def, 5, 5, 0, reach)
	for i in range(1, cells.size()):
		var a: Vector2i = cells[i - 1]
		var b: Vector2i = cells[i]
		t.ok(reach[a] < reach[b] or (reach[a] == reach[b] and (a.y < b.y or (a.y == b.y and a.x < b.x))), "ordered %s before %s" % [str(a), str(b)])


func test_rotated_shelves_report_their_front_tiles(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("shelf_general")
	var reach := PathService.distances(s.grid, {})
	var expect := [
		[0, [Vector2i(5, 5), Vector2i(5, 6)]],
		[1, [Vector2i(4, 6), Vector2i(5, 6)]],
		[2, [Vector2i(3, 5), Vector2i(3, 6)]],
		[3, [Vector2i(4, 4), Vector2i(5, 4)]],
	]
	for e in expect:
		var got := AccessService.reachable_access(s.grid, def, 4, 5, e[0], reach)
		got.sort()
		var want: Array = e[1]
		want.sort()
		t.eq(got, want as Array[Vector2i], "reachable front r%d" % e[0])


# ------------------------------------------------------------------ the only corridor

func _walled_store() -> GameState:
	# A two-tile-thick wall of ice cases at x=8..9 with a gap at y=4..7; register on the far side.
	var s := _state()
	for p in [["w1", 8, 0], ["w2", 8, 2], ["w3", 8, 8], ["w4", 8, 10]]:
		_put(s, p[0], "freezer_ice", p[1], p[2])
	_put(s, "reg", "register_basic", 12, 5, 0)
	return s


func test_blocking_the_only_corridor_to_the_register_is_refused(t, _tree) -> void:
	var s := _walled_store()
	var reach := PathService.distances(s.grid, s.grid.blocked_cells())
	t.ok(reach.has(Vector2i(13, 5)), "register front reachable through the gap")
	t.ok(_check(s, "freezer_ice", 8, 4).ok, "closing half of the gap leaves a passage")
	_put(s, "w5", "freezer_ice", 8, 4)
	var seal := _check(s, "freezer_ice", 8, 6)
	t.eq(seal.code, &"REGISTER_BLOCKED", "sealing the last gap is refused")
	t.eq(seal.message_key, &"blocks_other_access")
	t.eq(s.grid.instances.size(), 6, "validate never mutates")


func test_moving_a_fixture_into_the_corridor_is_checked_too(t, _tree) -> void:
	var s := _walled_store()
	_put(s, "w5", "freezer_ice", 8, 4)
	_put(s, "free", "freezer_ice", 2, 8)
	t.eq(_check(s, "freezer_ice", 8, 6, 0, "free").code, &"REGISTER_BLOCKED", "a move that would seal the wall is refused")
	t.ok(_check(s, "freezer_ice", 3, 8, 0, "free").ok, "a harmless move is fine")
	var away := _check(s, "freezer_ice", 3, 3, 0, "w5")
	t.ok(away.ok, "moving a wall piece out of the way opens the corridor further")


func test_no_register_means_no_register_reachability_requirement(t, _tree) -> void:
	var s := _state()
	for p in [["w1", 8, 0], ["w2", 8, 2], ["w3", 8, 4], ["w4", 8, 6], ["w5", 8, 8], ["w6", 8, 10]]:
		_put(s, p[0], "freezer_ice", p[1], p[2])
	t.ok(_check(s, "shelf_general", 4, 5, 0).ok, "walling the store off is fine while nothing needs the far side")
	t.ok(_check(s, "shelf_general", 12, 5, 0).code != &"OK", "but a shelf on the sealed side cannot be reached")


# ------------------------------------------------------------------ register queue

func test_register_service_cell_and_queue_per_rotation(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("register_basic")
	var reach := PathService.distances(s.grid, {})
	var cases := [
		[0, 6, 4, Vector2i(7, 5), [Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)]],
		[1, 6, 4, Vector2i(6, 5), [Vector2i(6, 5), Vector2i(6, 6), Vector2i(6, 7)]],
		[2, 6, 4, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5)]],
		[3, 6, 4, Vector2i(6, 3), [Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1)]],
	]
	for c in cases:
		var plan := AccessService.register_plan(s.grid, def, c[1], c[2], c[0], {}, reach)
		t.eq(plan["slots"], 3, "3 slots r%d" % c[0])
		t.eq(plan["service_cell"], c[3], "service cell r%d" % c[0])
		t.eq(plan["queue_cells"], c[4] as Array[Vector2i], "queue line r%d runs along the front normal" % c[0])


func test_register_queue_is_cut_by_walls_and_fixtures(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("register_basic")
	var near_wall := AccessService.register_plan(s.grid, def, 13, 4, 0, {}, PathService.distances(s.grid, {}))
	t.eq(near_wall["slots"], 2, "the east wall leaves room for two")
	t.eq(near_wall["service_cell"], Vector2i(14, 5), "same slots -> the cell nearer the entrance")
	_put(s, "block", "warmer_oden", 15, 5, 0)
	var blocked := s.grid.blocked_cells()
	var plan := AccessService.register_plan(s.grid, def, 13, 4, 0, blocked, PathService.distances(s.grid, blocked))
	t.eq(plan["slots"], 2)
	t.eq(plan["service_cell"], Vector2i(14, 4), "the blocked line loses; the longer one wins")
	t.eq(plan["queue_cells"], [Vector2i(14, 4), Vector2i(15, 4)] as Array[Vector2i])


func test_register_needs_a_free_front_and_keeps_its_queue(t, _tree) -> void:
	var s := _state()
	var cmds := GameCommands.new(s)
	t.eq(cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": "register_basic", "x": 15, "y": 4, "rotation": 0})).code, &"REGISTER_BLOCKED", "register facing the wall")
	t.ok(cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": "register_basic", "x": 6, "y": 4, "rotation": 0})).ok)
	# Blocking the whole front of the register with its own queue line starting tile is refused
	# once both service candidates would be gone.
	t.ok(cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": "warmer_oden", "x": 7, "y": 4, "rotation": 2})).ok, "one front tile can be used")
	var last := cmds.execute(_cmd(&"PLACE_FIXTURE", {"type_id": "warmer_oden", "x": 7, "y": 5, "rotation": 2}))
	t.eq(last.code, &"REGISTER_BLOCKED", "the last front tile is protected")
	t.eq(last.message_key, &"blocks_other_access")


func test_register_keeps_a_queue_after_a_partial_block(t, _tree) -> void:
	var s := _state()
	var def := s.fixtures.get_type("register_basic")
	_put(s, "reg", "register_basic", 13, 4, 0)
	var r := _check(s, "warmer_oden", 14, 4, 2)
	t.ok(r.ok, "a block on one of the two front tiles is allowed while one stays open")
	var reach := PathService.distances(s.grid, s.grid.blocked_cells())
	t.ok(int(AccessService.register_plan(s.grid, def, 13, 4, 0, s.grid.blocked_cells(), reach)["slots"]) >= 1)
