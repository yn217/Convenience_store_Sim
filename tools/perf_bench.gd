extends SceneTree
## Fixed-condition performance measurement (QA S-14). Run with a real renderer (not --headless):
##   Godot_v4.7.2-stable_win64.exe --path . --resolution 1920x1080 --script res://tools/perf_bench.gd -- build/perf.json
## Conditions: 16x12 store, 20 fixtures, 30 customers in the store, 1920x1080, speed x4, 600 measured frames.
## Writes median / p95 / max frame time, FPS, video memory and the sim cost per fixed step.

const FRAMES := 600
const WARMUP := 120
const SampleLayout := preload("res://tools/sample_layout.gd")   # data/layouts/sample_store_v1.json (falls back to the old plan)


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://perf.json"
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var app: Node = main.get_node("AppRoot")
	var s: GameState = app.state
	s.ledger.cash_yen = 5000000
	var placed := 0
	for p in (SampleLayout.placements() if not OS.get_cmdline_user_args().has("empty") else []):
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
	s.balance["base_potential_visitors_per_day"] = 200000
	s.balance["max_active_customers"] = 30
	s.speed_setting = 4
	var guard := 0
	while s.customers.size() < 30 and guard < 20000 and not OS.get_cmdline_user_args().has("empty") and not OS.get_cmdline_user_args().has("nocust"):
		app.runner.process_frame(1.0 / 15.0)
		guard += 1
	var sim_ms := _time_steps(app, 200)
	var parts := {}
	var ai := CustomerAI.new()
	for name in ["sweep", "release", "event", "demand", "ai", "progress"]:
		var t0 := Time.get_ticks_usec()
		for i in 50:
			match name:
				"sweep": InventoryService.sweep_expired(s)
				"release": InventoryService.release_timed_out(s)
				"event": EventService.step(s)
				"demand": DemandGenerator.step(s)
				"ai": ai.step(s)
				"progress": ProgressionService.evaluate(s)
		parts[name] = float(Time.get_ticks_usec() - t0) / 1000.0 / 50.0
	var phases := {}
	for c in s.customers:
		phases[c["phase"]] = int(phases.get(c["phase"], 0)) + 1
	var tc := Time.get_ticks_usec()
	for i in 20:
		ai.candidates(s)
	print("PHASES ", phases, " candidates_ms=", float(Time.get_ticks_usec() - tc) / 20000.0)
	var snap_parts := {}
	for name in ["today", "story", "milestone", "event", "stocked", "customers", "fixture_sales", "shelf", "stock_by_slot", "reports"]:
		var q0 := Time.get_ticks_usec()
		for i in 50:
			match name:
				"today": s.today_summary()
				"story": AssistantService.current(s)
				"milestone": ProgressionService.milestone_progress(s)
				"event": EventService.view(s)
				"stocked": DemandGenerator.stocked_categories(s)
				"customers": s._customer_views()
				"fixture_sales": s.fixture_sales_today()
				"shelf": s._shelf_skus()
				"stock_by_slot": ShelfDisplay.stock_by_slot(s.inventory_segments)
				"reports": s.daily_reports.duplicate(true)
		snap_parts[name] = float(Time.get_ticks_usec() - q0) / 50000.0
	print("SNAPPARTS ", snap_parts)
	print("PARTS ", parts)
	var presenter: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld/ObjectSortRoot/FixturePresenter")
	var t1 := Time.get_ticks_usec()
	for i in 30:
		presenter.compose()
	var compose_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / 30.0
	t1 = Time.get_ticks_usec()
	for i in 30:
		s.snapshot()
	var snapshot_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / 30.0
	t1 = Time.get_ticks_usec()
	for i in 10:
		app._publish_snapshot()
	var publish_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / 10.0
	var publish_parts := _time_views(main, s.snapshot())
	print("PUBLISHPARTS ", publish_parts)
	print("SNAPSHOT_MS ", snapshot_ms, " PUBLISH_MS ", publish_ms)
	for i in WARMUP:
		await process_frame
	if OS.get_cmdline_user_args().has("probe"):
		var world := main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
		s.speed_setting = 0 if OS.get_cmdline_user_args().has("paused") else 4
		var saved_stock: Dictionary = world.shelf_stock
		var saved_customers: Array = world.customers
		world.shelf_stock = {}
		var q0 := Time.get_ticks_usec()
		for i in 60:
			await process_frame
		print("PROBE nostock frame_ms=%.1f" % (float(Time.get_ticks_usec() - q0) / 60000.0))
		world.shelf_stock = saved_stock
		world.customers = []
		q0 = Time.get_ticks_usec()
		for i in 60:
			await process_frame
		print("PROBE nocustomers frame_ms=%.1f" % (float(Time.get_ticks_usec() - q0) / 60000.0))
		world.customers = saved_customers
		for probe in ["none", "FixturePresenter", "OverlayLayer", "CueLayer", "SelectionOverlay"]:
			var node: CanvasItem = null if probe == "none" else (world.get_node("ObjectSortRoot/FixturePresenter") if probe == "FixturePresenter" else world.get_node(probe))
			if node != null:
				node.visible = false
			var acc := 0.0
			var l0 := Time.get_ticks_usec()
			for i in 60:
				await process_frame
			acc = float(Time.get_ticks_usec() - l0) / 60000.0
			print("PROBE hide=%s frame_ms=%.1f" % [probe, acc])
			if node != null:
				node.visible = true
	main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld").projection.set_zoom(1.0)   # 04 §QA: zoom 1
	var by_speed := {}
	for speed in [1, 2, 4]:
		s.speed_setting = speed
		for i in WARMUP:
			await process_frame
		presenter.draw_usec_total = 0
		presenter.draw_count = 0
		presenter.prof_compose = 0
		presenter.prof_customers = 0
		presenter.prof_fixtures = 0
		var times: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in FRAMES:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now - last) / 1000.0)
			last = now
		times.sort()
		var med: float = times[times.size() / 2]
		var p95v: float = times[int(times.size() * 0.95)]
		by_speed["x%d" % speed] = {"median_ms": med, "p95_ms": p95v, "max_ms": times[times.size() - 1], "fps_median": 1000.0 / med, "fps_p95": 1000.0 / p95v, "presenter_draw_ms": float(presenter.draw_usec_total) / 1000.0 / maxf(presenter.draw_count, 1), "prof_ms": {"compose": float(presenter.prof_compose) / 1000.0 / maxf(presenter.draw_count, 1), "customers": float(presenter.prof_customers) / 1000.0 / maxf(presenter.draw_count, 1), "fixtures": float(presenter.prof_fixtures) / 1000.0 / maxf(presenter.draw_count, 1)}, "customers": s.customers.size(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}
	var info := {
		"conditions": {"store": "16x12", "fixtures_placed": s.grid.instances.size(), "customers_in_store": s.customers.size(), "window": str(get_root().size), "speed": s.speed_setting, "frames": FRAMES},
		"by_speed": by_speed,
		"sim_step_ms": sim_ms, "compose_ms": compose_ms, "snapshot_ms": snapshot_ms, "publish_ms": publish_ms, "publish_parts": publish_parts,
		"video_mem_mb": float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0,
		"environment": {"godot": Engine.get_version_info()["string"], "os": OS.get_name() + " " + OS.get_version(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "cpu": OS.get_processor_name(), "threads": OS.get_processor_count()},
	}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "  "))
	f.close()
	print(JSON.stringify(info, "  "))
	quit(0)


## Mean cost of one fixed simulation step with the customers in the store (ms).
func _time_steps(app: Node, steps: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in steps:
		app.runner._run_step()
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(steps)


## Cost of one apply_snapshot per view that has one, slowest first (ms).
func _time_views(main: Node, snap: Dictionary) -> Dictionary:
	var views: Array = main.find_children("*", "Node", true, false).filter(func(n): return n.has_method("apply_snapshot"))
	var rows: Array = []
	for v in views:
		var t0 := Time.get_ticks_usec()
		for i in 5:
			v.apply_snapshot(snap)
		rows.append([String(v.name), float(Time.get_ticks_usec() - t0) / 5000.0])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var parts := {}
	for r in rows:
		parts[r[0]] = r[1]
	return parts
