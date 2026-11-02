extends SceneTree
## Saves a screenshot of the running game with a stocked store and customers (visual review, #61).
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_screen.gd -- build/shot.png
## --calm: keep the balance's normal arrival rate (no forced crowd) so the shot is representative.
## --visual-variant=NAME: sprites use that visual variant (e.g. painted_v1) even when not runtime_approved (dev override).
## --world-only: capture StoreViewport/SubViewport without the surrounding HUD.
## --store-mask: capture the store's visible projected silhouette on transparent background, hiding environment/props.

const SampleLayout := preload("res://tools/sample_layout.gd")   # data/layouts/sample_store_v1.json (falls back to the old plan)


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_png := "user://shot.png"
	for a in OS.get_cmdline_user_args():   # the output path is the first non-flag .png argument
		if a.ends_with(".png") and not a.begins_with("--"):
			out_png = a
			break
	# Capture at a specific logical world viewport size for exterior camera QA.
	var capture_size_arg := _argument_value("--capture-size=")
	var capture_size := Vector2i.ZERO
	if capture_size_arg != "":
		var capture_size_parts := capture_size_arg.to_lower().split("x")
		if capture_size_parts.size() == 2:
			var capture_width := int(capture_size_parts[0])
			var capture_height := int(capture_size_parts[1])
			if capture_width >= 640 and capture_height >= 360:
				capture_size = Vector2i(capture_width, capture_height)
	var variant := VisualVariants.override()
	if variant != "":
		print("visual variant override: ", variant)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	if capture_size != Vector2i.ZERO:
		var world_container := main.get_node("Layout/MainArea/StoreViewport") as SubViewportContainer
		var world_viewport := world_container.get_node("SubViewport") as SubViewport
		world_container.stretch = false
		world_viewport.size = capture_size
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
	if not OS.get_cmdline_user_args().has("--place-preview"):
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
	# Apply requested zoom after fit_whole so whole-store fitting cannot reset the test zoom.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="):
			review_world.zoom_at(review_world.viewport_size() * 0.5, float(a.trim_prefix("--zoom=")))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pan="):
			var xy := a.trim_prefix("--pan=").split(",")
			if xy.size() == 2:
				review_world.pan_by(Vector2(float(xy[0]), float(xy[1])))
	var context_texture_path := _argument_value("--urban-context-texture=")
	if context_texture_path != "":
		var context_image := Image.new()
		var resolved_context_path := ProjectSettings.globalize_path(context_texture_path) if context_texture_path.begins_with("res://") else context_texture_path
		var context_load_error := context_image.load(resolved_context_path)
		if context_load_error != OK:
			push_error("could not load urban context texture: %s (%d)" % [resolved_context_path, context_load_error])
			quit(1)
			return
		var context_backdrop := review_world.get_node_or_null("BackdropLayer") as BackdropLayer
		if context_backdrop == null:
			push_error("urban context texture override requires BackdropLayer")
			quit(1)
			return
		context_backdrop.set_capture_urban_context_texture(ImageTexture.create_from_image(context_image))
		context_backdrop.sync(review_world.store_width, review_world.store_height, review_world.entrance_tiles, review_world.projection, review_world.viewport_size())
	var screen_plate_path := _argument_value("--background-screen-plate=")
	var plate_path := screen_plate_path if screen_plate_path != "" else _argument_value("--background-plate=")
	if plate_path != "":
		var plate_image := Image.new()
		var resolved_plate_path := ProjectSettings.globalize_path(plate_path) if plate_path.begins_with("res://") else plate_path
		var load_error := plate_image.load(resolved_plate_path)
		if load_error != OK:
			push_error("could not load background plate: %s (%d)" % [resolved_plate_path, load_error])
		else:
			var backdrop := review_world.get_node_or_null("BackdropLayer") as BackdropLayer
			if backdrop != null:
				var reference_origin := Vector2.ZERO
				var reference_zoom := 1.0
				if screen_plate_path != "":
					var guide_path := _argument_value("--background-guide=")
					if guide_path == "":
						guide_path = plate_path.get_base_dir().path_join("guide.json")
					var resolved_guide_path := ProjectSettings.globalize_path(guide_path) if guide_path.begins_with("res://") else guide_path
					var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resolved_guide_path)) if FileAccess.file_exists(resolved_guide_path) else {}
					if guide.is_empty():
						push_error("background screen plate requires a readable projection guide: %s" % resolved_guide_path)
						quit(1)
						return
					var projection_guide: Dictionary = guide.get("projection", {})
					var origin_guide: Array = projection_guide.get("origin", [0.0, 0.0])
					if origin_guide.size() >= 2:
						reference_origin = Vector2(float(origin_guide[0]), float(origin_guide[1]))
					reference_zoom = float(projection_guide.get("zoom", 1.0))
					var size_guide: Dictionary = guide.get("store_size", {})
					if origin_guide.size() < 2 or reference_zoom <= 0.0 or int(size_guide.get("width_m", -1)) != review_world.store_width or int(size_guide.get("height_m", -1)) != review_world.store_height:
						push_error("background screen plate guide does not match this store and camera: %s" % resolved_guide_path)
						quit(1)
						return
				backdrop.set_capture_background_plate(ImageTexture.create_from_image(plate_image), true, screen_plate_path != "", reference_origin, reference_zoom)
				backdrop.sync(review_world.store_width, review_world.store_height, review_world.entrance_tiles, review_world.projection, review_world.viewport_size())
				for child in backdrop.get_children():
					if child is CanvasItem:
						child.visible = false
				if screen_plate_path != "":
					for layer_name in ["ExteriorDecor", "LightSpill", "CueLayer", "SelectionOverlay"]:
						var layer := review_world.get_node_or_null(layer_name) as CanvasItem
						if layer != null:
							layer.visible = false
	var exterior_plate_path := _argument_value("--background-exterior-plate=")
	if exterior_plate_path != "":
		var exterior_image := Image.new()
		var resolved_exterior_path := ProjectSettings.globalize_path(exterior_plate_path) if exterior_plate_path.begins_with("res://") else exterior_plate_path
		var exterior_load_error := exterior_image.load(resolved_exterior_path)
		if exterior_load_error != OK:
			push_error("could not load exterior plate: %s (%d)" % [resolved_exterior_path, exterior_load_error])
			quit(1)
			return
		var exterior_guide_path := _argument_value("--background-guide=")
		if exterior_guide_path == "":
			exterior_guide_path = exterior_plate_path.get_base_dir().path_join("guide.json")
		var resolved_exterior_guide := ProjectSettings.globalize_path(exterior_guide_path) if exterior_guide_path.begins_with("res://") else exterior_guide_path
		var exterior_guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resolved_exterior_guide)) if FileAccess.file_exists(resolved_exterior_guide) else {}
		var exterior_projection: Dictionary = exterior_guide.get("projection", {})
		var exterior_origin: Array = exterior_projection.get("origin", [])
		var exterior_zoom := float(exterior_projection.get("zoom", 0.0))
		var exterior_size: Dictionary = exterior_guide.get("store_size", {})
		if exterior_origin.size() < 2 or exterior_zoom <= 0.0 or int(exterior_size.get("width_m", -1)) != review_world.store_width or int(exterior_size.get("height_m", -1)) != review_world.store_height:
			push_error("exterior plate guide does not match this store and camera: %s" % resolved_exterior_guide)
			quit(1)
			return
		var exterior_backdrop := review_world.get_node_or_null("BackdropLayer") as BackdropLayer
		if exterior_backdrop == null:
			push_error("exterior plate requires BackdropLayer")
			quit(1)
			return
		exterior_backdrop.sync(review_world.store_width, review_world.store_height, review_world.entrance_tiles, review_world.projection, review_world.viewport_size())
		exterior_backdrop.set_capture_exterior_plate(ImageTexture.create_from_image(exterior_image), Vector2(float(exterior_origin[0]), float(exterior_origin[1])), exterior_zoom)
		for layer_name in ["ExteriorDecor", "LightSpill"]:
			var layer := review_world.get_node_or_null(layer_name) as CanvasItem
			if layer != null:
				layer.visible = false
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
		s.close_day_once(s.day)
		app._publish_snapshot()
	for i in 30:
		await process_frame
	var screenshot: Image
	var store_viewport: SubViewport = main.get_node("Layout/MainArea/StoreViewport/SubViewport")
	if OS.get_cmdline_user_args().has("--store-mask"):
		store_viewport.transparent_bg = true
		_prepare_store_silhouette(main)
		for i in 2:
			await process_frame
		screenshot = store_viewport.get_texture().get_image()
	elif OS.get_cmdline_user_args().has("--world-only"):
		screenshot = store_viewport.get_texture().get_image()
	else:
		screenshot = get_root().get_texture().get_image()
	if OS.get_cmdline_user_args().has("--dump-projection"):
		var center: Vector2 = review_world.projection.world_to_screen((float(review_world.store_width) - 1.0) * 0.5, (float(review_world.store_height) - 1.0) * 0.5)
		print("capture projection: viewport=", store_viewport.size, " zoom=", review_world.projection.zoom, " origin=", review_world.projection.origin, " store_center=", center)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_png.get_base_dir()))
	screenshot.save_png(out_png)
	var guide_dir := _argument_value("--guide-dir=")
	if guide_dir != "":
		await _capture_projection_package(main, review_world, store_viewport, screenshot, guide_dir)
	quit(0)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


