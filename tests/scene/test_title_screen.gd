extends RefCounted
## Issue #28 (SCR-05): the title screen — 新規ゲーム / 続きから / 設定 / 終了; 続きから is off without a save and loads the
## slot saved last; the sound setting keeps the game's other settings.


func test_the_title_screen(t, tree) -> void:
	var dir := "user://test_title_saves"
	DirAccess.make_dir_recursive_absolute(dir)
	for id in SaveStore.SLOTS:
		DirAccess.remove_absolute(SaveStore.path_for(id, dir))
	var title: TitleScreen = load("res://scenes/title/Title.tscn").instantiate()
	title.save_dir = dir
	tree.root.add_child(title)
	await tree.process_frame
	for n in ["NewGame", "Continue", "Settings", "Quit"]:
		t.ok(title.find_child(n, true, false) != null, n + " is there")
	t.ok(title._continue.disabled, "no save: 続きから is off")
	t.eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/title/Title.tscn", "the game starts on the title")
	# a save makes 続きから available
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	app.save_dir = dir
	app.run_command({"command_id": "p1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	t.ok(app.run_command({"command_id": "s1", "kind": &"SAVE_GAME", "slot_id": "slot_1"}).ok, "saved")
	main.queue_free()
	await tree.process_frame
	title.refresh()
	t.ok(not title._continue.disabled, "with a save: 続きから is on")
	# 続きから: the next game loads that slot first
	AppRoot.start_slot = "slot_1"
	var again: Node = load("res://scenes/main/Main.tscn").instantiate()
	again.get_node("AppRoot").save_dir = dir
	tree.root.add_child(again)
	await tree.process_frame
	t.eq((again.get_node("AppRoot") as AppRoot).state.grid.instances.size(), 1, "the saved store is back")
	t.eq(AppRoot.start_slot, "", "loaded once")
	again.queue_free()
	title.queue_free()
	await tree.process_frame
