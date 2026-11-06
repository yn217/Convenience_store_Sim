extends SceneTree
## A run-in store's day in numbers: the sample layout (data/layouts/sample_store_v1.json), two more registers if
## asked, stock ordered every morning so that demand and the staff decide the sales. No scene, no renderer.
##   Godot --headless --path . --script res://tools/measure_day_sales.gd -- --days=3 --registers=2 --set=key=json --merge=file.json
## --set / --merge override balance keys for a trial, without touching the data file.

const SampleLayout := preload("res://tools/sample_layout.gd")
const Seeds := preload("res://tests/support/test_seeds.gd")
const ORDER_PER_SKU := 500
const ROOM_SPOTS := [[0, 4, 0], [0, 7, 0], [0, 1, 0], [6, 9, 0]]


func _initialize() -> void:
	var days := 3
	var registers := 1
	var staff := 0
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.trim_prefix("--days="))
		elif a.begins_with("--registers="):
			registers = int(a.trim_prefix("--registers="))
		elif a.begins_with("--staff="):
			staff = int(a.trim_prefix("--staff="))
		elif a.begins_with("--merge="):
			balance.merge(JSON.parse_string(FileAccess.get_file_as_string(a.trim_prefix("--merge="))), true)
		elif a.begins_with("--set="):
			var kv := a.trim_prefix("--set=").split("=", true, 1)
			balance[kv[0]] = JSON.parse_string(kv[1])
	if staff > 0:   # a run-in store: more hands, and a staff room to rest in
		var crew: Array = []
		for i in staff:
			crew.append(balance["starting_staff"][i % 2].duplicate(true))
			crew[i]["name"] = "店員%d" % i
		balance["starting_staff"] = crew
		balance["staff_cap_without_room"] = staff
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 100000000
	var cmds := GameCommands.new(s)
	var n := 0
	for p in SampleLayout.placements():
		n += 1
		cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": p[0], "x": p[1], "y": p[2], "rotation": p[3]})
	for i in registers - 1:
		for spot in [[10, 5], [10, 2], [7, 5], [13, 8]]:
			n += 1
			if cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": spot[0], "y": spot[1], "rotation": 0}).ok:
				break
	if staff > 0:
		for spot in ROOM_SPOTS:
			n += 1
			if cmds.execute({"command_id": "pl%d" % n, "kind": &"PLACE_FIXTURE", "type_id": "staff_room_m", "x": spot[0], "y": spot[1], "rotation": spot[2]}).ok:
				print("staff room at ", spot)
				break
	var runner := SimulationRunner.new(s)
	for day in days:
		_stock(s, cmds, day)
		if day == 0:
			cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
		var lost0 := int(s.visit_stats["lost"])
		while s.day == day:
			runner._run_step()
		var r: Dictionary = s.daily_reports[-1]
		var buyers := int(r["purchasing_customers"])
		print("day %d sales %d buyers %d visitors %d lost %d unit %d cash %d staff %d" % [day, int(r["revenue_yen"]), buyers, int(r["visitors"]),
			int(s.visit_stats["lost"]) - lost0, int(r["revenue_yen"]) / maxi(buyers, 1), s.ledger.cash_yen, s.staff.size()])
	quit(0)


## Fills each shelf slot once, with the slot's own SKU spread over the fixture's categories, and tops up the backroom.
func _stock(s: GameState, cmds: GameCommands, day: int) -> void:
	var cats := {}
	var n := 0
	for id in s.grid.instances:
		var def := s.fixtures.get_type(s.grid.instances[id]["type_id"])
		var k := n   # the next fixture of a kind starts further along the catalog: the whole range is on sale
		for slot in def["shelf_slots"]:
			var skus: Array = s.products.skus.values().filter(func(x): return (def["allowed_categories"] as Array).has(x["category"]))
			if skus.is_empty():
				continue
			var sku: Dictionary = skus[k % skus.size()]
			k += 1
			cats[sku["sku_id"]] = true
			n += 1
			cmds.execute({"command_id": "o%d_%d" % [day, n], "kind": &"ORDER_STOCK", "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
			cmds.execute({"command_id": "r%d_%d" % [day, n], "kind": &"RESTOCK", "instance_id": id, "slot_id": slot["slot_id"], "sku_id": sku["sku_id"], "qty": slot["capacity_units"]})
	for sku_id in cats:
		n += 1
		cmds.execute({"command_id": "b%d_%d" % [day, n], "kind": &"ORDER_STOCK", "sku_id": sku_id, "qty": ORDER_PER_SKU})
