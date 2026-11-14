extends RefCounted
## Storefront decorations (DecorCatalog, user's decision 2026-11-14): bought once, looks only, saved, drawn outside the
## store at a clear spot.

const Run := preload("res://tests/support/basket_run.gd")


func test_the_decor_file_is_valid_and_every_prop_exists(t, _tree) -> void:
	var problems: Array[String] = []
	var items := DecorCatalog.parse(JSON.parse_string(FileAccess.get_file_as_string(DecorCatalog.DATA_PATH)), problems)
	t.eq(problems, [] as Array[String])
	t.ok(items.size() >= 4, "several decorations: %d" % items.size())
	for d in items:
		t.ok(PropSprites.is_available(String(d["prop_id"])), "%s has its picture" % d["decor_id"])
	var bad := DecorCatalog.parse({"decor": [{"decor_id": "x", "name_ja": "X", "description_ja": "d", "prop_id": "p", "price_yen": -1, "spots": []}]}, problems)
	t.eq(bad.size(), 0, "a bad item is left out")


func test_buying_and_removing_a_decoration(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := GameCommands.new(s)
	var cash := s.cash_yen
	var price := int(DecorCatalog.find("cherry_tree")["price_yen"])
	var r := cmds.execute({"command_id": "d1", "kind": &"BUY_DECOR", "decor_id": "cherry_tree"})
	t.ok(r.ok, str(r.message_key))
	t.eq(s.cash_yen, cash - price, "paid once")
	t.eq(s.decor, ["cherry_tree"])
	t.eq(cmds.execute({"command_id": "d2", "kind": &"BUY_DECOR", "decor_id": "cherry_tree"}).message_key, &"decor_owned")
	t.eq(cmds.execute({"command_id": "d3", "kind": &"BUY_DECOR", "decor_id": "nope"}).message_key, &"unknown_decor")
	t.ok(cmds.execute({"command_id": "d4", "kind": &"REMOVE_DECOR", "decor_id": "cherry_tree"}).ok)
	t.eq(s.decor, [], "taken away")
	t.eq(s.cash_yen, cash - price, "nothing paid back")
	t.eq(cmds.execute({"command_id": "d5", "kind": &"REMOVE_DECOR", "decor_id": "cherry_tree"}).message_key, &"decor_not_owned")
	s.ledger.cash_yen = 10
	t.eq(cmds.execute({"command_id": "d6", "kind": &"BUY_DECOR", "decor_id": "cherry_tree"}).message_key, &"not_enough_cash")
	var rows := s.ledger.transactions.filter(func(tx): return (tx.get("details", {}) as Dictionary).has("decor"))
	t.eq(rows.size(), 1)
	t.eq(String(rows[0]["event_type"]), "FIXTURE_PURCHASE", "booked like a fixture, outside the operating profit")


func test_decorations_are_saved_and_older_saves_have_none(t, _tree) -> void:
	var s := Run.new_state(100.0)
	s.decor = ["nobori_coffee", "street_tree"]
	var data := SaveGame.to_dict(s, "decor", "2026-11-14T00:00:00Z")
	var back := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(back["ok"], str(back["errors"]))
	t.eq((back["state"] as GameState).decor, ["nobori_coffee", "street_tree"])
	data["runtime_state"]["decor"] = ["gone", "nobori_coffee"]
	var odd := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.eq((odd["state"] as GameState).decor, ["nobori_coffee"], "an unknown id is dropped")
	(data["runtime_state"] as Dictionary).erase("decor")
	var old := SaveGame.from_dict(JSON.parse_string(JSON.stringify(data)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(old["ok"])
	t.eq((old["state"] as GameState).decor, [], "a save from before decorations has none")


func test_every_decoration_finds_a_clear_spot_outside_the_default_store(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var all := DecorCatalog.items().map(func(d): return d["decor_id"])
	var items := StoreDecor.exterior_items(s.store_width, s.store_height, s.entrance_tiles, all)
	var placed := items.filter(func(it): return it.get("role", "") == "decor")
	t.eq(placed.size(), all.size(), "all of them are drawn: %s" % str(placed.map(func(it): return it["id"])))
	for it in placed:
		var p := Vector2(float(it["x"]), float(it["y"]))
		t.ok(p.x < -0.5 or p.y < -0.5 or p.x > s.store_width - 0.5 or p.y > s.store_height - 0.5, "%s stands outside the floor" % it["id"])
		for other in items:
			if other != it and other.get("kind") == &"sprite":
				t.ok(Vector2(float(other["x"]), float(other["y"])).distance_to(p) >= StoreDecor.DECOR_CLEARANCE - 0.001, "%s keeps clear of %s" % [it["id"], other["id"]])
	t.eq(StoreDecor.exterior_items(s.store_width, s.store_height, s.entrance_tiles).filter(func(it): return it.get("role", "") == "decor").size(), 0, "none bought, none drawn")


func test_decorations_do_not_change_the_simulation(t, _tree) -> void:
	var plain := Run.new_state(100.0)
	var dressed := Run.new_state(100.0)
	dressed.decor = DecorCatalog.items().map(func(d): return d["decor_id"])
	var a := Run.run_days(plain, Run.place_layout(plain), 1, 8)
	var b := Run.run_days(dressed, Run.place_layout(dressed), 1, 8)
	t.eq(b, a, "the same day with or without decorations")
