extends RefCounted
## UI redesign Phase 1 (overlay design): which panels show in each mode, that the store world is the full-window
## bottom layer, that the camera and the world size never change when panels open or close, and that only panels and
## the modal dimmer take mouse input.

const ORIGIN_POINT := Vector2(900, 540)   # centre-ish of the store; no panel covers it in any mode
const STORE := "Layout/MainArea/StoreViewport"
const WORLD := "Layout/MainArea/StoreViewport/SubViewport/StoreWorld"


func _boot(tree) -> Node:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return main


## Visible controls that stop mouse input and contain the point.
func _blockers_at(main: Node, point: Vector2) -> Array:
	var out: Array = []
	for n in main.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_global_rect().has_point(point):
			out.append(c.name)
	return out


func _panels(main: Node) -> Dictionary:
	return {
		"palette": main.get_node("Layout/MainArea/BuildPalette").visible,
		"inspector": main.get_node("Layout/MainArea/FixtureInspector").visible,
		"window": main.find_child("ManagementWindow", true, false).visible,
		"dimmer": main.find_child("ScreenDimmer", true, false).visible,
	}


## Drives the mode through the public UI commands (rail, B key, store selection, window tab).
func _show(main: Node, mode: String) -> void:
	var world: Node2D = main.get_node(WORLD)
	if mode == "NORMAL":
		if main.mode_name() == "SCREEN":
			main.call("close_screen")
		if main.mode_name() == "BUILD":
			main.call("close_build")
		world.clear_selection()
	elif mode == "BUILD":
		if main.mode_name() != "BUILD":
			main.call("toggle_build")
	elif mode == "SELECTED":
		world.select_screen(world.projection.tile_center(Vector2i(3, 9)))
	elif mode == "SCREEN":
		main.call("open_screen_tab", "商品")


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func test_normal_shows_only_the_store_hud_rail_and_summary(t, tree) -> void:
	var main := await _boot(tree)
	t.eq(main.mode_name(), "NORMAL", "starts in normal")
	var p := _panels(main)
	t.ok(not p["palette"] and not p["inspector"] and not p["window"] and not p["dimmer"], "no build palette, inspector, window or dimmer in NORMAL")
	t.ok(main.get_node("Layout/TopHUD").is_visible_in_tree(), "HUD shown")
	t.ok(main.get_node("Layout/MainArea/LeftNav").is_visible_in_tree(), "rail shown")
	t.ok(main.find_child("MetricBar", true, false).is_visible_in_tree(), "summary shown")
	t.eq(main.get_node("Layout/MainArea/LeftNav").entry_count(), 5, "rail has its entries")
	main.queue_free()
	await tree.process_frame


func test_each_mode_shows_its_own_panel(t, tree) -> void:
	var main := await _boot(tree)
	_show(main, "BUILD")
	await tree.process_frame
	var p := _panels(main)
	t.eq(main.mode_name(), "BUILD", "BUILD mode")
	t.ok(p["palette"] and not p["inspector"] and not p["window"], "BUILD: palette only")
	_show(main, "NORMAL")
	_show(main, "SELECTED")
	await tree.process_frame
	p = _panels(main)
	t.eq(main.mode_name(), "SELECTED", "SELECTED mode")
	t.ok(p["inspector"] and not p["palette"] and not p["window"], "SELECTED: inspector only")
	_show(main, "NORMAL")
	_show(main, "SCREEN")
	await tree.process_frame
	p = _panels(main)
	t.eq(main.mode_name(), "SCREEN", "SCREEN mode")
	t.ok(p["window"] and p["dimmer"] and not p["palette"] and not p["inspector"], "SCREEN: window and dimmer only")
	main.queue_free()
	await tree.process_frame


func test_world_size_never_changes(t, tree) -> void:
	var main := await _boot(tree)
	var store := main.get_node(STORE) as Control
	var window_size: Vector2 = main.get_viewport_rect().size
	var all_same := store.size.is_equal_approx(window_size)
	for mode in ["BUILD", "NORMAL", "SELECTED", "NORMAL", "SCREEN", "NORMAL"]:
		_show(main, mode)
		await tree.process_frame
		await tree.process_frame
		all_same = all_same and store.size.is_equal_approx(window_size)
	t.ok(all_same, "the world fills the window and keeps that size in every mode")
	t.ok(store.get_global_rect().position.is_zero_approx(), "world starts at the window corner")
	main.queue_free()
	await tree.process_frame


