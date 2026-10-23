extends SceneTree
## Saves a screenshot of the running game with a stocked store and customers (visual review, #61).
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_screen.gd -- build/shot.png

const PLAN := [
	["register_basic", 13, 5, 0], ["shelf_general", 3, 2, 0], ["shelf_onigiri", 3, 5, 0], ["shelf_noodle", 3, 8, 0],
	["shelf_bread", 6, 2, 0], ["shelf_snack", 6, 5, 0], ["shelf_general", 6, 8, 0], ["fridge_drink", 9, 2, 0],
	["fridge_dessert", 9, 5, 0], ["freezer_ice", 11, 9, 0], ["warmer_oden", 13, 2, 0], ["shelf_general", 1, 11, 1],
	["shelf_onigiri", 4, 11, 1], ["shelf_snack", 7, 11, 1], ["shelf_bread", 10, 7, 1], ["shelf_noodle", 14, 9, 1],
	["shelf_general", 14, 11, 1], ["fridge_drink", 1, 9, 1], ["shelf_snack", 12, 7, 1], ["fridge_dessert", 8, 9, 1],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_png := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shot.png"
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var app: Node = main.get_node("AppRoot")
	var s: GameState = app.state
	s.ledger.cash_yen = 5000000
	var placed := 0
	for p in (PLAN if not OS.get_cmdline_user_args().has("empty") else []):
		var r: CommandResult = app.run_command({"command_id": "pf%d" % placed, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
		if r.ok:
			placed += 1
	var n := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		for slot in def["shelf_slots"]:
			var cat: String = def["allowed_categories"][0]
			for sku in s.products.skus.values():
				if sku["category"] == cat:
					n += 1
					app.run_command({"command_id": "po%d" % n, "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					app.run_command({"command_id": "pr%d" % n, "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
					break
	app.run_command({"command_id": "pstart", "kind": &"START_BUSINESS"})
	s.balance["base_potential_visitors_per_day"] = 200000
	s.balance["max_active_customers"] = 30
	s.speed_setting = 4
	var guard := 0
	while s.customers.size() < 30 and guard < 20000 and not OS.get_cmdline_user_args().has("empty") and not OS.get_cmdline_user_args().has("nocust"):
		app.runner.process_frame(1.0 / 15.0)
		guard += 1
	for i in 240:
		app.runner.process_frame(1.0 / 15.0)
	for i in 30:
		await process_frame
	get_root().get_texture().get_image().save_png(out_png)
	quit(0)
