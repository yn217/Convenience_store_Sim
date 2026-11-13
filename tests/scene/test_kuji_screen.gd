extends RefCounted
## Issue #138 限定くじ管理: the mockup screen opens from the 店頭くじ card, shows the 星空マスコットくじ set live over
## its art, buys the set through START_LOTTERY, and steps the corner assistant aside while it is open.


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return [main, main.get_node("AppRoot"), main.get_node("LotteryController")]


func test_the_screen_shows_the_set_and_buys_it(t, tree) -> void:
	var r: Array = await _boot(tree)
	var main: Node = r[0]
	var app: Node = r[1]
	var lc: LotteryController = r[2]
	var screen: KujiScreen = main.get_node("KujiScreen")
	var stage: Control = main.get_node("AssistantStage")
	app.state.progression_state["store_rank"] = 5   # this test is about the feature, not the store rank that opens it
	t.ok(not screen.visible, "closed at boot")
	t.ok(stage.visible, "the corner assistant is up (story line)")
	(main.find_child("OpenKujiScreen", true, false) as Button).pressed.emit()
	t.ok(screen.visible, "限定くじ管理を開く opens it")
	t.ok(not stage.visible, "she steps aside from the corner while she is on the screen")
	t.ok(screen.get_index() > main.get_node("ManagementWindow").get_index(), "above the management window")
	t.eq(screen._chip_text.text, "未販売")
	t.eq(screen._period.text, "14日間")
	t.eq(screen._prize_counts.map(func(l): return l.text), ["5 / 5", "15 / 15", "30 / 30", "50 / 50"])
	t.eq(screen._values.map(func(l): return l.text), ["35,000円", "100枚", "100枚", "—"])
	t.ok(screen._line.text.begins_with("星空マスコットくじ、"), screen._line.text)
	t.ok(not screen._buy.disabled and not screen._buy_dim.visible)
	app.state.ledger.cash_yen = 1000000
	var cash: int = app.state.ledger.cash_yen
	screen._buy.pressed.emit()
	t.eq(app.state.ledger.cash_yen, cash - 35000, "セットを仕入れる buys the set")
	t.eq(screen._chip_text.text, "販売中")
	t.eq(screen._period.text, "DAY %d〜%d" % [app.state.day, app.state.day + 13])
	t.ok(screen._line.text.begins_with("仕入れました"), screen._line.text)
	t.ok(screen._buy.disabled and screen._buy_dim.visible, "one set at a time: the button is greyed")
	t.eq(screen._values[3].text, "まだ予測できません")
	screen.close()
	t.ok(not screen.visible and stage.visible, "closing brings the corner assistant back")
	lc.open_kuji_screen()
	(screen.find_child("DisplayButton", true, false) as Button).pressed.emit()
	t.ok(not screen.visible, "展示台を確認 goes back to the store")
	main.queue_free()
	await tree.process_frame


func test_the_texts_follow_the_run(t, _tree) -> void:
	var v := {"display_name": "星空マスコットくじ", "tickets": 100, "days": 14, "run": {}}
	t.eq(KujiScreen.forecast_text(v, 3), "—")
	t.ok(KujiScreen.rikka_line(v, true).begins_with("いまは別のくじ"), "another set on sale")
	v["run"] = {"status": "selling", "sold": 20, "start_day": 1, "end_day": 14, "remaining": {"A": 2}}
	t.eq(KujiScreen.period_text(v), "DAY 1〜14")
	# 20 sold over days 1-4 = 5 a day; 80 left -> 16 more days -> day 19: past the end
	t.eq(KujiScreen.forecast_text(v, 4), "期間内は難しそう")
	v["run"]["sold"] = 60   # 15 a day; 40 left -> 3 days -> day 6
	t.eq(KujiScreen.forecast_text(v, 4), "DAY 6 頃")
	t.ok(KujiScreen.rikka_line(v, false).contains("残り 40 枚") and KujiScreen.rikka_line(v, false).contains("A賞はあと 2 個"))
	v["run"]["remaining"] = {"A": 0}
	t.ok(KujiScreen.rikka_line(v, false).contains("A賞はもう出ちゃいました"))
	v["run"]["status"] = "sold_out"
	t.eq(KujiScreen.forecast_text(v, 4), "完売しました")
	t.ok(KujiScreen.rikka_line(v, false).begins_with("完売しました"))
