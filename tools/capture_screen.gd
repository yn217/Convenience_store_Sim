extends SceneTree
## Saves a screenshot of the running game with a stocked store and customers (visual review, #61).
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_screen.gd -- build/shot.png
## --calm: keep the balance's normal arrival rate (no forced crowd) so the shot is representative.
## --visual-variant=NAME: sprites use that visual variant (e.g. painted_v1) even when not runtime_approved (dev override).

const SampleLayout := preload("res://tools/sample_layout.gd")   # data/layouts/sample_store_v1.json (falls back to the old plan)


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_png := "user://shot.png"
	for a in OS.get_cmdline_user_args():   # the output path is the first .png argument (flags such as --visual-variant= come first or last)
		if a.ends_with(".png"):
			out_png = a
			break
	var variant := VisualVariants.override()
	if variant != "":
		print("visual variant override: ", variant)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var app: Node = main.get_node("AppRoot")
	var s: GameState = app.state
	s.ledger.cash_yen = 5000000
	for a in OS.get_cmdline_user_args():   # --store-size=small|large: resize the store before the layout (#145)
		if a.begins_with("--store-size="):
			app.run_command({"command_id": "size", "kind": &"SET_STORE_SIZE", "size_id": a.trim_prefix("--store-size=")})
	var plan: Array = SampleLayout.placements() if not OS.get_cmdline_user_args().has("empty") else []
	for a in OS.get_cmdline_user_args():   # --layout=realistic_store_v1: another data/layouts file (its store_size too)
		if a.begins_with("--layout="):
			var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/layouts/%s.json" % a.trim_prefix("--layout=")))
			if lay.has("store_size"):
				app.run_command({"command_id": "lsize", "kind": &"SET_STORE_SIZE", "size_id": lay["store_size"]})
			plan = (lay["placements"] as Array).map(func(p): return [String(p["type_id"]), int(p["x"]), int(p["y"]), int(p["rotation"])])
	var placed := 0
	for p in plan:
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
	for a in OS.get_cmdline_user_args():   # --staff=4: that many staff (extra balanced people at the first one's tile)
		if a.begins_with("--staff="):
			while s.staff.size() < int(a.trim_prefix("--staff=")) and not s.staff.is_empty():
				s.staff.append(StaffAI.make(s, {"name": "応援%d" % s.staff.size(), "skills": {"register": 3, "restock": 3, "stamina": 3, "service": 3}}, s.staff[0]["tile"]))
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
	if OS.get_cmdline_user_args().has("--select-customer"):   # --select-customer: pause and select the customer with the fullest basket (#141 panel)
		var best: Dictionary = {}
		for c in s.customers:
			if best.is_empty() or (c.get("basket_log", []) as Array).size() > (best.get("basket_log", []) as Array).size():
				best = c
		if not best.is_empty():
			s.speed_setting = 0
			var cw: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
			cw._set_customer(best["customer_id"])
			app._publish_snapshot()
	for a in OS.get_cmdline_user_args():   # --build: build mode (palette at the left); --screen=商品: management window on that tab
		if a == "--build":
			main.call("toggle_build")
		elif a.begins_with("--screen="):
			main.call("open_screen_tab", a.trim_prefix("--screen="))
	for a in OS.get_cmdline_user_args():   # --map=P02: the area map open with that site clicked (#150)
		if a == "--map" or a.begins_with("--map="):
			var biz: Node = main.get_node("BusinessController")
			biz.open_map()
			for m in OS.get_cmdline_user_args():   # --map-id=kakogawa_city_v1: show that map (#154)
				if m.begins_with("--map-id="):
					biz.show_map(m.trim_prefix("--map-id="))
			if a.begins_with("--map="):
				biz._show_plot(a.trim_prefix("--map="))
		if a.begins_with("--map-hour="):   # --map-hour=8: the forecast layer at that hour
			main.get_node("BusinessController").set_forecast_hour(int(a.trim_prefix("--map-hour=")))
		if a.begins_with("--map-zoom="):   # --map-zoom=1.8: zoomed about the centre of the map view
			var mv: MapView = main.get_node("BusinessController")._map_view
			mv.zoom_at(mv.size * 0.5, float(a.trim_prefix("--map-zoom=")))
	if OS.get_cmdline_user_args().has("--whole"):   # --whole: the whole-store fit (F key) instead of the default interior fit (#109)
		main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld").fit_whole()
	for a in OS.get_cmdline_user_args():   # --zoom=1.2: capture at that camera zoom (package icons, #12)
		if a.begins_with("--zoom="):
			var store: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
			store.zoom_at(store.viewport_size() * 0.5, float(a.trim_prefix("--zoom=")))
	if OS.get_cmdline_user_args().has("--register-closed"):   # --register-closed: nobody at the till, the 休止中 sign (#113)
		s.speed_setting = 0
		for st in s.staff:
			st["phase"] = "REST"
			st["tile"] = Vector2i(0, 0)
			st["path"] = [] as Array[Vector2i]
		app._publish_snapshot()
	if OS.get_cmdline_user_args().has("--focus=register"):   # --focus=register: zoom 1.6 centred on the first register (#113)
		var store_f: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
		var reg_tile := _first_register_tile(s)
		if reg_tile != Vector2i(-1, -1):
			store_f.zoom_at(store_f.viewport_size() * 0.5, 1.6)
			store_f.pan_by(store_f.viewport_size() * 0.5 - store_f.projection.tile_center(reg_tile))
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


## Origin tile of the first register (by instance id), or (-1, -1) when the store has none.
func _first_register_tile(s: GameState) -> Vector2i:
	var ids: Array = s.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = s.grid.instances[id]
		if AccessService.is_register(s.fixtures.get_type(inst["type_id"])):
			return Vector2i(inst["x"], inst["y"])
	return Vector2i(-1, -1)


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
