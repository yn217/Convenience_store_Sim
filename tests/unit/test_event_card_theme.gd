extends RefCounted
## The 本日のイベント card: its tag follows the event's state (開催中 / 終了間近 / 開催予定 / 終了 / なし) and every
## event's visual_theme has a look.


func test_tag_follows_the_event_state(t, _tree) -> void:
	var ev := {"status": "active", "end_sec": 100000, "visual_theme": "sun"}
	t.eq(EventCardTheme.tag(ev, 100000 - 7200)["text"], "開催中！", "two hours left: running")
	t.eq(EventCardTheme.tag(ev, 100000 - 3600)["text"], "終了間近！", "the last hour: ending soon")
	t.eq(EventCardTheme.tag({"status": "scheduled", "visual_theme": "sun"}, 0)["text"], "開催予定", "later today")
	t.eq(EventCardTheme.tag({"status": "ended", "visual_theme": "sun"}, 0)["text"], "終了", "over")
	t.eq(EventCardTheme.tag({"status": "missed", "visual_theme": "sun"}, 0)["text"], "終了", "closed through it")
	t.eq(EventCardTheme.tag({"status": "none"}, 0)["text"], "なし", "no event today")
	t.eq(EventCardTheme.tag({"status": "undrawn", "day": 0}, 0)["text"], "なし", "day 0")
	t.ok(EventCardTheme.tag_colors(ev, 100000 - 60)[0] != EventCardTheme.tag_colors(ev, 0)[0], "ending soon has its own colour")


func test_every_event_theme_has_a_look(t, _tree) -> void:
	var events = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json"))
	var list: Array = events if typeof(events) == TYPE_ARRAY else events["events"]
	var seen := {}
	for e in list:
		var view := {"status": "active", "visual_theme": e["visual_theme"]}
		t.eq(EventCardTheme.theme_id(view), String(e["visual_theme"]), "%s has a theme" % e["event_id"])
		seen[e["visual_theme"]] = true
	t.eq(EventCardTheme.theme_id({"status": "none"}), "none", "no event: the plain look")
	t.ok(seen.size() >= 10, "the events use many themes")


func test_the_view_carries_the_visual_theme(t, _tree) -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, preload("res://tests/support/test_seeds.gd").SEEDS, fx, pr)
	s.gameplay_events = GameplayEventDirector.load_events(JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mvp_v1.json")))
	s.gameplay_event_state["last_selected_day"] = s.time_sec / GameplayEventDirector.SECONDS_PER_DAY
	s.gameplay_event_state["selected_event_id"] = "evt_hot_day"
	s.gameplay_event_state["event_start_sec"] = 11 * 3600
	s.gameplay_event_state["event_end_sec"] = 17 * 3600
	t.eq(EventService.view(s)["visual_theme"], "sun", "the hot day is a sun event")
