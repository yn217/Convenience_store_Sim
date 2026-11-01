extends RefCounted
## The sample/bench layout (data/layouts/sample_store_v1.json) must place all 20 fixtures through the real
## placement rules, and every access tile of every fixture must be reachable from the entrance.

const Seeds := preload("res://tests/support/test_seeds.gd")
const SampleLayout := preload("res://tools/sample_layout.gd")
const LAYOUT_PATH := "res://data/layouts/sample_store_v1.json"


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func test_layout_file_has_20_placements(t, _tree) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	t.ok(typeof(parsed) == TYPE_DICTIONARY and parsed.has("placements"), "layout file parses")
	t.eq(parsed["placements"].size(), 20, "exactly 20 fixtures (bench condition)")
	t.eq(SampleLayout.placements().size(), 20, "loader returns the file's placements")
	t.eq(SampleLayout.placements()[0][0], parsed["placements"][0]["type_id"], "loader reads the file, not the fallback")


func test_layout_places_all_and_access_reachable(t, _tree) -> void:
	var s := _state()
	s.ledger.cash_yen = 5000000   # the bench and capture tools fund the sample store the same way
	var cmds := GameCommands.new(s)
	var n := 0
	var placed := 0
	for p in SampleLayout.placements():
		n += 1
		var r: CommandResult = cmds.execute({"command_id": "sl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
		t.ok(r.ok, "place %s at (%d,%d) r%d" % [p[0], p[1], p[2], p[3]])
		if r.ok:
			placed += 1
	t.eq(placed, 20, "all 20 placed through PLACE_FIXTURE")
	t.eq(s.grid.instances.size(), 20, "20 instances on the grid")

	var blocked := s.grid.blocked_cells()
	var reach := PathService.distances(s.grid, blocked)
	for c in [Vector2i(8, 10), Vector2i(9, 10), Vector2i(8, 11), Vector2i(9, 11)]:
		t.ok(not s.grid.is_blocked(c), "door and front-of-door tile %s stay free" % c)
	for id in s.grid.instances:
		var inst: Dictionary = s.grid.instances[id]
		var def := s.fixtures.get_type(inst["type_id"])
		if def["access_edges"].is_empty():
			continue
		var cands := PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"])
		for c in PlacementRules.walkable_access(s.grid, cands, blocked):
			t.ok(reach.has(c), "%s %s access %s reachable from the entrance" % [id, inst["type_id"], c])
		t.ok(not AccessService.reachable_access(s.grid, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty(), "%s %s has a reachable access tile" % [id, inst["type_id"]])
