extends RefCounted
## Scenarios on screen (user's decision 2026-11-14): the title lists them; a picked one starts the game with its card and
## its goals in the guide; the result card stops the clock, records a clear here and このまま続ける goes on in free play.

const RECORDS := "user://test_scenario_records.json"


func test_the_title_lists_the_scenarios_and_starts_one(t, tree) -> void:
	ScenarioText.records_path = RECORDS
	DirAccess.remove_absolute(RECORDS)
	ScenarioText.record_clear("sc_first_week", 5)
	var title: TitleScreen = load("res://scenes/title/Title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	t.ok(title.find_child("Scenario", true, false) != null, "a シナリオ button on the title")
	title.open_scenarios()
	await tree.process_frame
	var list := title.find_child("ScenarioList", true, false)
	t.eq(list.get_child_count(), ScenarioRules.scenarios().size(), "one card per scenario")
	var card := list.get_child(0)
	t.ok(_texts(card).contains("クリア済み（最短5日）"), "the clear record shows: %s" % _texts(card))
	title.close_scenarios()
	t.ok(not title.find_child("ScenarioSelect", true, false).visible, "戻る closes the list")
	title.queue_free()
	await tree.process_frame
	ScenarioText.records_path = ScenarioText.RECORDS_PATH


func test_a_scenario_game_shows_its_card_goals_and_result(t, tree) -> void:
	ScenarioText.records_path = RECORDS
	DirAccess.remove_absolute(RECORDS)
	AppRoot.start_slot = ""
	AppRoot.start_scenario = "sc_first_week"
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	var guide: ProgressionController = main.get_node("ProgressionController")
	var dialog := guide.scenario_dialog()
	t.eq(AppRoot.start_scenario, "", "used once")
	t.eq(String(app.state.scenario.get("scenario_id", "")), "sc_first_week")
	app._publish_snapshot()
	await tree.process_frame
	t.eq(dialog.mode(), "intro", "the scenario's card opens at the start")
	t.ok(_texts(dialog).contains("1日の売上 ¥300,000"), "with its goal: %s" % _texts(dialog))
	(dialog.find_child("ScenarioOk", true, false) as Button).pressed.emit()
	t.ok(not dialog.is_open(), "はじめる closes it")
	var goal := guide.find_child("ScenarioGoal", true, false) as Label
	if goal == null:
		goal = guide._scenario
	t.ok(goal.visible and goal.text.contains("残り7日"), "the guide shows the days left: %s" % goal.text)
	# the store runs, a good day closes
	var s := app.state
	s.business_state = GameState.OPEN
	s.speed_setting = 2
	s.last_nonzero_speed = 2
	var report := DailyReport.build(0, s.ledger, {}, s.reputation, s.cash_yen)
	report["revenue_yen"] = 320000   # a good first day (a full report: the other views read it too)
	s.daily_reports.append(report)
	s.day = 1
	s.time_sec = 86400 + 600
	ProgressionService.evaluate(s)
	app._publish_snapshot()
	await tree.process_frame
	t.eq(dialog.mode(), "cleared", "the result card")
	t.eq(int(s.speed_setting), 0, "the clock stops while it shows")
	t.ok(_texts(dialog).contains("1日でクリア"), "in how many days: %s" % _texts(dialog))
	t.eq(ScenarioText.record_text("sc_first_week", ScenarioText.read_records()), "クリア済み（最短1日）", "recorded on this computer")
	(dialog.find_child("ScenarioOk", true, false) as Button).pressed.emit()
	t.ok(not dialog.is_open(), "このまま続ける")
	t.eq(int(s.speed_setting), 2, "and the store runs on")
	app._publish_snapshot()
	t.ok(goal.text.contains("クリア"), "the guide keeps the result: %s" % goal.text)
	main.queue_free()
	await tree.process_frame
	ScenarioText.records_path = ScenarioText.RECORDS_PATH
	DirAccess.remove_absolute(RECORDS)


func _texts(node: Node) -> String:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append(_texts(c))
	return "\n".join(out)
