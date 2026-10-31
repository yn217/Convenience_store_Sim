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
	var pc: ProgressionController = main.get_node("ProgressionController")
	t.ok(pc._stage.visible and pc._assistant.text.begins_with("今日もお疲れさまでした"), "小春六花 comments on the day: %s" % pc._assistant.text)
	(rc._day_end.find_child("DayEndNext", true, false) as Button).pressed.emit()
	t.ok(not rc._day_end.visible, "翌日の経営へ closes it")
	t.ok(not pc._assistant.text.begins_with("今日もお疲れさまでした"), "and her remark goes with it")
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



## #19/#32 営業結果: her remark follows the day's numbers: profit or loss, the change from the day before, one tip.
func test_the_day_end_remark(t, _tree) -> void:
	var day := {"purchasing_customers": 12, "operating_profit_yen": 3000, "revenue_yen": 9000, "lost_customers": 0,
			"wastage_yen": 0, "balked_customers": 0}
	t.eq(ProgressionText.day_end_remark([]), "", "no closed day: nothing to say")
	var good := ProgressionText.day_end_remark([day])
	t.ok(good.begins_with("今日もお疲れさまでした！黒字") and good.ends_with("素敵なお店にしていきましょうね！"), good)
	var worse := day.duplicate()
	worse.merge({"operating_profit_yen": -500, "revenue_yen": 7000, "lost_customers": 3}, true)
	var lines := ProgressionText.day_end_remark([day, worse]).split("\n")
	t.ok(lines[0].contains("赤字"), lines[0])
	t.ok(lines[1].contains("2,000") and lines[1].contains("減りました"), lines[1])
	t.ok(lines[2].contains("買えずに帰ったお客様が 3 人"), lines[2])
	worse["balked_customers"] = 2
	t.ok(ProgressionText.day_end_remark([worse]).contains("混雑で引き返したお客様が 2 人"), "a crowd at the door comes first")
	var quiet := day.duplicate()
	quiet["purchasing_customers"] = 0
	t.ok(ProgressionText.day_end_remark([quiet]).contains("お買い上げがありませんでした"), "no sale: how to start")


## #24 売れ筋ランキング in the データ tab: today's best sellers with a bar against the leader.
func test_the_best_seller_ranking(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	var rc: ReportController = main.get_node("ReportController")
	t.eq(rc._ranking_note.text, "今日はまだ商品が売れていません")
	t.ok(not rc._rank_rows[0]["box"].visible)
	app.state.ledger.cash_yen = 100000
	for i in 3:
		app.state.ledger.record("SALE", "rk%d" % i, 150, app.state.day, 0, {"reservation_id": "r%d" % i, "sku_id": "snack_001", "qty": 1}, {"revenue": 150})
	app.state.ledger.record("SALE", "rk9", 300, app.state.day, 0, {"reservation_id": "r9", "sku_id": "drink_001", "qty": 1}, {"revenue": 300})
	app.call("_publish_snapshot")
	t.eq(rc._ranking_note.text, "本日・確定した会計から")
	t.ok(rc._rank_rows[0]["amount"].text.begins_with("3個"), rc._rank_rows[0]["amount"].text)
	t.eq(rc._rank_rows[0]["bar"].value, 1.0)
	t.ok(is_equal_approx(rc._rank_rows[1]["bar"].value, 1.0 / 3.0), "the second bar is a third of the leader")
	t.ok(not rc._rank_rows[2]["box"].visible)
	t.ok(rc._ranking_categories.text.begins_with("カテゴリ別：おかし 3"), rc._ranking_categories.text)
	t.eq(rc._hourly.values().reduce(func(acc, v): return acc + v, 0), 750, "the hourly chart holds today's sales")
	(main.find_child("RankingDay_yesterday", true, false) as Button).pressed.emit()
	t.eq(rc._ranking_note.text, "前日は商品が売れていません", "前日: day 0 has no day before")
	t.ok(not rc._rank_rows[0]["box"].visible)
	(main.find_child("RankingDay_today", true, false) as Button).pressed.emit()
	t.ok(rc._rank_rows[0]["box"].visible, "本日 again")
	var card := rc._ranking_note.get_parent()
	while card != null and not (card is TabContainer):
		card = card.get_parent()
	t.ok(card != null, "the ranking card sits in a management tab")
	main.queue_free()
	await tree.process_frame


## #19: at a real midnight (the day moves on first) the card shows the closed day's sales by hour.
func test_the_day_end_card_has_the_hourly_chart(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	var rc: ReportController = main.get_node("ReportController")
	app.state.ledger.cash_yen = 100000
	app.state.ledger.record("SALE", "h1", 400, 0, 15 * 3600, {"reservation_id": "r", "sku_id": "snack_001", "qty": 1}, {"revenue": 400})
	SimulationRunner.roll_day(app.state, 0, 1)
	app.call("_publish_snapshot")
	t.ok(rc._day_end.visible)
	t.ok(rc._day_end_hourly.visible, "the closed day's hours are on the card")
	t.eq(rc._day_end_hourly.values()[15], 400)
	main.queue_free()
	await tree.process_frame
