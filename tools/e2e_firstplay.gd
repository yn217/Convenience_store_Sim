extends SceneTree
## Scripted first play on the real renderer (QA E2E, #25): empty store -> build -> order -> restock -> open ->
## trade at x4 through the first day -> screenshots at each stage -> a summary line per stage.
##   Godot --path . --resolution 1920x1080 --script res://tools/e2e_firstplay.gd -- build/e2e
## Exit code 1 if a stage fails (a command refused, no sale, errors in the log are checked by the caller).

var _main: Node
var _app: Node
var _out := "build/e2e"
var _failed := false


func _initialize() -> void:
	_run()


func _cmd(id: String, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	var c := {"command_id": id, "kind": kind}
	c.merge(payload)
	var r: CommandResult = _app.run_command(c)
	if not r.ok:
		_failed = true
		print("E2E FAIL ", id, " ", r.code, " ", r.message_key)
	return r


func _shot(name: String) -> void:
	for i in 10:
		await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var s: GameState = _app.state
	print("E2E STAGE %s day=%d t=%d cash=%d customers=%d sold=%d" % [name, s.day, s.time_sec, s.cash_yen, s.customers.size(), int(s.visit_stats["purchased"])])


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	_main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(_main)
	for i in 5:
		await process_frame
	_app = _main.get_node("AppRoot")
	var s: GameState = _app.state
	await _shot("01_empty_store")
	_cmd("e1", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	_cmd("e2", &"PLACE_FIXTURE", {"type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	_cmd("e3", &"PLACE_FIXTURE", {"type_id": "fridge_drink", "x": 4, "y": 8, "rotation": 0})
	await _shot("02_built")
	_cmd("e4", &"ORDER_STOCK", {"sku_id": "rice_001", "qty": 24})
	_cmd("e5", &"ORDER_STOCK", {"sku_id": "drink_001", "qty": 12})
	_cmd("e6", &"RESTOCK", {"instance_id": "fx_0002", "slot_id": "row0", "sku_id": "rice_001", "qty": 12})
	_cmd("e7", &"RESTOCK", {"instance_id": "fx_0002", "slot_id": "row1", "sku_id": "rice_001", "qty": 12})
	_cmd("e8", &"RESTOCK", {"instance_id": "fx_0003", "slot_id": "row0", "sku_id": "drink_001", "qty": 12})
	await _shot("03_stocked")
	_cmd("e9", &"START_BUSINESS")
	s.balance["base_potential_visitors_per_day"] = 600
	_cmd("e10", &"SET_SPEED", {"speed": 4})
	var checkpoints := {10 * 3600: "04_morning", 16 * 3600: "05_afternoon", 23 * 3600: "06_night"}
	var next: Array = checkpoints.keys()
	next.sort()
	var guard := 0
	while s.day == 0 and guard < 200000 and not next.is_empty():
		await process_frame
		guard += 1
		if s.time_sec >= int(next[0]):
			await _shot(checkpoints[next[0]])
			next.pop_front()
	var past := 0
	while s.day == 0 and past < 20000:
		await process_frame
		past += 1
	await _shot("07_next_day")
	print("E2E DONE reports=%d purchased_today_reports=%s failed=%s" % [s.daily_reports.size(), str(s.daily_reports[0]["purchasing_customers"]) if s.daily_reports.size() > 0 else "none", str(_failed)])
	if s.daily_reports.is_empty() or int(s.daily_reports[0]["purchasing_customers"]) < 1:
		_failed = true
	quit(1 if _failed else 0)
