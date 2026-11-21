extends RefCounted
## The event's special picture when it begins (user's request 2026-11-21): it plays once when today's event goes from
## scheduled to active while the player watches, stops the clock, and a click resumes it; not for an event already
## running at load, not while the event choice is open; every event with a picture has its line.

const DAY := 86400


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var events: EventController = main.get_node("EventController")
	return [main, main.get_node("AppRoot"), events.start_cutin(), events.choice_dialog(), main.get_node("ProgressionController")]


## Today's event = evt_local_fair (17:00-22:00), chosen already, store open at x2, the clock at `hour`.
func _local_fair(app: Node, hour: int) -> void:
	var s: GameState = app.state
	s.business_state = GameState.OPEN
	s.speed_setting = 2
	s.last_nonzero_speed = 2
	s.time_sec = DAY + hour * 3600
	s.day = 1
	var ges := s.gameplay_event_state
	ges["last_selected_day"] = 1
	ges["selection_event_id"] = "daily:1"
	ges["selected_event_id"] = "evt_local_fair"
	ges["event_start_sec"] = DAY + 17 * 3600
	ges["event_end_sec"] = DAY + 22 * 3600
	ges["started"] = hour >= 17
	ges["ended"] = false
	ges["choice_id"] = "normal"
	app._publish_snapshot()


func test_the_picture_plays_when_the_event_begins(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var cut: EventStartCutin = r[2]
	var guide: ProgressionController = r[4]
	_local_fair(app, 16)
	await tree.process_frame
	t.ok(not cut.is_open(), "nothing before the event begins")
	if guide._opening_cutin_active:   # the 開店！ band of the setup holds it back
		_local_fair(app, 17)
		await tree.process_frame
		t.ok(not cut.is_open(), "it waits for the 開店！ band")
		guide._finish_opening_cutin()
	_local_fair(app, 17)
	await tree.process_frame
	t.ok(cut.is_open(), "the event begins: its picture")
	t.eq(cut.event_id(), "evt_local_fair")
	var art := cut.find_child("EventStartArt", true, false) as TextureRect
	t.ok(art.texture != null, "the special picture is loaded")
	t.ok(cut.card_text().contains("地域のお祭り") and cut.card_text().contains("お祭りが始まりました"), cut.card_text())
	t.eq(int(app.state.speed_setting), 0, "the clock stops meanwhile")
	t.ok(guide._suppressed_by.has("event_start"), "the corner assistant steps aside")
	cut.close()
	t.ok(not cut.is_open(), "a click closes it")
	t.eq(int(app.state.speed_setting), 2, "and the clock runs on at the earlier speed")
	t.ok(not guide._suppressed_by.has("event_start"), "and she is back in her corner")
	app._publish_snapshot()
	await tree.process_frame
	t.ok(not cut.is_open(), "once per event")
	r[0].queue_free()
	await tree.process_frame


func test_not_for_an_event_already_running_at_load(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var cut: EventStartCutin = r[2]
	_local_fair(app, 18)
	await tree.process_frame
	t.ok(not cut.is_open(), "the event was running before the player saw it")
	t.eq(int(app.state.speed_setting), 2, "the clock keeps running")
	r[0].queue_free()
	await tree.process_frame


func test_it_waits_for_the_event_choice(t, _tree) -> void:
	var cut := EventStartCutin.new()
	var view := {"day": 1, "event_id": "evt_hot_day", "name_ja": "暑い日", "status": "scheduled"}
	cut.observe(view)
	view["status"] = "active"
	cut.observe(view, true)
	t.ok(not cut.is_open(), "the choice is open: it waits")
	cut.observe(view, false)
	t.ok(cut.is_open(), "then it plays")
	cut.close()
	cut.free()


func test_every_picture_has_its_line(t, _tree) -> void:
	var events: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json"))
	var with_picture := 0
	for e in events:
		var id := String(e["event_id"])
		if ResourceLoader.exists(EventStartCutin.picture_path(id)):
			with_picture += 1
			t.ok(EventStartCutin.LINES.has(id), "%s has her line" % id)
	t.eq(with_picture, 7, "seven events have a special picture")
	t.ok(EventStartCutin.line_for({"event_id": "evt_x", "name_ja": "テスト"}).contains("テスト"), "a fallback line names the event")
