extends RefCounted
## Issue #19 (SCR-13): when a day closes, a card shows that day's result from the closed report; not on a load.


func test_the_day_end_card(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	var rc: ReportController = main.get_node("ReportController")
	t.ok(rc._day_end != null and not rc._day_end.visible, "no card before a day closes")
	app.state.close_day_once(0)
	app.call("_publish_snapshot")
	t.ok(rc._day_end.visible, "a day closed: the card shows")
	t.ok(rc._day_end_text.text.contains("DAY 0　営業結果") and rc._day_end_text.text.contains("売上高"), rc._day_end_text.text)
	(rc._day_end.find_child("DayEndNext", true, false) as Button).pressed.emit()
	t.ok(not rc._day_end.visible, "翌日の経営へ closes it")
	app.call("_publish_snapshot")
	t.ok(not rc._day_end.visible, "it does not come back without a new day")
	main.queue_free()
	await tree.process_frame
