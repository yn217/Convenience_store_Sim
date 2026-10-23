extends SceneTree
## Renders Main.tscn (non-headless) and saves a PNG for manual review.
## godot --path . --script res://tools/screenshot.gd -- <out.png> [tile_x tile_y]

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
	if args.size() >= 3:
		world.select_screen(world.projection.tile_center(Vector2i(int(args[1]), int(args[2]))))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " tiles=", world.tile_count())
	quit(0)
