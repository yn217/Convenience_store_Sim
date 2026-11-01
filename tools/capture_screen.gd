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
	for a in OS.get_cmdline_user_args():   # --place=type_id,x,y,rotation: one more fixture after the layout (e.g. crane_game, #132)
		if a.begins_with("--place="):
			var f := a.trim_prefix("--place=").split(",")
			plan = plan + [[f[0], int(f[1]), int(f[2]), int(f[3])]]
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
	for a in OS.get_cmdline_user_args():   # --entrance=x,y: move the entrance there first (#121)
		if a.begins_with("--entrance="):
			var xy := a.trim_prefix("--entrance=").split(",")
			var er: CommandResult = app.run_command({"command_id": "door", "kind": &"MOVE_ENTRANCE", "x": int(xy[0]), "y": int(xy[1])})
			print("entrance: ", er.ok, " ", er.message_key)
	if not OS.get_cmdline_user_args().has("--place-preview") and not OS.get_cmdline_user_args().has("--setup"):
		app.run_command({"command_id": "pstart", "kind": &"START_BUSINESS"})
	if OS.get_cmdline_user_args().has("--setup"):   # --setup: stay before opening (開店までの手順)
		app._publish_snapshot()
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
		if a.begins_with("--build-tab="):   # --build-tab=service: build mode on that catalog tab (all/shelf/cold/counter/service)
			main.call("toggle_build")
			main.get_node("BuildController")._catalog_view.set_category(StringName(a.trim_prefix("--build-tab=")))
		elif a == "--build":
			main.call("toggle_build")
		elif a.begins_with("--screen="):
			main.call("open_screen_tab", a.trim_prefix("--screen="))
		elif a == "--backroom-list":   # some stock in the backroom and its list open (mockup 商品 tab)
			for sku in ["bake_003", "bento_001", "bento_002", "rice_001", "drink_001"]:
				app.run_command({"command_id": "cap_bo_" + sku, "kind": &"ORDER_STOCK", "sku_id": sku, "qty": 3})
			app._publish_snapshot()
			var sc: Node = main.get_node("StockController")
			if sc.backroom_panel != null:
				sc.backroom_panel.toggle()
		elif a.begins_with("--day="):   # --day=1: move the clock to that day (its daily challenge is drawn); cheers closed
			s.day = int(a.trim_prefix("--day="))
			ProgressionService.evaluate(s)
			s.take_progression_events()
			app._publish_snapshot()
			var cheer: ProgressionController = main.get_node("ProgressionController")
			while cheer.is_celebrating():
				cheer.close_celebration()
		elif a == "--kuji" or a == "--kuji-selling":   # #138 限定くじ管理; --kuji-selling buys the set and sells 37 tickets first
			if a == "--kuji-selling":
				app.run_command({"command_id": "cap_kuji", "kind": &"START_LOTTERY", "set_id": KujiScreen.SET_ID})
				var lot: Dictionary = s.lotteries.back()
				for _k in 37:
					Lottery.sell_ticket(s, lot, "cap")
				s.day += 2
				app._publish_snapshot()
			main.get_node("LotteryController").call("open_kuji_screen")
		elif a == "--sample-history":   # #31: a few past days in イベント履歴 (review shots only)
			s.event_history = [{"day": 1, "event_id": "evt_hot_day", "held": true}, {"day": 2, "event_id": "", "held": false}]
			app._publish_snapshot()
		elif a.begins_with("--event="):   # --event=evt_roadworks: today's event, running now (after --day=)
			var ev := GameplayEventDirector.event_by_id(s.gameplay_events, a.trim_prefix("--event="))
			var w := GameplayEventDirector.window(s.day, ev)
			s.time_sec = w.x + 3600
			s.gameplay_event_state.merge({"last_selected_day": s.day, "selection_event_id": "daily:%d" % s.day, "selected_event_id": ev["event_id"],
					"event_start_sec": w.x, "event_end_sec": w.y, "started": true, "ended": false}, true)
			app._publish_snapshot()
		elif a == "--select-customer-first":   # #141: the first customer in the store selected (its portrait in the panel)
			for _f in 3:
				await process_frame
			var w: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
			var people: Array = w.customers.filter(func(c): return not String(c["customer_id"]).begins_with("staff_"))
			if not people.is_empty():
				w.selected_customer = String(people[0]["customer_id"])
				main.get_node("OverlayController").call("refresh_customer")
				main.call("_sync_selection")
		elif a == "--opening":   # 開店！ cut-in, as when the player starts business
			s.business_state = GameState.SETUP
			app._publish_snapshot()
			s.business_state = GameState.OPEN
			app._publish_snapshot()
			for _f in 20:
				await process_frame
			get_root().get_texture().get_image().save_png(out_png)
			quit(0)
			return
		elif a == "--no-assistant":   # hide the corner assistant (window content under her bubble)
			main.get_node("ProgressionController").call("set_suppressed", true)
		elif a.begins_with("--reveal="):   # --reveal=Missions: scroll the open window to that node (by name)
			for _f in 3:
				await process_frame
			var target := main.find_child(a.trim_prefix("--reveal="), true, false) as Control
			if target != null:
				main.call("_reveal", target)
	for a in OS.get_cmdline_user_args():   # --second-store=P05: a second store opened there (#146), the map left open on it
		if a.begins_with("--second-store="):
			s.ledger.cash_yen = 50000000
			app.run_command({"command_id": "cap_open2", "kind": &"OPEN_STORE", "map_id": WorldMap.DEFAULT_MAP, "plot_id": a.trim_prefix("--second-store="), "size_id": "small"})
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
	# Deterministic exterior review: pause after setup, then use the real presentation camera.
	if OS.get_cmdline_user_args().has("--freeze"):
		s.speed_setting = 0
		app._publish_snapshot()
		main.get_node("CuePlayer").advance(10.0)
	var review_world: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	if OS.get_cmdline_user_args().has("--clear-hover"):
		review_world.set_hover_screen(Vector2(-1000, -1000))
	if OS.get_cmdline_user_args().has("--place-preview"):
		main.get_node("BuildController").begin_place("shelf_general")
		review_world.set_hover_screen(review_world.projection.tile_center(Vector2i(2, 7)))
	if OS.get_cmdline_user_args().has("--whole"):
		review_world.fit_whole()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pan="):
			var xy := a.trim_prefix("--pan=").split(",")
			if xy.size() == 2:
				review_world.pan_by(Vector2(float(xy[0]), float(xy[1])))
	if OS.get_cmdline_user_args().has("--intent"):   # --intent: pick bubble, queue badge and checkout pop, each saved while on screen
		await _capture_intent(main, s, out_png)
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--blocked"):   # #20 SCR-14: the store could not pay its costs
		s.business_state = GameState.PAYMENT_BLOCKED
		s.unpaid_cost_yen = 25000
		s.speed_setting = 0
		app._publish_snapshot()
	if OS.get_cmdline_user_args().has("--day-end"):   # #19 SCR-13: close today now, the day-end card with its history
		s.speed_setting = 0
		SimulationRunner.roll_day(s, s.day, s.day + 1)   # as at midnight: the report, then the new day
		app._publish_snapshot()
		var guide: ProgressionController = main.get_node("ProgressionController")
		while guide.is_celebrating():   # earlier titles' cheers are over by the end of the day: her day remark shows
			guide.close_celebration()
	var cut: Control = main.get_node("ProgressionController")._cutin   # the setup above opened the store: no 開店！ in review shots
	if cut != null:
		cut.visible = false
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
