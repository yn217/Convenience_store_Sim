extends SceneTree
## Renders Main.tscn (non-headless) and saves a PNG for manual review.
## godot --path . --script res://tools/screenshot.gd -- <out.png> [tile_x tile_y | demo]

func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var world := main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	if args.has("demo"):
		_demo(main, world)
	elif args.size() >= 3:
		world.select_screen(world.projection.tile_center(Vector2i(int(args[1]), int(args[2]))))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " tiles=", world.tile_count())
	quit(0)


## Demo layout: a register, shelves in different rotations, a selected shelf and a ghost.
func _demo(main: Node, world: Node2D) -> void:
	var app := main.get_node("AppRoot")
	var n := 0
	for p in [["register_basic", 3, 8, 0], ["shelf_general", 6, 3, 0], ["shelf_bread", 6, 7, 1], ["fridge_drink", 10, 2, 0], ["freezer_ice", 11, 7, 0], ["warmer_oden", 3, 3, 0]]:
		n += 1
		app.run_command({"command_id": "demo%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
	_fake_stock(world)
	# Customers around the shelf at (6,3) (1x2 along y): in front, behind, and past each end.
	world.customers = [
		{"customer_id": "c1", "tile": Vector2i(7, 3), "phase": "SELECT"}, {"customer_id": "c2", "tile": Vector2i(5, 4), "phase": "SELECT"},
		{"customer_id": "c3", "tile": Vector2i(6, 5), "phase": "SELECT"}, {"customer_id": "c4", "tile": Vector2i(6, 2), "phase": "SELECT"},
	]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			world.projection.set_zoom(float(a.substr(5)))
	world.select_screen(world.projection.tile_center(Vector2i(6, 3)))
	var bc := main.get_node("BuildController")
	bc.begin_place("shelf_snack")
	bc.rotate_preview()
	world.set_hover_screen(world.projection.tile_center(Vector2i(13, 4)))


## Visual check only: fills each fixture's rows to different levels (no stock system until #11).
func _fake_stock(world: Node2D) -> void:
	var levels := [0.0, 0.2, 0.5, 1.0]
	var i := 0
	for inst in world.fixtures:
		var def: Dictionary = world.fixture_catalog.get_type(inst["type_id"])
		var rows := {}
		for slot in def["shelf_slots"]:
			rows[slot["slot_id"]] = int(slot["capacity_units"] * levels[i % 4])
			i += 1
		world.shelf_stock[inst["instance_id"]] = rows
	world.get_node("ObjectSortRoot/FixturePresenter").queue_redraw()
