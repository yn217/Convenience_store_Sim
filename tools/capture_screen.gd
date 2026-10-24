extends SceneTree
## Saves a screenshot of the running game with a stocked store and customers (visual review, #61).
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_screen.gd -- build/shot.png
## --calm: keep the balance's normal arrival rate (no forced crowd) so the shot is representative.

const PLAN := [
	["register_basic", 13, 5, 0], ["shelf_general", 3, 2, 0], ["shelf_onigiri", 3, 5, 0], ["shelf_noodle", 3, 8, 0],
	["shelf_bread", 6, 2, 0], ["shelf_snack", 6, 5, 0], ["shelf_general", 6, 8, 0], ["fridge_drink", 9, 2, 0],
	["fridge_dessert", 9, 5, 0], ["freezer_ice", 11, 9, 0], ["warmer_oden", 13, 2, 0], ["shelf_general", 1, 11, 1],
	["shelf_onigiri", 4, 11, 1], ["shelf_snack", 7, 11, 1], ["shelf_bread", 10, 7, 1], ["shelf_noodle", 14, 9, 1],
	["shelf_general", 14, 11, 1], ["fridge_drink", 1, 9, 1], ["shelf_snack", 12, 7, 1], ["fridge_dessert", 8, 9, 1],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_png := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shot.png"
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var app: Node = main.get_node("AppRoot")
	var s: GameState = app.state
	s.ledger.cash_yen = 5000000
	var placed := 0
	for p in (PLAN if not OS.get_cmdline_user_args().has("empty") else []):
		var r: CommandResult = app.run_command({"command_id": "pf%d" % placed, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
		if r.ok:
			placed += 1
	var n := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		for slot in def["shelf_slots"]:
			var cat: String = def["allowed_categories"][0]
			for sku in s.products.skus.values():
				if sku["category"] == cat:
					n += 1
					app.run_command({"command_id": "po%d" % n, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					app.run_command({"command_id": "pr%d" % n, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					break
	app.run_command({"command_id": "pstart", "kind": &"START_BUSINESS"})
	# --calm: the normal arrival rate of the balance file (no crowd forced in), so the shot shows a typical store (#105 B7).
	var calm := OS.get_cmdline_user_args().has("--calm")
	if not calm:
		s.balance["base_potential_visitors_per_day"] = 200000
		s.balance["max_active_customers"] = 30
	s.speed_setting = 4
	var guard := 0
	while not calm and s.customers.size() < 30 and guard < 20000 and not OS.get_cmdline_user_args().has("empty") and not OS.get_cmdline_user_args().has("nocust"):
		app.runner.process_frame(1.0 / 15.0)
		guard += 1
	for i in 240:
		app.runner.process_frame(1.0 / 15.0)
	if OS.get_cmdline_user_args().has("--select"):   # --select: the first shelf is selected (inspector card with its products)
		var ids: Array = s.grid.instances.keys()
		ids.sort()
		var pick: String = ids[0] if not ids.is_empty() else ""
		for id in ids:
			if not s.fixtures.get_type(s.grid.instances[id]["type_id"]).get("shelf_slots", []).is_empty():
				pick = id
				break
		if pick != "":
			var world: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
			var first: Dictionary = s.grid.instances[pick]
			world.select_screen(world.projection.tile_center(Vector2i(first["x"], first["y"])))
			app._publish_snapshot()
	for a in OS.get_cmdline_user_args():   # --build: build mode (palette at the left); --screen=商品: management window on that tab
		if a == "--build":
			main.call("toggle_build")
		elif a.begins_with("--screen="):
			main.call("open_screen_tab", a.trim_prefix("--screen="))
	if OS.get_cmdline_user_args().has("--whole"):   # --whole: the whole-store fit (F key) instead of the default interior fit (#109)
		main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld").fit_whole()
	for a in OS.get_cmdline_user_args():   # --zoom=1.2: capture at that camera zoom (package icons, #12)
		if a.begins_with("--zoom="):
			var store: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
			store.zoom_at(store.viewport_size() * 0.5, float(a.trim_prefix("--zoom=")))
	if OS.get_cmdline_user_args().has("--debug-paths"):   # --debug-paths: customer path overlay on (DebugPathLayer, F3 in game)
		var store_dbg: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
		store_dbg.set_debug_paths(true)
	for a in OS.get_cmdline_user_args():   # --hour=12: capture at that game clock (daylight tint, #61)
		if a.begins_with("--hour="):
			s.time_sec = int(float(a.trim_prefix("--hour=")) * 3600.0)
			app._publish_snapshot()
	if OS.get_cmdline_user_args().has("--live"):   # --live: keep the stocked, open store running (for recording video)
		app.run_command({"command_id": "plive", "kind": &"SET_SPEED", "speed": 1})
		return
	if OS.get_cmdline_user_args().has("--intent"):   # --intent: pick bubble, queue badge and checkout pop, each saved while on screen
		await _capture_intent(main, s, out_png)
		quit(0)
		return
	for i in 30:
		await process_frame
	get_root().get_texture().get_image().save_png(out_png)
	quit(0)


## Waits until a pick bubble, a queue of two or more and a checkout pop are on screen (each one at most once) and
## saves <out>_pick.png, <out>_queue.png, <out>_checkout.png. Only reads the running game.
func _capture_intent(main: Node, s: GameState, out_png: String) -> void:
	var player: Node = main.get_node("CuePlayer")
	var prefix := out_png.get_basename()
	var saved := {}
	for frame in 9000:
		await process_frame
		var queues := OverlayModel.register_queues(s.customers)
		var waiting := 0
		for reg in queues:
			waiting = maxi(waiting, OverlayModel.line_size(queues[reg]))
		var pick_fresh := false
		for m in player.marks:
			if m["kind"] == "pick" and float(m["age"]) < 0.2:
				pick_fresh = true
		var pop_fresh := false
		for f in player.floats:
			if float(f["age"]) < 0.2:
				pop_fresh = true
		var shot := ""
		if pick_fresh and waiting >= 1 and not saved.has("pick"):
			shot = "pick"
		elif waiting >= 2 and not saved.has("queue"):
			shot = "queue"
		elif pop_fresh and not saved.has("checkout"):
			shot = "checkout"
		if shot != "":
			get_root().get_texture().get_image().save_png("%s_%s.png" % [prefix, shot])
			saved[shot] = true
			print("saved %s_%s.png at game time %d" % [prefix, shot, s.time_sec])
			for f in player.floats:   # the pop-ups on screen: merged count, total and age (real seconds)
				print("  pop %s count=%d yen=%d age=%.2f text=%s" % [f["register_id"], int(f["count"]), int(f["yen"]), float(f["age"]), f["text"]])
		if saved.size() == 3:
			return
