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
	t.ok(pc._assistant.visible and pc._assistant.text.contains("どんなお店"))
	t.ok(pc._assistant.text.begins_with("小春六花"), "the assistant is named")
	var portrait := pc._assistant_row.get_node("AssistantPortrait") as TextureRect
	t.ok(pc._assistant_row.visible and portrait.texture != null, "her portrait shows beside the line")
	t.ok(pc.dismiss_cue().ok)
	t.eq(pc._snap["story_cue"], "", "nothing else is eligible yet")
	t.ok(not pc._assistant.visible and not pc._assistant_row.visible, "the line and the portrait hide together")
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
