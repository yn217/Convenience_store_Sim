extends RefCounted
## Issue #20: save and load through the app; a bad file never changes the running game.

const DIR := "user://test_saves_ui"


func _clean() -> void:
	for slot in ["slot_1", "slot_2", "slot_3"]:
		for ext in [".json", ".json.bak", ".json.tmp"]:
			var p := "%s/%s%s" % [DIR, slot, ext]
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)


func test_save_then_load_restores_the_game(t, tree) -> void:
	_clean()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	app.save_dir = DIR
	var sc: SaveController = main.get_node("SaveController")
	app.run_command({"command_id": "a", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	app.run_command({"command_id": "b", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 7})
	var cash: int = app.state.cash_yen
	t.ok(sc.save_slot().ok)
	t.ok(FileAccess.file_exists(DIR + "/slot_1.json"))
	# Change the game after saving, then load: the saved moment comes back.
	app.run_command({"command_id": "c", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 100})
	app.run_command({"command_id": "d", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	t.ok(app.state.cash_yen != cash)
	t.ok(sc.load_slot(false).ok)
	t.eq(app.state.cash_yen, cash)
	t.eq(app.state.grid.instances.size(), 1)
	t.eq(app.state.backroom_available("rice_001"), 7)
	var world := main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	t.eq(world.fixtures.size(), 1, "the store view shows the loaded layout")
	t.eq(app.run_command({"command_id": "a", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 6, "y": 5, "rotation": 0}).code, &"ALREADY_APPLIED", "command ids are restored too")
	main.queue_free()
	_clean()
	await tree.process_frame


func test_bad_files_leave_the_game_alone_and_offer_the_backup(t, tree) -> void:
	_clean()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	app.save_dir = DIR
	var sc: SaveController = main.get_node("SaveController")
	t.eq(sc.load_slot(false).message_key, &"save_empty")
	app.run_command({"command_id": "a", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 2})
	sc.save_slot()
	app.run_command({"command_id": "b", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 3})
	sc.save_slot()   # slot_1 now holds 5, the backup holds 2
	# Damage the main file.
	var f := FileAccess.open(DIR + "/slot_1.json", FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	app.run_command({"command_id": "c", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 1})
	var cash: int = app.state.cash_yen
	var r := sc.load_slot(false)
	t.eq(r.message_key, &"save_corrupt")
	t.eq(app.state.cash_yen, cash, "the running game is untouched")
	t.eq(app.state.backroom_available("rice_001"), 6)
	t.ok(sc._backup_button.visible, "the backup generation is offered")
	t.eq(FileAccess.get_file_as_string(DIR + "/slot_1.json"), "{ broken", "the damaged file is not overwritten by loading")
	t.ok(sc.load_slot(true).ok)
	t.eq(app.state.backroom_available("rice_001"), 2, "the backup holds the earlier save")
	# A structurally valid but inconsistent file is refused as well.
	var data := SaveGame.to_dict(app.state, "slot_2", "t")
	data["economy"]["cash_yen"] = -5
	SaveStore.write("slot_2", data, DIR)
	sc._slot.select(1)
	t.eq(sc.load_slot(false).message_key, &"save_invalid")
	t.eq(app.state.backroom_available("rice_001"), 2)
	main.queue_free()
	_clean()
	await tree.process_frame
