extends RefCounted
## "空店舗のシーンが起動する" (Issue #2).


func test_main_scene_boots_empty_store(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var world := main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	t.eq(world.store_width, 16, "store width")
	t.eq(world.store_height, 12, "store height")
	t.eq(world.revision, 0, "first snapshot is revision 0")
	t.eq(world.fixtures.size(), 0, "no fixtures in empty store")
	t.eq((main.get_node("Layout/TopHUD/Row/StateLabel") as Label).text, "準備中", "HUD shows SETUP state")
	t.eq((main.get_node("Layout/TopHUD/Row/CashLabel") as Label).text, "所持金 ¥500,000", "HUD shows starting cash")
	t.eq((main.get_node("Layout/TopHUD/Row/SpeedLabel") as Label).text, "速度 停止", "HUD shows paused")
	t.eq(main.get_node("AppRoot").state.speed_setting, 0, "starts paused")
	main.queue_free()
	await tree.process_frame
