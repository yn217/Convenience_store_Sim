extends SceneTree
## Review-only cache injection: never changes asset definitions or saves.
func _initialize() -> void:
	_run()

func _run() -> void:
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	var world = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	var app = main.get_node("AppRoot")
	app.run_command({"command_id":"guided_review", "kind":&"PLACE_FIXTURE", "type_id":"shelf_general", "x":6, "y":3, "rotation":0})
	var presenter = world.get_node("ObjectSortRoot/FixturePresenter")
	var cache: Dictionary = presenter._sprites._cache
	var legacy: Dictionary = presenter._sprites.rotation_entry("shelf_general",0)
	var full := OS.get_cmdline_user_args().has("full")
	var half := OS.get_cmdline_user_args().has("half")
	var image = Image.load_from_file("res://assets/review/guided_assets/shelf_general_open_r0_v1/" + ("half_composite_candidate.png" if half else ("full_composite_candidate.png" if full else "empty_corrected.png")))
	var texture = ImageTexture.create_from_image(image)
	var candidate = {"anchor":Vector2(380,430),"layers":{"body":texture},"slots":{}}
	var base := "res://assets/review/guided_assets/shelf_general_open_r0_v1/"
	for zoom in [0.5,1.0,2.0]:
		world.zoom_at(world.projection.world_to_screen(6,3),zoom)
		for variant in ["before","candidate"]:
			cache["shelf_general/0"] = legacy if variant=="before" else candidate
			presenter._seg_cache.clear()
			presenter.queue_redraw()
			for i in 4: await process_frame
			root.get_texture().get_image().save_png(base+"game_%s%s_zoom%s.png" % ["half_" if half else ("full_" if full else ""),variant,str(zoom)])
	print("GUIDED_REVIEW_DONE: r0 ", "FULL" if full else "EMPTY", "; zoom 0.5/1/2 via world.zoom_at; no runtime approval")
	quit()
