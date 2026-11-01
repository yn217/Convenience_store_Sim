extends RefCounted
## Focused registry and routing checks for the Issue #230 character visual pilot.


func test_registry_assets_and_story_routes_load(t, _tree) -> void:
	var panel: Node = load("res://scripts/presentation/character_visual_pilot_panel.gd").new()
	panel._entries = panel._load_entries()
	t.eq(panel._entries.size(), 45, "the pilot registry exposes all 45 selected visuals")
	for entry in panel._entries:
		var id := String(entry.get("id", ""))
		var path := String(entry.get("runtime_path", ""))
		t.ok(not bool(entry.get("runtime_approved", true)), "%s remains review-only" % id)
		t.ok(ResourceLoader.exists(path), "%s runtime path exists" % id)
		t.ok(load(path) is Texture2D, "%s runtime texture loads" % id)
	for pair in [
		["story_start", "reaction_discovery"],
		["story_register", "functional_register_guidance"],
		["story_first_restock", "functional_restock_guidance"],
		["story_sold_out", "functional_sold_out"],
		["story_queue_giveup", "reaction_pleading"],
		["story_staff_short", "reaction_pleading"],
		["story_first_sale", "fullbody_emotion_05"],
	]:
		var entry: Dictionary = panel._select_entry({"story_cue": pair[0], "gameplay_event": {}, "progression": {}})
		t.eq(entry.get("id", ""), pair[1], "%s selects the expected pilot" % pair[0])
	var quiet: Dictionary = panel._select_entry({"story_cue": "", "gameplay_event": {"event_id": "evt_quiet_street"}, "progression": {}})
	t.eq(quiet.get("id", ""), "reaction_deadpan", "quiet street uses the deadpan reaction")
	t.ok(panel.has_method("is_pilot_enabled"), "pilot panel exposes its display toggle")
	t.ok(panel.has_method("selected_entry"), "pilot panel exposes the selected runtime entry")
	t.ok(panel.has_method("stage_entry"), "pilot panel exposes a full-body stage route")
	t.ok(panel.has_method("event_entry"), "pilot panel exposes event-image routing")
	t.eq(panel.selected_entry({"story_cue": "story_sold_out", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_sold_out", "stage consumers share pilot routing")
	t.eq(panel.cue_entry("long_queue").get("id", ""), "functional_queue", "a long queue has a functional pilot pose")
	t.eq(panel.cue_entry("low_stock_notice").get("id", ""), "functional_low_stock", "low stock has a functional pilot pose")
	t.eq(panel.cue_entry("expiry_notice").get("id", ""), "functional_expiry", "expiry has a functional pilot pose")
	t.eq(panel.cue_entry("access_blocked").get("id", ""), "functional_access_blocked", "blocked access has a functional pilot pose")
	t.eq(panel.cue_entry("empty_handed").get("id", ""), "functional_empty_handed", "an empty-handed exit has a functional pilot pose")
	t.eq(panel.cue_entry("rival_opened").get("id", ""), "functional_rival_store", "rival opening reuses the rival pose")
	t.eq(panel.cue_entry("capsule_rare").get("id", ""), "functional_capsule_rare", "capsule rare uses its functional pilot pose")
	t.eq(panel.cue_entry("capsule_empty").get("id", ""), "functional_capsule_rare", "capsule empty reuses the capsule pose")
	t.eq(panel.cue_entry("save_complete").get("id", ""), "functional_save_complete", "save completion uses its functional pilot pose")
	t.eq(panel.cue_entry("staff_hired").get("id", ""), "functional_staff_hiring", "staff hiring uses its functional pilot pose")
	t.eq(panel.cue_entry("seasonal_campaign_started").get("id", ""), "functional_campaign", "promotion start uses its campaign pilot pose")
	t.eq(panel.cue_entry("map_proposal_open").get("id", ""), "functional_map_proposal", "area map uses its proposal pilot pose")
	t.eq(panel.cue_entry("business_started").get("id", ""), "functional_business_opening", "opening cut-in has a functional pilot pose")
	t.eq(panel.stage_entry({"story_cue": "story_first_profit", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_first_profit", "first-profit story uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "story_register", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_register_guidance", "register tutorial uses the register guidance pose")
	t.eq(panel.stage_entry({"story_cue": "story_first_restock", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_restock_guidance", "restock tutorial uses the restock guidance pose")
	t.eq(panel.day_end_entry("worried").get("id", ""), "functional_day_end_review", "negative day-end uses the review pose")
	t.eq(panel.stage_entry({"story_cue": "story_start", "gameplay_event": {}, "progression": {}}).get("kind", ""), "functional_pose", "story start stage avoids a bust-up asset")
	t.eq(panel.stage_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("kind", ""), "functional_pose", "queue reaction stage uses a functional full-body asset")
	t.eq(panel.stage_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_queue", "queue story uses the queue-specific pose")
	t.eq(panel.stage_entry({"story_cue": "story_staff_short", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_staff_short", "staff shortage story uses the staff-specific pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_six_categories"]}}).get("id", ""), "functional_six_categories", "six-category achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_ten_sales"]}}).get("id", ""), "functional_ten_sales", "ten-sales achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_three_fixtures"]}}).get("id", ""), "functional_expansion", "fixture expansion achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_first_week"]}}).get("id", ""), "functional_day_end_review", "first-week achievement uses its review pose")
	t.eq(panel.cue_entry("staff_schedule_open").get("id", ""), "functional_staff_schedule", "staff scheduling has a functional pilot pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_sales_3", "completed_milestone_ids": []}}).get("id", ""), "functional_three_sales", "sales challenge uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_stock_2", "completed_milestone_ids": []}}).get("id", ""), "functional_stock_challenge", "stock challenge uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_no_waste", "completed_milestone_ids": []}}).get("id", ""), "functional_no_waste", "no-waste challenge uses its presentation pose")
	t.eq(panel.event_entry("evt_neighbor_mentions").get("id", ""), "event_neighbor_mentions", "neighbor mentions uses the selected event pilot")
	for event_id in ["evt_local_fair", "evt_roadworks", "evt_hot_day", "evt_cold_day", "evt_sweets_spotlight", "evt_snack_buzz", "evt_lunch_pick", "evt_drink_pick", "evt_bread_feature", "evt_after_work"]:
		t.eq(panel.event_entry(event_id).get("trigger", ""), event_id, "%s has a selected event pilot" % event_id)


func test_runtime_assistant_stage_uses_selected_pilot(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var guide := main.get_node("ProgressionController")
	var panel := main.get_node("CharacterVisualPilotPanel")
	t.ok(panel.is_pilot_enabled(), "the pilot toggle defaults on for visual review")
	t.ok(guide._pilot_figure != null, "the assistant stage owns a pilot figure layer")
	t.ok(guide._pilot_figure.texture is Texture2D, "the assistant stage loads a pilot texture")
	var expected: Dictionary = panel.stage_entry(guide._snap)
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, expected.get("runtime_path", ""), "the stage texture follows the shared pilot route")
	main.queue_free()
	await tree.process_frame


func test_runtime_notification_uses_functional_pilot_pose(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var panel: Node = main.get_node("CharacterVisualPilotPanel")
	var pc: ProgressionController = main.get_node("ProgressionController")
	var player: Node = main.get_node("CuePlayer")
	t.ok(panel.is_pilot_enabled(), "notification pilot is enabled for the QA runtime")
	player.pilot_cue_requested.emit("long_queue", {})
	await tree.process_frame
	t.ok(pc._stage.visible, "a warning cue opens the assistant stage")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_queue.png", "long queue selects the queue pose")
	player.pilot_cue_requested.emit("access_blocked", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_access_blocked.png", "blocked access selects the blocked-aisle pose")
	player.pilot_cue_requested.emit("rival_opened", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_rival_store.png", "rival opening selects the rival pose")
	player.pilot_cue_requested.emit("capsule_rare", {"prize": "test"})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_capsule_rare.png", "capsule rare selects the capsule pose")
	player.pilot_cue_requested.emit("empty_handed", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_empty_handed.png", "an empty-handed exit selects the exit pose")
	pc.request_pilot_cue("save_complete", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_save_complete.png", "save completion selects the save pose")
	pc.request_pilot_cue("staff_hired", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_staff_hiring.png", "staff hiring selects the hiring pose")
	pc.request_pilot_cue("seasonal_campaign_started", {})
	await tree.process_frame
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_campaign.png", "promotion start selects the campaign pose")
	main.call("open_screen_tab", "店員")
	await tree.process_frame
	t.eq(pc._pilot_cue_id, "staff_schedule_open", "opening the staff screen requests the schedule pose")
	t.ok(pc._stage.visible, "the schedule pose remains visible over the staff screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_staff_schedule.png", "staff screen uses the schedule pose")
	pc._pilot_cue_timer.stop()
	pc._clear_pilot_cue()
	main.queue_free()
	await tree.process_frame
