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
	t.ok(rc._day_end_text.text.contains("今日のイベント：なし") and rc._day_end_text.text.contains("獲得した称号："), "the day's history follows the result")
	(rc._day_end.find_child("DayEndNext", true, false) as Button).pressed.emit()
	t.ok(not rc._day_end.visible, "翌日の経営へ closes it")
	app.call("_publish_snapshot")
	t.ok(not rc._day_end.visible, "it does not come back without a new day")
	main.queue_free()
	await tree.process_frame


## The history lines: the day's event, its challenge achieved or not (none on day 0), and the titles won that day.
func test_the_days_history_lines(t, _tree) -> void:
	var lines := ReportController.day_history_lines(1, {"event": "雨の日セール", "titles": ["はじめての一品", "常連さん"]},
			{"completed_daily_challenge_ids": [ProgressionService.challenge_event_id(1, ProgressionService.challenge_for_day(1))]})
	t.eq(lines[0], "今日のイベント：雨の日セール")
	t.ok(lines[1].begins_with("チャレンジ：達成") and lines[1].contains("3件以上の会計"), lines[1])
	t.eq(lines[2], "獲得した称号：はじめての一品、常連さん")
	var quiet := ReportController.day_history_lines(2, {}, {})
	t.ok(quiet[1].begins_with("チャレンジ：未達成"), "not achieved: 未達成")
	t.eq(ReportController.day_history_lines(0, {}, {}).size(), 2, "day 0 has no challenge")

