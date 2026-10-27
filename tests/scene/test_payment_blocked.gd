extends RefCounted
## Issue #20 (SCR-14): when the day's costs cannot be paid, a panel says so with the unpaid amount and offers to load
## the last save or start a new game; the last save is the slot written most recently.


func test_the_panel_and_loading_the_last_save(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	app.save_dir = "user://test_blocked_saves"
	DirAccess.make_dir_recursive_absolute(app.save_dir)
	for id in SaveStore.SLOTS:
		DirAccess.remove_absolute(SaveStore.path_for(id, app.save_dir))
	var bc: BusinessController = main.get_node("BusinessController")
	await tree.process_frame
	t.ok(bc._blocked != null and not bc._blocked.visible, "no panel while the store can go on")
	t.eq(SaveStore.latest_slot(app.save_dir), "", "no save yet")
	t.ok(app.run_command({"command_id": "s1", "kind": &"SAVE_GAME", "slot_id": "slot_2"}).ok, "saved in slot 2")
	t.eq(SaveStore.latest_slot(app.save_dir), "slot_2", "the last save is slot 2")
	app.state.business_state = GameState.PAYMENT_BLOCKED
	app.state.unpaid_cost_yen = 25000
	app.run_command({"command_id": "s2", "kind": &"SAVE_GAME", "slot_id": "slot_3"})   # any command republishes
	app.state.business_state = GameState.PAYMENT_BLOCKED
	bc.apply_snapshot(app.state.snapshot())
	t.ok(bc._blocked.visible, "the panel shows")
	t.ok(bc._blocked_text.text.contains("¥25,000"), "with the unpaid amount: %s" % bc._blocked_text.text)
	t.ok(not bc._blocked_load.disabled, "a save to load")
	t.ok(BusinessController.blocked_text(1000, false).contains("セーブがありません"), "and says so without one")
	DirAccess.remove_absolute(SaveStore.path_for("slot_3", app.save_dir))
	t.ok(bc.load_latest().ok, "the last good save loads")
	t.eq(app.state.business_state, GameState.SETUP, "the store is back as it was saved")
	main.queue_free()
	await tree.process_frame
