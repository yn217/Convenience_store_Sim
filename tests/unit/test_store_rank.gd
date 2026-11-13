extends RefCounted
## Store rank (StoreRank, user's decision 2026-11-13): the rank from revenue and reputation, what each rank opens, the
## command gate in the game, the rank-up event and the save.

const Run := preload("res://tests/support/basket_run.gd")


func test_the_rank_data_covers_every_fixture_once(t, _tree) -> void:
	var problems: Array[String] = []
	var ranks := StoreRank.parse(JSON.parse_string(FileAccess.get_file_as_string(StoreRank.DATA_PATH)), problems)
	t.eq(problems, [] as Array[String], "the rank file is valid")
	t.eq(ranks.size(), 5, "★1 to ★5")
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	for type_id in fixtures.types:
		t.ok(ranks.any(func(r): return (r["fixtures"] as Array).has(type_id)), "%s is opened by a rank" % type_id)
	for r in ranks:
		for f in r["fixtures"]:
			t.ok(fixtures.types.has(f), "%s is a fixture type" % f)
	for i in range(1, ranks.size()):
		t.ok(int(ranks[i]["revenue_yen"]) > int(ranks[i - 1]["revenue_yen"]) and int(ranks[i]["reputation"]) > int(ranks[i - 1]["reputation"]), "each rank asks more")


func test_rank_needs_both_revenue_and_reputation(t, _tree) -> void:
	t.eq(StoreRank.qualified(0, 50), 1)
	t.eq(StoreRank.qualified(1000000, 52), 2)
	t.eq(StoreRank.qualified(1000000, 51), 1, "revenue alone is not enough")
	t.eq(StoreRank.qualified(100000000, 54), 2, "reputation holds the rank back")
	t.eq(StoreRank.qualified(100000000, 100), 5)
	t.eq(StoreRank.rank_for("bakery_oven"), 3)
	t.eq(StoreRank.rank_for("open_store"), 5)
	t.eq(StoreRank.rank_for("register_basic"), 1)
	t.eq(StoreRank.locked(4), {"open_store": 5}, "at ★4 only the second store is closed")


func test_the_game_refuses_what_the_rank_has_not_opened(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	s.rank_gating = true
	var r := cmds.execute({"command_id": "c1", "kind": &"PLACE_FIXTURE", "type_id": "crane_game", "x": 2, "y": 9, "rotation": 0})
	t.ok(not r.ok and r.message_key == &"rank_locked_4", "a crane game waits for ★4: %s" % r.message_key)
	t.ok(not cmds.execute({"command_id": "c2", "kind": &"START_PROMOTION", "def_id": "x", "days": 3}).ok, "promotions wait for ★2")
	var placed := cmds.execute({"command_id": "c3", "kind": &"PLACE_FIXTURE", "type_id": "shelf_snack", "x": 2, "y": 9, "rotation": 0})
	t.ok(placed.ok or placed.message_key != &"rank_locked_1", "a ★1 fixture is never held back by the rank")
	s.progression_state["store_rank"] = 4
	r = cmds.execute({"command_id": "c4", "kind": &"PLACE_FIXTURE", "type_id": "crane_game", "x": 2, "y": 9, "rotation": 0})
	t.ok(r.message_key != &"rank_locked_4", "at ★4 the crane game is open: %s" % r.message_key)
	s.rank_gating = false
	s.progression_state["store_rank"] = 1
	t.ok(cmds.execute({"command_id": "c5", "kind": &"PLACE_FIXTURE", "type_id": "pizza_oven", "x": 12, "y": 2, "rotation": 0}).message_key != &"rank_locked_3", "without gating (tests, tools) nothing is held back")


func test_climbing_ranks_announces_each_once_and_keeps_the_rank(t, _tree) -> void:
	var s := Run.new_state(100.0)
	s.progression_totals["revenue"] = 6000000
	s.reputation = 56
	var events := ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "RANK_UP")
	t.eq(events.map(func(e): return int(e["rank"])), [2, 3], "★2 and ★3 are announced, in order")
	t.eq(int(s.progression_state["store_rank"]), 3)
	t.eq(ProgressionService.evaluate(s).filter(func(e): return e["kind"] == "RANK_UP").size(), 0, "no second announcement")
	s.reputation = 40
	ProgressionService.evaluate(s)
	t.eq(int(s.progression_state["store_rank"]), 3, "a rank reached is kept when reputation falls")
	var view := ProgressionService.rank_view(s)
	t.eq(int(view["next"]["rank"]), 4)
	t.ok((view["locked"] as Dictionary).has("crane_game"))


func test_the_rank_survives_a_save_and_old_saves_start_at_one(t, _tree) -> void:
	var s := Run.new_state(100.0)
	s.progression_state["store_rank"] = 3
	var data := SaveGame.to_dict(s, "rank", "2026-11-13T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq(int((lr["state"] as GameState).progression_state["store_rank"]), 3, "the rank is saved")
	(data["progression_state"] as Dictionary).erase("store_rank")
	var lo := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lo["ok"], "a save from before ranks still loads: %s" % str(lo["errors"]))
	t.eq(int((lo["state"] as GameState).progression_state.get("store_rank", 1)), 1, "and starts at ★1 (the next evaluation lifts it)")
