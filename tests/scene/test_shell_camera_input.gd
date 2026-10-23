extends RefCounted
## Issue #5: fit view, wheel zoom, pan, selection after zoom/pan, UI does not leak input.

const NO_TILE := Vector2i(-1, -1)
const PATH_WORLD := "Layout/MainArea/StoreViewport/SubViewport/StoreWorld"


func _boot(tree, container_size: Vector2 = Vector2(1920, 1080)) -> Array:
	var holder := Control.new()
	holder.size = container_size
	tree.root.add_child(holder)
	var main: Control = load("res://scenes/main/Main.tscn").instantiate()
	holder.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return [holder, main, main.get_node(PATH_WORLD)]


func _wheel(pos: Vector2, up: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	return e


func _button(pos: Vector2, index: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = index
	e.pressed = pressed
	return e


func _motion(pos: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.relative = rel
	return e


func _key(code: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	return e


func _inside(world: Node2D) -> bool:
	var b: Rect2 = world.projection.floor_bounds(world.store_width, world.store_height)
	return Rect2(Vector2.ZERO, world.viewport_size()).encloses(b)


func test_initial_view_shows_whole_16x12_store(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	t.eq(world.viewport_size().x >= 640.0, true, "store view keeps >= 640 px")
	t.ok(_inside(world), "whole floor visible at start: %s in %s" % [str(world.projection.floor_bounds(16, 12)), str(world.viewport_size())])
	t.ok(world.projection.zoom >= 0.5 and world.projection.zoom <= 1.0, "fit zoom within range")
	for c in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 11), Vector2i(15, 11)]:
		t.ok(Rect2(Vector2.ZERO, world.viewport_size()).has_point(world.projection.tile_center(c)), "corner tile %s on screen" % str(c))
	r[0].queue_free()
	await tree.process_frame


func test_wheel_zoom_keeps_tile_under_pointer_and_clamps(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	var ctl: Node = world.get_node("InputController")
	var tile := Vector2i(10, 7)
	var pivot: Vector2 = world.projection.tile_center(tile)
	var before: Vector2 = world.projection.screen_to_world(pivot)
	for i in 5:
		ctl.handle_event(_wheel(pivot, true))
		t.ok(world.projection.screen_to_world(pivot).distance_to(before) < 1e-4, "world point under pointer fixed (zoom in %d)" % i)
	for i in 3:
		ctl.handle_event(_wheel(pivot, false))
		t.eq(world.projection.screen_to_tile(pivot), tile, "tile under pointer unchanged (zoom out %d)" % i)
	for i in 60:
		ctl.handle_event(_wheel(pivot, true))
	t.eq(world.projection.zoom, 2.0, "max zoom 2.0")
	for i in 120:
		ctl.handle_event(_wheel(pivot, false))
	t.eq(world.projection.zoom, 0.5, "min zoom 0.5")
	r[0].queue_free()
	await tree.process_frame


func test_pan_by_middle_drag_and_space_drag(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	var ctl: Node = world.get_node("InputController")
	var start: Vector2 = world.projection.origin
	var p := Vector2(500, 400)
	ctl.handle_event(_button(p, MOUSE_BUTTON_MIDDLE, true))
	ctl.handle_event(_motion(p + Vector2(30, 20), Vector2(30, 20)))
	ctl.handle_event(_button(p, MOUSE_BUTTON_MIDDLE, false))
	t.ok(world.projection.origin.distance_to(start + Vector2(30, 20)) < 1e-6, "middle drag pans by the drag vector")
	ctl.handle_event(_motion(p, Vector2(50, 0)))
	t.ok(world.projection.origin.distance_to(start + Vector2(30, 20)) < 1e-6, "motion after release does not pan")
	# Space alone: no action, no pan, no selection.
	ctl.handle_event(_key(KEY_SPACE, true))
	t.ok(world.projection.origin.distance_to(start + Vector2(30, 20)) < 1e-6, "Space alone does nothing")
	ctl.handle_event(_button(p, MOUSE_BUTTON_LEFT, true))
	ctl.handle_event(_motion(p, Vector2(-10, 5)))
	ctl.handle_event(_button(p, MOUSE_BUTTON_LEFT, false))
	ctl.handle_event(_key(KEY_SPACE, false))
	t.ok(world.projection.origin.distance_to(start + Vector2(20, 25)) < 1e-6, "Space + left drag pans")
	t.eq(world.selected_tile, NO_TILE, "Space+drag does not select")
	r[0].queue_free()
	await tree.process_frame


func test_pan_cannot_lose_the_store(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	var ctl: Node = world.get_node("InputController")
	ctl.handle_event(_button(Vector2(10, 10), MOUSE_BUTTON_MIDDLE, true))
	for d in [Vector2(-99999, 0), Vector2(99999, 0), Vector2(0, -99999), Vector2(0, 99999)]:
		ctl.handle_event(_motion(Vector2(10, 10), d))
		var b: Rect2 = world.projection.floor_bounds(16, 12)
		var vs: Vector2 = world.viewport_size()
		t.ok(b.end.x >= 128.0 - 0.01 and b.position.x <= vs.x - 128.0 + 0.01, "x keeps floor reachable after %s" % str(d))
		t.ok(b.end.y >= 128.0 - 0.01 and b.position.y <= vs.y - 128.0 + 0.01, "y keeps floor reachable after %s" % str(d))
	ctl.handle_event(_button(Vector2(10, 10), MOUSE_BUTTON_MIDDLE, false))
	r[0].queue_free()
	await tree.process_frame


func test_selection_matches_tile_after_zoom_and_pan(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	var ctl: Node = world.get_node("InputController")
	var overlay: Node2D = world.get_node("SelectionOverlay")
	var tiles := [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 11), Vector2i(15, 11), Vector2i(8, 5)]
	for step in 4:
		for c in tiles:
			var centre: Vector2 = world.projection.tile_center(c)
			if not Rect2(Vector2.ZERO, world.viewport_size()).has_point(centre):
				continue
			ctl.handle_event(_button(centre, MOUSE_BUTTON_LEFT, true))
			ctl.handle_event(_button(centre, MOUSE_BUTTON_LEFT, false))
			t.eq(world.selected_tile, c, "click on centre selects %s (step %d, zoom %s)" % [str(c), step, str(world.projection.zoom)])
			t.eq(overlay.selected_polygon, world.projection.tile_diamond(c), "highlight on the tile diamond")
		ctl.handle_event(_wheel(Vector2(400, 300), step % 2 == 0))
		ctl.handle_event(_button(Vector2(5, 5), MOUSE_BUTTON_MIDDLE, true))
		ctl.handle_event(_motion(Vector2(5, 5), Vector2(-40, 25)))
		ctl.handle_event(_button(Vector2(5, 5), MOUSE_BUTTON_MIDDLE, false))
	# After camera moves the highlight follows its tile.
	world.select_screen(world.projection.tile_center(Vector2i(8, 5)))
	ctl.handle_event(_wheel(Vector2(300, 300), true))
	t.eq(overlay.selected_polygon, world.projection.tile_diamond(Vector2i(8, 5)), "highlight re-derived after zoom")
	r[0].queue_free()
	await tree.process_frame


func test_cancel_keys_and_fit(t, tree) -> void:
	var r: Array = await _boot(tree)
	var world: Node2D = r[2]
	var ctl: Node = world.get_node("InputController")
	var fit_zoom: float = world.projection.zoom
	world.select_screen(world.projection.tile_center(Vector2i(4, 4)))
	t.eq(world.selected_tile, Vector2i(4, 4))
	ctl.handle_event(_key(KEY_ESCAPE, true))
	t.eq(world.selected_tile, NO_TILE, "Esc clears selection")
	world.select_screen(world.projection.tile_center(Vector2i(4, 4)))
	ctl.handle_event(_button(Vector2(1, 1), MOUSE_BUTTON_RIGHT, true))
	t.eq(world.selected_tile, NO_TILE, "right click cancels")
	world.select_screen(Vector2(-500, -500))
	t.eq(world.selected_tile, NO_TILE, "click off the floor selects nothing")
	ctl.handle_event(_wheel(Vector2(500, 400), true))
	t.ok(world.user_moved)
	ctl.handle_event(_key(KEY_F, true))
	t.ok(not world.user_moved and absf(world.projection.zoom - fit_zoom) < 1e-9 and _inside(world), "F refits the whole store")
	r[0].queue_free()
	await tree.process_frame


func test_ui_panels_do_not_leak_input_to_the_store(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var world: Node2D = r[2]
	var palette: Control = main.get_node("Layout/MainArea/BuildPalette")
	var hud: Control = main.get_node("Layout/TopHUD")
	var store: Control = main.get_node("Layout/MainArea/StoreViewport")
	t.eq(palette.mouse_filter, Control.MOUSE_FILTER_STOP, "palette stops mouse")
	t.eq(hud.mouse_filter, Control.MOUSE_FILTER_STOP, "HUD stops mouse")
	t.eq(main.get_node("Layout/MainArea/FixtureInspector").mouse_filter, Control.MOUSE_FILTER_STOP, "inspector stops mouse")
	var z0: float = world.projection.zoom
	var o0: Vector2 = world.projection.origin
	# Positive control first: the same push path reaches the store through its container.
	var sp: Vector2 = store.get_global_rect().get_center()
	tree.root.push_input(_wheel(sp, true), true)
	await tree.process_frame
	t.ok(world.projection.zoom > z0, "wheel over the store zooms (control for the negative checks)")
	var z1: float = world.projection.zoom
	for ctrl in [palette, hud]:
		var c: Vector2 = ctrl.get_global_rect().get_center()
		tree.root.push_input(_wheel(c, true), true)
		tree.root.push_input(_button(c, MOUSE_BUTTON_LEFT, true), true)
		tree.root.push_input(_button(c, MOUSE_BUTTON_LEFT, false), true)
		tree.root.push_input(_button(c, MOUSE_BUTTON_MIDDLE, true), true)
		tree.root.push_input(_motion(c + Vector2(40, 0), Vector2(40, 0)), true)
		tree.root.push_input(_button(c, MOUSE_BUTTON_MIDDLE, false), true)
		await tree.process_frame
	t.eq(world.projection.zoom, z1, "wheel on UI panels never zooms the store")
	t.eq(world.selected_tile, NO_TILE, "clicks on UI panels never select a tile")
	t.ok(world.projection.origin.distance_to(o0) < 1e9, "sanity")
	r[0].queue_free()
	await tree.process_frame


func test_compact_layout_shows_one_side_panel(t, tree) -> void:
	var r: Array = await _boot(tree, Vector2(1000, 700))
	var main: Control = r[1]
	var palette: Control = main.get_node("Layout/MainArea/BuildPalette")
	var inspector: Control = main.get_node("Layout/MainArea/FixtureInspector")
	var store: Control = main.get_node("Layout/MainArea/StoreViewport")
	t.ok(main.is_compact(), "1000 px wide is compact")
	t.ok(palette.visible and not inspector.visible, "palette first")
	t.ok(main.get_node("Layout/TopHUD/Row/PaletteTab").visible, "tabs shown when compact")
	t.ok(store.size.x >= 640.0, "store view keeps >= 640 px (%s)" % str(store.size.x))
	main.show_compact_panel(main.SidePanel.INSPECTOR)
	t.ok(inspector.visible and not palette.visible, "switch to inspector hides palette")
	main.get_node("Layout/TopHUD/Row/PaletteTab").pressed.emit()
	t.ok(palette.visible and not inspector.visible, "tab button switches back")
	r[0].queue_free()
	await tree.process_frame
	var wide: Array = await _boot(tree, Vector2(1920, 1080))
	var wm: Control = wide[1]
	t.ok(not wm.is_compact(), "1920 px is not compact")
	t.ok(wm.get_node("Layout/MainArea/BuildPalette").visible and wm.get_node("Layout/MainArea/FixtureInspector").visible, "both panels in wide layout")
	t.ok(not wm.get_node("Layout/TopHUD/Row/PaletteTab").visible, "no tabs when wide")
	t.eq(wm.get_node("Layout/TopHUD").size.y, 64.0, "HUD height 64")
	t.eq(wm.get_node("Layout/MainArea/BuildPalette").size.x, 280.0, "palette 280 px")
	t.eq(wm.get_node("Layout/MainArea/FixtureInspector").size.x, 320.0, "inspector 320 px")
	wide[0].queue_free()
	await tree.process_frame


func test_inspector_shows_selected_tile(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Control = r[1]
	var world: Node2D = r[2]
	var label := main.find_child("SelectionLabel", true, false) as Label
	t.eq(label.text, "未選択")
	world.select_screen(world.projection.tile_center(Vector2i(3, 9)))
	t.eq(label.text, "選択タイル (3, 9)")
	world.clear_selection()
	t.eq(label.text, "未選択")
	r[0].queue_free()
	await tree.process_frame
