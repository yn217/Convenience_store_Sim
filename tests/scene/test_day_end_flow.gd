extends RefCounted
## Issue #19 checklist: the day-end card on a day with no sale and on a loss, its numbers against the ledger, the way
## from the card to the details and on to the next day, repeated presses, and a save / load after it.

const DIR := "user://test_saves_day_end_flow"


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return [main, main.get_node("AppRoot"), main.get_node("ReportController"), main.get_node("ProgressionController")]


func _midnight(app: Node, from_day: int) -> void:
	SimulationRunner.roll_day(app.state, from_day, from_day + 1)
	app.call("_publish_snapshot")


func _clean() -> void:
	for f in ["slot_1.json", "slot_1.json.bak", "slot_1.json.tmp"]:
		if FileAccess.file_exists("%s/%s" % [DIR, f]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [DIR, f]))


func test_a_day_with_no_sale(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var rc: ReportController = r[2]
	var pc: ProgressionController = r[3]
	_midnight(app, 0)
	t.ok(rc._day_end.visible, "the first day closes with its card")
	t.ok(rc._day_end_text.text.contains("DAY 0　営業結果") and rc._day_end_text.text.contains("売上高 ¥0"), rc._day_end_text.text)
	t.ok(rc._day_end_text.text.contains("今日の来店 0人 ／ 購買 0人"), "no visitor, no buyer: both 0")
	t.ok(pc._assistant.text.contains("お買い上げがありませんでした"), "her remark says how to start: %s" % pc._assistant.text)
	t.ok(rc._day_end_hourly.visible and rc._day_end_hourly.values().all(func(v): return int(v) == 0), "an empty chart, not an error")
	r[0].queue_free()
	await tree.process_frame


func test_a_loss_matches_the_ledger(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var rc: ReportController = r[2]
	app.state.ledger.cash_yen = 100000
	app.state.ledger.record("SALE", "l1", 300, 0, 10 * 3600, {"reservation_id": "r", "sku_id": "snack_001", "qty": 2}, {"revenue": 300, "cogs": 180})
	app.state.ledger.record("ELECTRICITY", "l2", -2000, 0, 11 * 3600, {}, {"expense": 2000})
	_midnight(app, 0)
	var report: Dictionary = app.state.daily_reports.back()
	var sum := LedgerSummary.summarize(app.state.ledger, 0)
	t.eq(int(report["revenue_yen"]), int(sum["revenue_yen"]), "revenue from the ledger")
	t.eq(int(report["gross_profit_yen"]), int(sum["gross_profit_yen"]))
	t.ok(int(report["operating_profit_yen"]) < 0, "a loss")
	t.ok(rc._day_end_text.text.contains("営業利益 -¥"), "the loss keeps its minus sign: %s" % rc._day_end_text.text)
	t.ok(rc._day_end_text.text.contains("粗利益 ¥120"), "gross profit is not the operating result")
	r[0].queue_free()
	await tree.process_frame


func test_details_then_the_next_day_and_repeated_presses(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Node = r[0]
	var app: Node = r[1]
	var rc: ReportController = r[2]
	var pc: ProgressionController = r[3]
	_midnight(app, 0)
	var more := rc._day_end.find_child("DayEndHistory", true, false) as Button
	more.pressed.emit()
	t.ok(not rc._day_end.visible, "履歴を詳しく見る closes the card")
	t.ok(main.ui.is_screen(), "and opens the management window")
	t.eq(main._tabs.get_tab_title(main._tabs.current_tab), "データ", "on the データ tab")
	t.ok(not pc._assistant.text.contains("お疲れさまでした"), "her day remark goes with the card")
	more.pressed.emit()   # a second press on the hidden card changes nothing
	t.ok(not rc._day_end.visible)
	main.call("close_screen")
	_midnight(app, 1)
	t.ok(rc._day_end.visible and rc._day_end_text.text.contains("DAY 1　営業結果"), "the next midnight brings the next card")
	var next := rc._day_end.find_child("DayEndNext", true, false) as Button
	next.pressed.emit()
	next.pressed.emit()
	t.ok(not rc._day_end.visible, "pressed twice: still just closed")
	app.call("_publish_snapshot")
	t.ok(not rc._day_end.visible, "and it stays closed")
	main.queue_free()
	await tree.process_frame


func test_a_load_after_the_day_end(t, tree) -> void:
	_clean()
	var r: Array = await _boot(tree)
	var main: Node = r[0]
	var app: Node = r[1]
	var rc: ReportController = r[2]
	app.save_dir = DIR
	var sc: SaveController = main.get_node("SaveController")
	_midnight(app, 0)
	(rc._day_end.find_child("DayEndNext", true, false) as Button).pressed.emit()
	t.ok(sc.save_slot().ok)
	t.ok(sc.load_slot(false).ok)
	await tree.process_frame
	t.ok(not rc._day_end.visible, "a load does not show the card again")
	t.eq(app.state.daily_reports.size(), 1, "the closed day is in the loaded history")
	t.ok(rc._label.text.begins_with("DAY 0"), "the daily report shows it: %s" % rc._label.text)
	main.queue_free()
	await tree.process_frame
	_clean()
