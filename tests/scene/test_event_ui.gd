extends RefCounted
## Issue #31: the daily event panel (SCR-11) follows the EventService state.


func _force(app: Node, event_id: String, started: bool, ended: bool = false) -> void:
	var ev := GameplayEventDirector.event_by_id(app.state.gameplay_events, event_id)
	var w := GameplayEventDirector.window(1, ev)
	app.state.gameplay_event_state.merge({"last_selected_day": 1, "selection_event_id": "daily:1", "selected_event_id": event_id,
			"event_start_sec": w.x, "event_end_sec": w.y, "started": started, "ended": ended}, true)


func test_panel_shows_each_state(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var panel: EventController = main.get_node("EventController")
	t.eq(app.state.gameplay_events.size(), 12, "master data is loaded at boot")
	t.ok(panel._status.text.contains("DAY 0 はイベントなし"), panel._status.text)
	app.state.time_sec = 86400 + 6 * 3600
	_force(app, "evt_hot_day", false)
	app._publish_snapshot()
	t.ok(panel._status.text.begins_with("予定: 暑い日"), panel._status.text)
	t.ok(panel._status.text.contains("時間 11:00〜17:00") and panel._status.text.contains("飲料 ×1.60") and panel._status.text.contains("アイス ×1.60"), panel._status.text)
	t.ok(panel._status.text.contains("開始まで 05:00"))
	t.ok(panel._status.text.contains("対象の商品が棚にありません"), "nothing stocked yet: the panel says what to do")
	app.state.time_sec = 86400 + 12 * 3600
	_force(app, "evt_hot_day", true)
	app._publish_snapshot()
	t.ok(panel._status.text.begins_with("開催中:") and panel._status.text.contains("終了まで 05:00"), panel._status.text)
	_force(app, "evt_roadworks", true)
	app._publish_snapshot()
	t.ok(panel._status.text.contains("来店 ×0.75") and panel._status.text.contains("品揃えと価格を見直して乗り切りましょう"), "a negative event comes with a way out")
	_force(app, "evt_roadworks", true, true)
	app._publish_snapshot()
	t.ok(panel._status.text.begins_with("終了:"))
	app.state.gameplay_event_state.merge({"selected_event_id": null, "event_start_sec": null, "event_end_sec": null, "started": false, "ended": false}, true)
	app._publish_snapshot()
	t.ok(panel._status.text.contains("イベントはありません"), panel._status.text)
	main.queue_free()
	await tree.process_frame


## #31 mockup: 効果の内訳 as chips, and 本日のイベント一覧 with every event marked 選択中 / 候補 / locked.
func test_effect_chips_and_the_event_list(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var panel: EventController = main.get_node("EventController")
	t.ok(not panel._effects.visible, "no event: no effect chips")
	t.eq(panel._list.get_child_count(), 12, "all 12 events are listed")
	t.ok(panel._cells.values().all(func(c): return c["state"] == "locked"), "day 0: none can be drawn yet")
	app.state.time_sec = 86400 + 12 * 3600
	app.state.reputation = 0
	_force(app, "evt_roadworks", true)
	app._publish_snapshot()
	await tree.process_frame
	var texts: Array = panel._effects.get_children().filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return c.text)
	t.ok(texts.has("来店 −25%"), "the drop in visitors as a chip: %s" % [texts])
	t.eq(panel._cells["evt_roadworks"]["state"], "selected")
	t.eq(panel._cells["evt_roadworks"]["tag"].text, "選択中")
	t.ok(panel._cells.values().any(func(c): return c["state"] == "candidate"), "day 1: some are candidates")
	t.ok(panel._cells["evt_roadworks"]["panel"].tooltip_text.contains("来店 −25%"), "hover shows the effect")
	main.queue_free()
	await tree.process_frame


func test_effect_chip_texts(t, _tree) -> void:
	var chips := EventText.effect_chips({"traffic": 1.35, "categories": {"drink": 1.6, "oden": 0.8}})
	t.eq(chips.map(func(c): return c["text"]), ["来店 +35%", "飲料 +60%", "おでん −20%"])
	t.eq(chips.map(func(c): return c["good"]), [true, true, false])
	t.eq(EventText.effect_chips({"traffic": 1.0, "categories": {}}).size(), 0)


## The day's event as an illustration at the top of the card (ComfyUI art, one per event, 576x324 for 384x216).
func test_event_picture(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var panel: EventController = main.get_node("EventController")
	t.ok(not panel._picture.visible, "no event yet: no picture")
	for e in app.state.gameplay_events:
		var pic := EventController.picture_for(String(e["event_id"]))
		t.ok(pic != null and pic.get_size() == EventController.PICTURE_SIZE * 1.5, "%s has its picture at 1.5x" % e["event_id"])
	app.state.time_sec = 86400 + 12 * 3600
	_force(app, "evt_local_fair", false)
	app._publish_snapshot()
	t.ok(panel._picture.visible and panel._picture.texture == EventController.picture_for("evt_local_fair"), "today's event is shown")
	t.ok(not panel._pilot_picture.visible, "a scheduled event keeps the pilot art hidden")
	_force(app, "evt_neighbor_mentions", true)
	app._publish_snapshot()
	t.ok(panel._pilot_picture.visible and panel._pilot_picture.texture is Texture2D, "the selected event pilot is shown alongside the event picture")
	var guide: Node = main.get_node("ProgressionController")
	main.open_screen_tab("経営")
	await tree.process_frame
	t.ok(not guide._stage.visible, "the event pilot hides the persistent assistant while the event screen is open")
	var chrome := main.get_node_or_null("MockupChrome")
	if chrome != null:
		t.ok(not chrome.get_node("WindowLayer/Rikka").visible, "the event pilot hides the baked assistant figure")
		t.ok(not chrome.get_node("WindowLayer/Bubble").visible, "the event pilot hides the baked assistant bubble")
	main.close_screen()
	await tree.process_frame
	t.ok(not guide._suppressed_by.has("event_pilot"), "closing the event screen releases the persistent assistant suppression")
	for event_id in ["evt_local_fair", "evt_roadworks", "evt_hot_day", "evt_cold_day", "evt_sweets_spotlight", "evt_snack_buzz", "evt_lunch_pick", "evt_drink_pick", "evt_bread_feature", "evt_after_work"]:
		_force(app, event_id, true)
		app._publish_snapshot()
		t.eq((panel._pilot_picture.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/%s.png" % event_id.replace("evt_", "event_"), "%s selects its event pilot" % event_id)
	main.queue_free()
	await tree.process_frame
