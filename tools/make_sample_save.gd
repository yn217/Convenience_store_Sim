extends SceneTree
## Writes the bundled mid-game save (data/saves/sample_midgame.json) that the title screen's 続きから opens in a debug
## build when there is no save of the player's own (user's request 2026-11-14: testing should not start from zero).
## A store with the sample layout and a staff room, stocked every morning, run for three days and into the fourth
## morning, paused, with two storefront decorations. Re-run after a save format change:
##   Godot --headless --path . --script res://tools/make_sample_save.gd

const SampleLayout := preload("res://tools/sample_layout.gd")
const OUT := "res://data/saves/sample_midgame.json"
const DAYS := 3
const STOP_HOUR := 10
const ORDER_PER_SKU := 80


func _initialize() -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string(AppRoot.BALANCE_PATH))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string(AppRoot.FIXTURES_PATH))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string(AppRoot.PRODUCTS_PATH))
	var s := GameState.from_balance(balance, AppRoot.DEFAULT_SEEDS, fx, pr)
	s.ledger.cash_yen = 3000000   # a store some way into the game
	s.progression_state["tutorial_skipped"] = true
	var cmds := GameCommands.new(s)
	var n := 0
	for p in SampleLayout.placements():
		n += 1
		cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
	for spot in [[0, 4, 0], [0, 7, 0], [0, 1, 0]]:
		n += 1
		if cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": "staff_room_s", "x": spot[0], "y": spot[1], "rotation": spot[2]}).ok:
			break
	var runner := SimulationRunner.new(s)
	for day in DAYS + 1:
		_stock(s, cmds, day)
		if day == 0:
			cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
			cmds.execute({"command_id": "speed", "kind": &"SET_SPEED", "speed": 1})
		var stop := day * DemandModel.SECONDS_PER_DAY + STOP_HOUR * 3600 if day == DAYS else 1 << 62
		while s.day == day and s.time_sec < stop:
			runner._run_step()
		ProgressionService.evaluate(s)
		print("day %d closed: reports %d cash %d rank %d" % [day, s.daily_reports.size(), s.cash_yen, int(s.progression_state.get("store_rank", 1))])
	for d in ["nobori_coffee", "flower_planter"]:
		n += 1
		cmds.execute({"command_id": "decor%d" % n, "kind": &"BUY_DECOR", "decor_id": d})
	s.speed_setting = 0   # opens paused
	s.progression_state["dismissed_story_cue_ids"] = Array(AssistantService.CUES)   # past the first-day greetings
	var data := SaveGame.to_dict(s, "sample", "2026-11-14T00:00:00Z")
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var back := SaveGame.from_dict(JSON.parse_string(FileAccess.get_file_as_string(OUT)), balance, fx, pr)
	print("wrote %s: day %d %02d:00, %d fixtures, cash %d, loads back: %s" % [OUT, s.day, STOP_HOUR, s.grid.instances.size(), s.cash_yen, str(back["ok"])])
	quit(0 if back["ok"] else 1)


## Fills each shelf slot with a SKU of its categories and tops up the backroom (as tools/measure_day_sales.gd).
func _stock(s: GameState, cmds: GameCommands, day: int) -> void:
	var cats := {}
	var n := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		var k := n
		for slot in def["shelf_slots"]:
			var skus: Array = s.products.skus.values().filter(func(x): return (def["allowed_categories"] as Array).has(x["category"]))
			if skus.is_empty():
				continue
			var sku: Dictionary = skus[k % skus.size()]
			k += 1
			cats[sku["sku_id"]] = true
			n += 1
			cmds.execute({"command_id": "o%d_%d" % [day, n], "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
			cmds.execute({"command_id": "r%d_%d" % [day, n], "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
	for sku_id in cats:
		n += 1
		cmds.execute({"command_id": "b%d_%d" % [day, n], "kind": &"ORDER_STOCK", "sku_id": sku_id, "qty": ORDER_PER_SKU})
