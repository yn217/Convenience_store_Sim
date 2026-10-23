extends RefCounted
## "空店舗のシーンが起動する" (Issue #2).


func test_main_scene_boots_empty_store(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var world := main.get_node("MainArea/StoreViewport/SubViewport/StoreWorld")
	t.eq(world.store_width, 16, "store width")
	t.eq(world.store_height, 12, "store height")
	t.eq(world.revision, 0, "first snapshot is revision 0")
	t.eq(world.get_node("ObjectSortRoot").get_child_count(), 0, "no fixtures in empty store")
	var label := main.get_node("GameHUD/StateLabel") as Label
	t.ok(label.text.contains("SETUP"), "HUD shows SETUP")
	t.eq(main.get_node("AppRoot").state.speed_setting, 0, "starts paused")
	main.queue_free()
	await tree.process_frame