func test_camera_does_not_move_when_panels_open(t, tree) -> void:
	var main := await _boot(tree)
	var world: Node2D = main.get_node(WORLD)
	var origin0: Vector2 = world.projection.origin
	var zoom0: float = world.projection.zoom
	for mode in ["BUILD", "SELECTED", "SCREEN", "NORMAL"]:
		_show(main, mode)
		await tree.process_frame
	t.ok(world.projection.origin.is_equal_approx(origin0) and is_equal_approx(world.projection.zoom, zoom0), "opening and closing panels keeps the camera")
	main.queue_free()
	await tree.process_frame


func test_store_fit_keeps_clear_of_the_hud_rail_and_summary(t, tree) -> void:
	var main := await _boot(tree)
	var world: Node2D = main.get_node(WORLD)
	t.ok(world.safe_inset.x >= 80.0 and world.safe_inset.y >= 64.0 and world.safe_inset.w >= 72.0, "safe area covers rail, HUD and summary")
	world.fit_view()
	var floor_rect: Rect2 = world.projection.floor_bounds(world.store_width, world.store_height)
	var top_left: Vector2 = world.projection.origin + floor_rect.position * world.projection.zoom
	t.ok(top_left.x >= world.safe_inset.x - 1.0 and top_left.y >= world.safe_inset.y - 1.0, "fitted floor starts right of the rail and under the HUD")
	main.queue_free()
	await tree.process_frame


func test_only_panels_and_the_dimmer_block_mouse(t, tree) -> void:
	var main := await _boot(tree)
	t.eq(_blockers_at(main, ORIGIN_POINT), [], "NORMAL: the empty store takes the click")
	_show(main, "BUILD")
	await tree.process_frame
	t.eq(_blockers_at(main, ORIGIN_POINT), [], "BUILD: empty store area still reaches the world")
	var palette_point: Vector2 = main.get_node("Layout/MainArea/BuildPalette").get_global_rect().get_center()
	t.ok(_blockers_at(main, palette_point).has("BuildPalette"), "BUILD: the palette takes its own clicks")
	_show(main, "NORMAL")
	_show(main, "SELECTED")
	await tree.process_frame
	t.eq(_blockers_at(main, ORIGIN_POINT), [], "SELECTED: empty store area reaches the world")
	_show(main, "NORMAL")
	_show(main, "SCREEN")
	await tree.process_frame
	t.ok(_blockers_at(main, ORIGIN_POINT).has("ScreenDimmer"), "SCREEN: the dimmer blocks the store")
	main.call("close_screen")
	await tree.process_frame
	t.ok(not _blockers_at(main, ORIGIN_POINT).has("ScreenDimmer"), "after closing no dimmer remains")
	main.queue_free()
	await tree.process_frame


func test_closing_leaves_no_invisible_blocker(t, tree) -> void:
	var main := await _boot(tree)
	for mode in ["BUILD", "SELECTED", "SCREEN"]:
		_show(main, mode)
		await tree.process_frame
		_show(main, "NORMAL")
		await tree.process_frame
	for node_name in ["ScreenDimmer", "ManagementWindow", "BuildPalette", "FixtureInspector"]:
		var node := main.find_child(node_name, true, false) as Control
		t.ok(node != null and not node.is_visible_in_tree(), "%s hidden after closing" % node_name)
	t.eq(_blockers_at(main, ORIGIN_POINT), [], "only the store takes the click after closing")
	main.queue_free()
	await tree.process_frame


func test_esc_and_b_keys_move_between_modes(t, tree) -> void:
	var main := await _boot(tree)
	main.call("_input", _key(KEY_B))
	t.eq(main.mode_name(), "BUILD", "B opens build")
	main.call("_input", _key(KEY_ESCAPE))
	t.eq(main.mode_name(), "NORMAL", "Esc leaves build")
	_show(main, "SCREEN")
	main.call("_input", _key(KEY_B))
	t.eq(main.mode_name(), "SCREEN", "B is ignored while a window is open")
	main.call("_input", _key(KEY_ESCAPE))
	t.eq(main.mode_name(), "NORMAL", "Esc closes the window")
	main.queue_free()
	await tree.process_frame


func test_state_badge_opens_the_management_tab(t, tree) -> void:
	var main := await _boot(tree)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.call("_on_state_gui_input", click)
	t.eq(main.mode_name(), "SCREEN", "the state badge opens a screen")
	t.eq(main.get("ui").screen_tab, "経営", "on the 経営 tab")
	main.queue_free()
	await tree.process_frame
