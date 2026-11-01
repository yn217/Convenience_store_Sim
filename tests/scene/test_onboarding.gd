extends RefCounted
## Issues #28/#32 (screen part): the first five minutes from an empty store, skip / show again,
## notices, and the way back from a cash shortage.


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return [main, main.get_node("AppRoot"), main.get_node("ProgressionController")]


func _cmd(app: Node, id: String, kind: StringName, payload: Dictionary = {}) -> CommandResult:
	var c := {"command_id": id, "kind": kind}
	c.merge(payload)
	return app.run_command(c)


func test_card_texts_and_skip_toggle(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var pc: ProgressionController = r[2]
	t.ok(pc._card.text.begins_with("手順 2/8"), "tut_01 is passed at once, the card asks for the register: %s" % pc._card.text)
	t.ok(pc._challenge.text.contains("2日目から"))
	t.eq(pc._milestones.text, "称号 0/12（店のレベル 0）")
	var missions: Control = pc._missions
	t.ok(missions.is_visible_in_tree() or missions.get_parent() != null, "本日のミッション is in the card")
	t.ok(not pc._mission_rows[0]["caption"].text.is_empty() and pc._mission_rows[0]["caption"].text.begins_with("称号「"), "day 0: no challenge, titles only: %s" % pc._mission_rows[0]["caption"].text)
	t.ok(pc._mission_rows[0]["count"].text.contains(" / ") and pc._mission_rows[0]["chip"].text == "進行中")
	t.ok(not pc._mission_rows[3]["box"].visible, "three titles on day 0, the fourth row is hidden")
	t.ok(pc._toggle.text.contains("スキップ"))
	pc.toggle_tutorial()
	t.eq(app.state.progression_state["tutorial_skipped"], true)
	t.ok(pc._card.text.contains("非表示"), pc._card.text)
	t.ok(pc._toggle.text.contains("再表示"))
	_cmd(app, "k1", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	pc.toggle_tutorial()
	t.eq(app.state.progression_state["tutorial_skipped"], false)
	t.ok(pc._card.text.begins_with("手順 3/8"), "progress was kept while hidden: %s" % pc._card.text)
	r[0].queue_free()
	await tree.process_frame


func test_first_five_minutes_within_the_starting_money(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var pc: ProgressionController = r[2]
	t.ok(_cmd(app, "f1", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0}).ok)
	t.ok(pc._notices.text.contains("手順 2 完了"))
	var r2 := _cmd(app, "f2", &"PLACE_FIXTURE", {"type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0})
	t.ok(r2.ok)
	t.ok(pc._notices.text.contains("手順 3 完了"))
	t.ok(_cmd(app, "f3", &"ORDER_STOCK", {"sku_id": "snack_001", "qty": 12}).ok)
	t.ok(pc._notices.text.contains("手順 4 完了"))
	t.ok(_cmd(app, "f4", &"RESTOCK", {"instance_id": "fx_0002", "slot_id": "row0", "sku_id": "snack_001", "qty": 12}).ok)
	t.ok(pc._notices.text.contains("手順 5 完了"))
	t.ok(_cmd(app, "f5", &"START_BUSINESS").ok)
	t.ok(pc._notices.text.contains("手順 6 完了"))
	app.state.balance["base_potential_visitors_per_day"] = 4000
	app.state.speed_setting = 4
	var steps := 0
	while app.state.visit_stats["purchased"] < 1 and steps < 40000:
		steps += app.runner.process_frame(1.0 / 15.0)
	app._publish_snapshot()
	t.ok(app.state.visit_stats["purchased"] >= 1, "the first sale happened")
	t.ok(app.state.progression_state["tutorial_step_index"] >= 7)
	t.ok(pc._notices.text.contains("称号を獲得: ") or pc._history.any(func(l): return l.contains("手順 7 完了")))
	t.ok(app.state.cash_yen > 0, "the whole opening fits the starting money: ¥%d left" % app.state.cash_yen)
	t.ok(pc._history.any(func(l): return l.contains("称号を獲得")), "the first sale earned a title")
	t.ok(pc.is_celebrating() and pc._heading.visible, "she celebrates the first title (#32)")
	r[0].queue_free()
	await tree.process_frame


func test_shortage_is_explained_and_nothing_is_taken(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	app.state.ledger.cash_yen = 50000
	var placed := _cmd(app, "s1", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	t.ok(not placed.ok)
	t.eq(CommandMessages.text(placed.code, placed.message_key), "資金が足りません")
	t.eq(app.state.cash_yen, 50000, "a refused purchase costs nothing")
	t.eq(app.state.grid.instances.size(), 0)
	var bc: BusinessController = r[0].get_node("BusinessController")
	t.ok(bc._start.disabled)
	t.ok(bc._checklist.text.contains("✗ レジが必要です"))
	# Blocked payment explains the cause and the way out.
	app.state.business_state = GameState.PAYMENT_BLOCKED
	app.state.unpaid_cost_yen = 1500
	app._publish_snapshot()
	t.ok(bc._status.text.contains("支払えず") and bc._status.text.contains("未払い ¥1,500") and bc._status.text.contains("セーブ"), bc._status.text)
	r[0].queue_free()
	await tree.process_frame


func test_assistant_cues_show_in_order_and_stay_dismissed(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var pc: ProgressionController = r[2]
	t.eq(pc._snap["story_cue"], "story_start")
	var stage: Control = r[0].get_node("AssistantStage")
	t.ok(stage.get_index() > r[0].get_node("ManagementWindow").get_index(), "she stands in front of the management window")
	r[0].call("open_screen_tab", "経営")
	t.ok(stage.visible, "the management window keeps the screen-scoped pilot guidance visible")
	r[0].call("close_screen")
	t.ok(stage.visible, "and comes back when it closes")
	t.ok(stage.visible and pc._assistant.text.contains("どんなお店"), "her line shows in the bubble")
	t.eq((stage.find_child("AssistantName", true, false) as Label).text, "小春六花（店長アシスタント）", "the bubble is named")
	var figure := stage.get_node("AssistantFigure") as TextureRect
	t.ok(figure.texture != null and figure.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the standing figure shows and lets clicks through")
	var bottom: float = tree.root.get_visible_rect().size.y - 108.0   # MainLayout.BOTTOM_HEIGHT: the summary cards stay uncovered
	var bubble := stage.get_node("AssistantBubble") as Control
	t.ok(figure.offset_left >= ProgressionController.ASSISTANT_LEFT and absf(figure.get_global_rect().end.y - bottom) < 1.0, "right of the left menu, standing on the summary strip: %s" % figure.get_global_rect())
	t.ok(bubble.offset_top > -ProgressionController.FIGURE_SIZE.y - 108.0 + 40.0, "the assistant speech bubble is lowered below the figure head")
	(stage.find_child("AssistantDismiss", true, false) as Button).pressed.emit()
	t.eq(pc._snap["story_cue"], "", "閉じる in the bubble dismisses it; nothing else is eligible yet")
	t.ok(not stage.visible, "the figure and the bubble hide together")
	t.eq(pc.dismiss_cue().code, &"INVALID_OPERATION", "no cue to close")
	_cmd(app, "a1", &"PLACE_FIXTURE", {"type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	t.eq(pc._snap["story_cue"], "story_register")
	app.state.rate_stats["stockouts"] = 1
	t.ok(pc.dismiss_cue().ok)
	t.eq(pc._snap["story_cue"], "story_sold_out", "the next eligible cue follows")
	# Dismissals are saved and survive a load.
	var saved := SaveGame.to_dict(app.state, "s", "2026-01-01T00:00:00Z")
	t.ok(saved["progression_state"]["dismissed_story_cue_ids"].has("story_register"))
	t.eq(app.run_command({"command_id": "a9", "kind": &"DISMISS_STORY_CUE", "cue_id": "nope"}).code, &"INVALID_OPERATION")
	t.eq(AssistantService.CUES.size(), ProgressionText.ASSISTANT.size(), "every cue has a text")
	r[0].queue_free()
	await tree.process_frame


func test_achievement_list_shows_progress(t, tree) -> void:
	var r: Array = await _boot(tree)
	var pc: ProgressionController = r[2]
	t.eq(pc._snap["milestone_progress"].size(), 12)
	t.ok(pc._achievements.text.begins_with("実績一覧"))
	t.ok(pc._achievements.text.contains("・ "), "unfinished entries show as open")
	r[0].queue_free()
	await tree.process_frame


## #32 達成演出: titles and daily challenges make her cheer, one at a time, before her story line; the badge is the
## only reward, and an event is celebrated once.
func test_achievements_are_celebrated_once_without_rewards(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var pc: ProgressionController = r[2]
	var stage: Control = r[0].get_node("AssistantStage")
	var cash: int = app.state.cash_yen
	var first: Dictionary = app.state.milestones[0]
	pc.show_events([
		{"kind": "TUTORIAL_STEP", "id": "tut_02"},
		{"kind": "MILESTONE", "id": first["milestone_id"]},
		{"kind": "CHALLENGE", "challenge_id": "challenge_sales_3"},
	])
	t.ok(stage.visible and pc._heading.visible, "目標達成！ shows")
	t.eq(pc.mood(), "happy", "she cheers with her happy face")
	t.eq(pc._heading.text, "★ 目標達成！ ★")
	t.ok(pc._assistant.text.contains("称号「%s」" % first["name_ja"]), "the title comes first: %s" % pc._assistant.text)
	t.eq(pc._celebrations.size(), 2, "a tutorial step is not celebrated")
	(stage.find_child("AssistantDismiss", true, false) as Button).pressed.emit()
	t.ok(pc._assistant.text.contains("3件以上の会計") and not pc._assistant.text.contains("今日のチャレンジ:"), "then the challenge: %s" % pc._assistant.text)
	t.eq(pc._snap["story_cue"], "story_start", "closing a celebration does not dismiss the story line")
	pc._celebrate_timer.timeout.emit()
	t.ok(not pc.is_celebrating() and not pc._heading.visible, "the timer closes a celebration by itself")
	t.ok(stage.visible and pc._assistant.text.contains("どんなお店"), "her story line is back")
	t.eq(pc.mood(), "welcome", "and her greeting pose for the first story line")
	app._publish_snapshot()
	t.ok(not pc.is_celebrating(), "a new snapshot does not celebrate again")
	t.eq(app.state.cash_yen, cash, "no cash reward: the badge is the whole reward")
	r[0].queue_free()
	await tree.process_frame