## Capture the composed image, both visual layers, and Godot-projected guide/mask assets from one camera state.
func _capture_projection_package(main: Node, world: Node2D, store_viewport: SubViewport, source: Image, output_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var fullscene_path := output_dir.path_join("source_fullscene.png")
	source.save_png(fullscene_path)
	var original_transparent := store_viewport.transparent_bg
	store_viewport.transparent_bg = true
	var world_visible := world.visible
	var visibility := {}
	for child in world.get_children():
		if child is CanvasItem:
			visibility[child.name] = child.visible
			child.visible = child.name in ["BackdropLayer", "TimeTint"]
	var backdrop := world.get_node_or_null("BackdropLayer") as BackdropLayer
	var backdrop_child_visibility := {}
	if backdrop != null:
		for child in backdrop.get_children():
			if child is CanvasItem:
				backdrop_child_visibility[child] = child.visible
				child.visible = false
		backdrop.set_capture_background_only(true)
	world.set_capture_skip_store_floor(true)
	for i in 3:
		await process_frame
	var background_only := store_viewport.get_texture().get_image()
	background_only.save_png(output_dir.path_join("background_only.png"))
	if backdrop != null:
		backdrop.set_capture_background_only(false)
		for child in backdrop_child_visibility:
			if is_instance_valid(child):
				child.visible = bool(backdrop_child_visibility[child])
	world.set_capture_skip_store_floor(false)
	for child in world.get_children():
		if child is CanvasItem and visibility.has(child.name):
			child.visible = bool(visibility[child.name])
	for i in 2:
		await process_frame
	var hidden_paths := [
		"BackdropLayer", "LightSpill", "ExteriorDecor", "FrontDecor", "RegisterFloorDecor",
		"EquipmentDecor", "RegisterTopDecor", "LightGlow", "OverlayLayer", "CueLayer",
		"SelectionOverlay", "DebugPathLayer",
	]
	visibility.clear()
	for path in hidden_paths:
		var item := world.get_node_or_null(path) as CanvasItem
		if item != null:
			visibility[path] = item.visible
			item.visible = false
	for i in 3:
		await process_frame
	var store_only := store_viewport.get_texture().get_image()
	store_only.save_png(output_dir.path_join("store_only.png"))
	var size := Vector2i(store_viewport.size)
	var overlay_visibility := {}
	for child in world.get_children():
		if child is CanvasItem:
			overlay_visibility[child] = child.visible
			# SignLayer contains the floating fixture/category labels visible in the
			# normal store view; OverlayLayer contains stock/selection badges.
			child.visible = child.name in ["OverlayLayer", "SignLayer"]
	world.set_capture_skip_store_floor(true)
	for i in 3:
		await process_frame
	var overlay_only := store_viewport.get_texture().get_image()
	overlay_only.save_png(output_dir.path_join("overlay_only.png"))
	var overlay_mask := _store_protect_mask(overlay_only, size, 2)
	overlay_mask.save_png(output_dir.path_join("overlay_protect_mask.png"))
	for child in overlay_visibility:
		if is_instance_valid(child):
			child.visible = bool(overlay_visibility[child])
	var dynamic_visibility := {}
	for child in world.get_children():
		if child is CanvasItem:
			dynamic_visibility[child.name] = child.visible
			child.visible = child.name in ["ObjectSortRoot", "TimeTint"]
	var fixture_presenter := world.get_node_or_null("ObjectSortRoot/FixturePresenter")
	if fixture_presenter != null and fixture_presenter.has_method("set_capture_customers_only"):
		fixture_presenter.call("set_capture_customers_only", true)
	world.set_capture_skip_store_floor(true)
	for i in 3:
		await process_frame
	var dynamic_only := store_viewport.get_texture().get_image()
	dynamic_only.save_png(output_dir.path_join("dynamic_object_only.png"))
	if fixture_presenter != null and fixture_presenter.has_method("set_capture_customers_only"):
		fixture_presenter.call("set_capture_customers_only", false)
	world.set_capture_skip_store_floor(false)
	for child in world.get_children():
		if child is CanvasItem and dynamic_visibility.has(child.name):
			child.visible = bool(dynamic_visibility[child.name])
	for path in visibility:
		var item := world.get_node_or_null(path) as CanvasItem
		if item != null:
			item.visible = bool(visibility[path])
	store_viewport.transparent_bg = original_transparent
	var protect_mask := _store_protect_mask(store_only, size, 2)
	var dynamic_mask := _store_protect_mask(dynamic_only, size, 2)
	var edit_mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	var overlay := source.duplicate() as Image
	overlay.convert(Image.FORMAT_RGBA8)
	var depth_mask := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y in size.y:
		for x in size.x:
			var protected := protect_mask.get_pixel(x, y).r > 0.5
			var p := Vector2(x + 0.5, y + 0.5)
			var world_point: Vector2 = world.projection.screen_to_world(p)
			var depth_class := _exterior_depth_class(world_point, world.store_width, world.store_height, BackdropLayer.entrance_side(world.store_width, world.store_height, world.entrance_tiles))
			if protected:
				edit_mask.set_pixel(x, y, Color.BLACK)
				depth_mask.set_pixel(x, y, Color(1.0, 0.0, 0.0))
			else:
				edit_mask.set_pixel(x, y, Color.WHITE)
				depth_mask.set_pixel(x, y, depth_class)
				var regen_blend := source.get_pixel(x, y).lerp(Color(1.0, 0.08, 0.04), 0.34)
				overlay.set_pixel(x, y, regen_blend)
	protect_mask.save_png(output_dir.path_join("store_protect_mask.png"))
	dynamic_mask.save_png(output_dir.path_join("dynamic_object_protect_mask.png"))
	edit_mask.save_png(output_dir.path_join("exterior_edit_mask.png"))
	depth_mask.save_png(output_dir.path_join("depth_or_occlusion_mask.png"))
	overlay.save_png(output_dir.path_join("exterior_edit_mask_overlay.png"))
	var geometry := _projection_edge_guide(world.projection, world.store_width, world.store_height, world.entrance_tiles, size)
	geometry.save_png(output_dir.path_join("geometry_edges.png"))
	var flat_guide := _flat_color_guide(world.projection, world.store_width, world.store_height, world.entrance_tiles, protect_mask, size)
	flat_guide.save_png(output_dir.path_join("flat_color_guide.png"))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(fullscene_path))
	var entrance_side := BackdropLayer.entrance_side(world.store_width, world.store_height, world.entrance_tiles)
	var metadata := {
		"source": "source_fullscene.png",
		"source_sha256": hash.finish().hex_encode(),
		"viewport": {"width": size.x, "height": size.y},
		"store_size": {"width_m": world.store_width, "height_m": world.store_height},
		"entrance_side": entrance_side,
		"entrance_tiles": world.entrance_tiles.map(func(tile: Vector2i) -> Array: return [tile.x, tile.y]),
		"projection": {
			"class": "IsoProjection",
			"zoom": world.projection.zoom,
			"origin": [world.projection.origin.x, world.projection.origin.y],
			"formula": "screen = origin + zoom * (64*(x-y), 32*(x+y)-78.38367177*z)",
			"ground_axis_slopes": [0.5, -0.5],
			"wall_height_m": IsoProjection.WALL_HEIGHT_M,
		},
		"masks": {
			"store_protect_mask.png": "white=keep/protect, black=exterior; store, fixtures and visible store objects dilated by 2px",
			"dynamic_object_protect_mask.png": "white=visible customer pixels, black=other pixels; independently rendered customer layer dilated by 2px",
			"overlay_protect_mask.png": "white=live fixture/category labels and store badges, black=other pixels; independently rendered SignLayer and OverlayLayer dilated by 2px",
			"exterior_edit_mask.png": "white=permitted exterior edit, black=protected store",
			"depth_or_occlusion_mask.png": {"red": "protected store foreground", "green": "rear/side exterior", "blue": "entrance-side paving, parking, and road"},
		},
		"guide_files": ["geometry_edges.png", "flat_color_guide.png", "background_only.png", "store_only.png", "overlay_only.png", "overlay_protect_mask.png", "dynamic_object_only.png", "dynamic_object_protect_mask.png"],
		"background_only_policy": "single UrbanContextBackdrop plate only; omit store wall occlusion, store-adjacent surface meshes, and individual backdrop child sprites (including the right-edge horizontal planting strip)",
	}
	var file := FileAccess.open(output_dir.path_join("guide.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("projection guide package saved: ", output_dir)


## Keep visible store geometry and attached frontage art; hide exterior scenery, overlays, and transient UI.
func _prepare_store_silhouette(main: Node) -> void:
	var base := "Layout/MainArea/StoreViewport/SubViewport/StoreWorld/"
	for node_name in ["BackdropLayer", "LightSpill", "ExteriorDecor", "OverlayLayer", "CueLayer", "LightGlow", "SelectionOverlay", "DebugPathLayer"]:
		var layer := main.get_node_or_null(base + node_name) as CanvasItem
		if layer != null:
			layer.visible = false
	var time_tint := main.get_node_or_null(base + "TimeTint") as CanvasModulate
	if time_tint != null:
		time_tint.color = Color.WHITE


func _store_protect_mask(store_only: Image, size: Vector2i, expand_px: int) -> Image:
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	mask.fill(Color.BLACK)
	var alpha := store_only.get_region(Rect2i(Vector2i.ZERO, size)).get_data()
	for y in size.y:
		for x in size.x:
			var pixel_index := (y * size.x + x) * 4 + 3
			if alpha[pixel_index] < 16:
				continue
			for oy in range(-expand_px, expand_px + 1):
				for ox in range(-expand_px, expand_px + 1):
					var mx := x + ox
					var my := y + oy
					if mx >= 0 and my >= 0 and mx < size.x and my < size.y and Vector2i(ox, oy).length() <= float(expand_px):
						mask.set_pixel(mx, my, Color.WHITE)
	return mask


func _projection_edge_guide(proj: IsoProjection, width: int, height: int, entrances: Array, canvas: Vector2i) -> Image:
	var image := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var ground := [Vector2(-0.5, -0.5), Vector2(width - 0.5, -0.5), Vector2(width - 0.5, height - 0.5), Vector2(-0.5, height - 0.5)]
	for i in 4:
		var a: Vector2 = ground[i]
		var b: Vector2 = ground[(i + 1) % 4]
		var base_color := Color("ff615c") if absf(b.x - a.x) > 0.01 else Color("61aaff")
		_draw_guide_line(image, proj.world_to_screen(a.x, a.y), proj.world_to_screen(b.x, b.y), base_color, 3)
		_draw_guide_line(image, proj.world_to_screen(a.x, a.y, IsoProjection.WALL_HEIGHT_M), proj.world_to_screen(b.x, b.y, IsoProjection.WALL_HEIGHT_M), Color("ff4de1"), 3)
		_draw_guide_line(image, proj.world_to_screen(a.x, a.y), proj.world_to_screen(a.x, a.y, IsoProjection.WALL_HEIGHT_M), Color("ffe45f"), 2)
	var side := BackdropLayer.entrance_side(width, height, entrances)
	var edge_length := float(height if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else width)
	var zone_depths := [BackdropLayer.PAVE_M, BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M, BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M, BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M]
	for depth in zone_depths:
		var p0 := BackdropLayer.side_point(side, depth, 0.0, width, height)
		var p1 := BackdropLayer.side_point(side, depth, edge_length, width, height)
		_draw_guide_line(image, proj.world_to_screen(p0.x, p0.y), proj.world_to_screen(p1.x, p1.y), Color("ffe45f"), 2)
	var center := Vector2((float(width) - 1.0) * 0.5, (float(height) - 1.0) * 0.5)
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		var a: Vector2 = center - axis * 6.0
		var b: Vector2 = center + axis * 6.0
		var color := Color("69ffd1") if axis == Vector2.RIGHT else Color("c58aff")
		_draw_guide_line(image, proj.world_to_screen(a.x, a.y), proj.world_to_screen(b.x, b.y), color, 2)
	return image


func _flat_color_guide(proj: IsoProjection, width: int, height: int, entrances: Array, protect_mask: Image, canvas: Vector2i) -> Image:
	var image := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGB8)
	var side := BackdropLayer.entrance_side(width, height, entrances)
	var edge_length := float(height if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else width)
	for y in canvas.y:
		for x in canvas.x:
			if protect_mask.get_pixel(x, y).r > 0.5:
				image.set_pixel(x, y, Color("d8c8a7"))
				continue
			var w: Vector2 = proj.screen_to_world(Vector2(x + 0.5, y + 0.5))
			var depth := _entrance_side_depth(w, side)
			var along := w.y if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else w.x
			var color := Color("52784f")
			if depth >= 0.0 and depth < BackdropLayer.PAVE_M and along >= 0.0 and along <= edge_length:
				color = Color("d6cbb4")
			elif depth >= BackdropLayer.PAVE_M and depth < BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M and along >= 0.0 and along <= edge_length:
				color = Color("454950")
			elif depth >= BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M and depth < BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M:
				color = Color("cbc9c0")
			elif depth >= BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M and depth < BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M:
				color = Color("52575b")
			elif depth >= BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M:
				color = Color("d6cbb4") if depth < BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M + BackdropLayer.OUTER_SIDEWALK_M else Color("52784f")
			image.set_pixel(x, y, color)
	return image


func _entrance_side_depth(point: Vector2, side: int) -> float:
	match side:
		BackdropLayer.SIDE_WEST:
			return -0.5 - point.x
		BackdropLayer.SIDE_NORTH:
			return -0.5 - point.y
		BackdropLayer.SIDE_EAST:
			return point.x - 0.0
	return point.y - 0.0


func _exterior_depth_class(point: Vector2, width: int, height: int, side: int) -> Color:
	var depth := _entrance_side_depth(point, side)
	var road_end := BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M
	if depth >= 0.0 and depth <= road_end + BackdropLayer.OUTER_SIDEWALK_M:
		return Color(0.0, 0.0, 1.0)
	if point.x < -0.5 or point.y < -0.5 or point.x > width - 0.5 or point.y > height - 0.5:
		return Color(0.0, 1.0, 0.0)
	return Color.BLACK


func _draw_guide_line(image: Image, a: Vector2, b: Vector2, color: Color, thickness: int) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) * 1.5))
	var radius := thickness / 2
	for step in range(steps + 1):
		var point := a.lerp(b, float(step) / float(steps))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x := roundi(point.x) + dx
				var y := roundi(point.y) + dy
				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					image.set_pixel(x, y, color)


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
