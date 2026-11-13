extends SceneTree
## Frame sequence of the store for the customer motion review (issue #117). Windowed (needs a renderer):
##   Godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://tools/capture_frames.gd -- <out_dir> --speed=1
## Same seed, same game time (--hour=12), same camera and same bench layout as tools/motion_trace.gd (perf_bench PLAN).
## Saves one frame every --interval seconds (real time, default 0.1) for --seconds (default 10) at the given speed,
## downscaled to --size (default 320x180) as JPG, numbered f0000.jpg, f0001.jpg ... in <out_dir>.
## Only reads the running game except for the arrival queue that the bench uses (no state is edited by the presenter).

const PLAN := [
	["register_basic", 13, 5, 0], ["shelf_general", 3, 2, 0], ["shelf_onigiri", 3, 5, 0], ["shelf_noodle", 3, 8, 0],
	["shelf_bread", 6, 2, 0], ["shelf_snack", 6, 5, 0], ["shelf_general", 6, 8, 0], ["fridge_drink", 9, 2, 0],
	["fridge_dessert", 9, 5, 0], ["freezer_ice", 11, 9, 0], ["warmer_oden", 13, 2, 0], ["shelf_general", 1, 11, 1],
	["shelf_onigiri", 4, 11, 1], ["shelf_snack", 12, 11, 1], ["shelf_bread", 10, 7, 1], ["shelf_noodle", 14, 9, 1],
	["shelf_general", 14, 11, 1], ["fridge_drink", 1, 9, 1], ["shelf_snack", 12, 7, 1], ["fridge_dessert", 8, 9, 1],
]


func _initialize() -> void:
	_run()


func _flag(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return default


func _run() -> void:
	var out_dir := "user://motion_frames"
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out_dir = a
			break
	DirAccess.make_dir_recursive_absolute(out_dir)
	var speed := int(_flag("speed", "1"))
	var seconds := float(_flag("seconds", "10"))
	var interval := float(_flag("interval", "0.1"))
	var size_parts := _flag("size", "320x180").split("x")
	var out_size := Vector2i(int(size_parts[0]), int(size_parts[1]))
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var app: Node = main.get_node("AppRoot")
	var s: GameState = app.state
	s.rank_gating = false   # review layouts use fixtures of every rank (StoreRank); the game itself keeps the gate
	s.ledger.cash_yen = 5000000
	var n := 0
	for p in PLAN:
		app.run_command({"command_id": "cf%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
		n += 1
	var k := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		if def["allowed_categories"].is_empty():
			continue
		var cat: String = def["allowed_categories"][0]
		for slot in def["shelf_slots"]:
			for sku in s.products.skus.values():
				if sku["category"] == cat:
					k += 1
					app.run_command({"command_id": "co%d" % k, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					app.run_command({"command_id": "cr%d" % k, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					break
	app.run_command({"command_id": "cstart", "kind": &"START_BUSINESS"})
	s.balance["base_potential_visitors_per_day"] = 200000
	s.balance["max_active_customers"] = 30
	s.speed_setting = 4
	var guard := 0
	while s.customers.size() < 30 and guard < 20000:
		app.runner.process_frame(1.0 / 15.0)
		guard += 1
	s.time_sec = int(12.0 * 3600.0)   # the same game time for every run (daylight, opening hours)
	app._publish_snapshot()
	var world: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	world.projection.set_zoom(1.0)   # 04 QA: zoom 1
	app.run_command({"command_id": "cspeed", "kind": &"SET_SPEED", "speed": speed})
	for i in 30:
		await process_frame
	var start := Time.get_ticks_msec()
	var shot := 0
	var due := 0.0
	while float(Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await process_frame
		var now := float(Time.get_ticks_msec() - start) / 1000.0
		if now >= due:
			var img := root.get_texture().get_image()
			img.resize(out_size.x, out_size.y, Image.INTERPOLATE_LANCZOS)
			img.save_jpg("%s/f%04d.jpg" % [out_dir, shot], 0.85)
			shot += 1
			due += interval
	print("saved %d frames at x%d into %s, customers on screen %d" % [shot, speed, out_dir, s.customers.size()])
	quit(0)
