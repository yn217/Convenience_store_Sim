extends RefCounted
## The event choice in the real game screen: it opens once for today's event, stops the clock, and the pick resumes it
## with Rikka's line; a choice the store cannot pay for is greyed out.

const DAY := 86400


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return [main, main.get_node("AppRoot"), main.get_node("EventController").choice_dialog(), main.get_node("ProgressionController")]


## Today's event = evt_local_fair (scheduled), store open at x2.
func _local_fair(app: Node) -> void:
	var s: GameState = app.state
	s.business_state = GameState.OPEN
	s.speed_setting = 2
	s.last_nonzero_speed = 2
	s.time_sec = DAY + 12 * 3600
	s.day = 1
	var ges := s.gameplay_event_state
	ges["last_selected_day"] = 1
	ges["selection_event_id"] = "daily:1"
	ges["selected_event_id"] = "evt_local_fair"
	ges["event_start_sec"] = DAY + 17 * 3600
	ges["event_end_sec"] = DAY + 22 * 3600
	ges["started"] = false
	ges["ended"] = false
	ges["choice_id"] = null
	app._publish_snapshot()


func test_the_choice_opens_pauses_and_the_pick_resumes(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var dialog: EventChoiceDialog = r[2]
	var guide: ProgressionController = r[3]
	_local_fair(app)
	await tree.process_frame
	t.ok(dialog.is_open(), "today's event asks the player")
	t.eq(int(app.state.speed_setting), 0, "the clock stops while she asks")
	var buttons := dialog.find_child("EventChoiceButtons", true, false) as VBoxContainer
	t.eq(buttons.get_child_count(), 2, "one button per choice")
	var stall := buttons.get_child(0) as Button
	t.ok(stall.text.contains("屋台を出す") and stall.text.contains("30,000"), "label and cost: %s" % stall.text)
	t.ok(stall.text.contains("来店 +55%"), "and its effect: %s" % stall.text)
	var art := dialog.find_child("EventChoiceArt", true, false) as TextureRect
	t.ok(art.visible and art.texture != null, "the event picture")
	var cash: int = app.state.cash_yen
	stall.pressed.emit()
	t.ok(not dialog.is_open(), "the pick closes it")
	t.eq(int(app.state.speed_setting), 2, "and the clock runs on at the earlier speed")
	t.eq(app.state.cash_yen, cash - 30000, "the stall is paid")
	t.eq(app.state.gameplay_event_state["choice_id"], "stall")
	t.ok(guide._assistant.text.contains("屋台"), "Rikka says the choice's line: %s" % guide._assistant.text)
	app._publish_snapshot()
	await tree.process_frame
	t.ok(not dialog.is_open(), "a chosen event does not ask again")
	r[0].queue_free()
	await tree.process_frame


func test_a_choice_beyond_the_cash_is_greyed_out(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var dialog: EventChoiceDialog = r[2]
	app.state.ledger.cash_yen = 1000
	_local_fair(app)
	await tree.process_frame
	var buttons := dialog.find_child("EventChoiceButtons", true, false) as VBoxContainer
	t.ok((buttons.get_child(0) as Button).disabled, "the stall cannot be paid")
	t.ok(not (buttons.get_child(1) as Button).disabled, "the free choice can always be picked")
	(buttons.get_child(1) as Button).pressed.emit()
	t.eq(app.state.gameplay_event_state["choice_id"], "normal")
	t.eq(app.state.cash_yen, 1000, "nothing paid")
	r[0].queue_free()
	await tree.process_frame
