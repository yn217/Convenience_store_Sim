extends RefCounted
## Focused registry and routing checks for the Issue #230 character visual pilot.


func test_registry_assets_and_story_routes_load(t, _tree) -> void:
	var panel: Node = load("res://scripts/presentation/character_visual_pilot_panel.gd").new()
	panel._entries = panel._load_entries()
	t.eq(panel._entries.size(), 50, "the pilot registry exposes all 50 selected visuals")
	var kind_counts := {}
	for entry in panel._entries:
		var id := String(entry.get("id", ""))
		var path := String(entry.get("runtime_path", ""))
		var kind := String(entry.get("kind", ""))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		t.ok(not bool(entry.get("runtime_approved", true)), "%s remains review-only" % id)
		t.ok(ResourceLoader.exists(path), "%s runtime path exists" % id)
		t.ok(load(path) is Texture2D, "%s runtime texture loads" % id)
	t.eq(kind_counts.get("functional_pose", 0), 31, "all 31 functional standing poses are selected")
	t.eq(kind_counts.get("event_image", 0), 11, "all 11 selected event standing images are registered")
	t.eq(kind_counts.get("bustup_reaction", 0), 5, "five cleaned reactions have dedicated routes")
	t.eq(kind_counts.get("fullbody", 0), 2, "two general full-body pilots are registered")
	t.eq(kind_counts.get("title_background", 0), 1, "one title background pilot is kept exclusive")
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
	t.ok(panel.has_method("reaction_entry"), "pilot panel exposes a separate bust-up reaction route")
	t.ok(panel.has_method("event_entry"), "pilot panel exposes event-image routing")
	t.ok(panel.has_method("set_review_candidate"), "pilot panel exposes a capture-only candidate override")
	var gate_entry: Dictionary = panel._find("functional_low_stock")
	t.ok(not panel.entry_allowed_for_mode(gate_entry, false), "unapproved candidate is blocked in release mode")
	var approved_gate_entry := gate_entry.duplicate(true)
	approved_gate_entry["runtime_approved"] = true
	t.ok(panel.entry_allowed_for_mode(approved_gate_entry, false), "approved candidate is allowed in release mode")
	t.ok(panel.entry_allowed_for_mode(gate_entry, true), "debug mode can inspect an unapproved candidate")
	t.ok(not panel.entry_allowed_for_mode({"runtime_approved": true, "runtime_path": "res://missing_character.png"}, false), "missing approved texture is blocked")
	panel.set_review_candidate("additional_001")
	t.eq(panel.review_candidate_entry().get("asset_id", ""), "additional_001", "candidate review override resolves a placement asset")
	t.eq(panel.review_candidate_entry().get("kind", ""), "fullbody", "full-body candidate review uses the assistant stage")
	panel.clear_review_candidate()
	t.ok(panel.review_candidate_entry().is_empty(), "candidate review override can be cleared")
	panel.set_review_candidate("reaction_001")
	t.eq(panel.review_candidate_entry().get("asset_id", ""), "reaction_001", "reaction candidate review override resolves a placement asset")
	t.eq(panel.review_candidate_entry().get("kind", ""), "bustup_reaction", "reaction candidate review uses the dedicated bust-up layer")
	panel.clear_review_candidate()
	t.ok(panel.review_candidate_entry().is_empty(), "reaction candidate review override can be cleared")
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
	t.eq(panel.cue_entry("order_help").get("id", ""), "functional_order_help", "the order screen has a purchasing guidance pose")
	t.eq(panel.cue_entry("restock_help").get("id", ""), "functional_restock_guidance", "the restock screen has a replenishment guidance pose")
	t.eq(panel.cue_entry("opening_checklist").get("id", ""), "functional_opening_checklist", "the setup management screen has an opening checklist pose")
	t.eq(panel.cue_entry("business_started").get("id", ""), "functional_business_greeting", "opening cut-in has a greeting pilot pose")
	t.eq(panel.cue_entry("layout_help").get("id", ""), "functional_layout_guidance", "build mode has a layout guidance pilot pose")
	t.eq(panel.stage_entry({"story_cue": "story_first_profit", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_first_profit", "first-profit story uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "story_register", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_register_guidance", "register tutorial uses the register guidance pose")
	t.eq(panel.stage_entry({"story_cue": "story_first_restock", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_restock_guidance", "restock tutorial uses the restock guidance pose")
	t.eq(panel.day_end_entry("worried").get("id", ""), "functional_day_end_review", "negative day-end uses the review pose")
	t.eq(panel.day_end_entry("normal").get("id", ""), "functional_day_report", "normal day-end uses the business report pose")
	t.eq(panel.stage_entry({"story_cue": "story_start", "gameplay_event": {}, "progression": {}}).get("kind", ""), "functional_pose", "story start stage avoids a bust-up asset")
	t.eq(panel.reaction_entry({"story_cue": "story_start", "gameplay_event": {}, "progression": {}}).get("id", ""), "reaction_discovery", "story start uses the discovery bust-up layer")
	t.eq(panel.stage_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("kind", ""), "functional_pose", "queue reaction stage uses a functional full-body asset")
	t.eq(panel.stage_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_queue", "queue story uses the queue-specific pose")
	t.eq(panel.reaction_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("id", ""), "reaction_pleading", "queue story uses the pleading bust-up layer")
	t.eq(panel.reaction_entry({"story_cue": "story_first_profit", "gameplay_event": {}, "progression": {}}).get("id", ""), "reaction_milestone_calm", "first-profit story uses the clean calm bust-up layer")
	t.eq(panel.reaction_entry({"story_cue": "story_first_sale", "gameplay_event": {}, "progression": {}}).get("id", ""), "reaction_first_sale_joy", "first-sale story uses the clean joy bust-up layer")
	t.eq(panel.stage_entry({"story_cue": "story_staff_short", "gameplay_event": {}, "progression": {}}).get("id", ""), "functional_staff_short", "staff shortage story uses the staff-specific pose")
	t.ok(panel.reaction_entry({"story_cue": "story_staff_short", "gameplay_event": {}, "progression": {}}).is_empty(), "staff shortage keeps its full-body pose instead of stacking a reaction")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_six_categories"]}}).get("id", ""), "functional_six_categories", "six-category achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_ten_sales"]}}).get("id", ""), "functional_ten_sales", "ten-sales achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_three_fixtures"]}}).get("id", ""), "functional_expansion", "fixture expansion achievement uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"completed_milestone_ids": ["ms_first_week"]}}).get("id", ""), "functional_day_end_review", "first-week achievement uses its review pose")
	t.eq(panel.cue_entry("staff_schedule_open").get("id", ""), "functional_staff_schedule", "staff scheduling has a functional pilot pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_sales_3", "completed_milestone_ids": []}}).get("id", ""), "functional_three_sales", "sales challenge uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_stock_2", "completed_milestone_ids": []}}).get("id", ""), "functional_stock_challenge", "stock challenge uses its presentation pose")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {"active_daily_challenge_id": "challenge_no_waste", "completed_milestone_ids": []}}).get("id", ""), "functional_no_waste", "no-waste challenge uses its presentation pose")
	t.eq(panel.event_entry("evt_neighbor_mentions").get("id", ""), "event_neighbor_mentions", "neighbor mentions uses the selected event pilot")
	t.eq(panel.event_entry("evt_quiet_street").get("id", ""), "reaction_deadpan", "quiet street uses the dedicated deadpan reaction slot")
	for event_id in ["evt_local_fair", "evt_roadworks", "evt_hot_day", "evt_cold_day", "evt_sweets_spotlight", "evt_snack_buzz", "evt_lunch_pick", "evt_drink_pick", "evt_bread_feature", "evt_after_work"]:
		t.eq(panel.event_entry(event_id).get("trigger", ""), event_id, "%s has a selected event pilot" % event_id)
	# Every selected functional/event entry must have a concrete presentation route.
	# This guards against adding a registry row that is reviewable but unreachable in-game.
	for entry in panel._entries:
		var kind := String(entry.get("kind", ""))
		var trigger := String(entry.get("trigger", ""))
		var id := String(entry.get("id", ""))
		if kind == "functional_pose":
			t.eq(panel.cue_entry(trigger).get("id", ""), id, "%s functional trigger is reachable" % id)
		elif kind == "event_image":
			t.eq(panel.event_entry(trigger).get("id", ""), id, "%s event trigger is reachable" % id)
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {}, "progression": {}}).get("id", ""), "fullbody_dynamic_201", "default full-body pilot is reachable")
	t.eq(panel.stage_entry({"story_cue": "", "gameplay_event": {"event_id": "evt_quiet_street"}, "progression": {}}).get("id", ""), "fullbody_dynamic_201", "quiet-street full-body fallback is reachable")
	t.eq(panel.stage_entry({"story_cue": "story_first_sale", "gameplay_event": {}, "progression": {}}).get("id", ""), "fullbody_emotion_05", "first-sale full-body pilot is reachable")


func test_runtime_assistant_stage_uses_selected_pilot(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var guide := main.get_node("ProgressionController")
	var panel := main.get_node("CharacterVisualPilotPanel")
	t.ok(panel.is_pilot_enabled(), "the pilot toggle defaults on for visual review")
	t.ok(guide._pilot_figure != null, "the assistant stage owns a pilot figure layer")
	t.ok(guide._pilot_reaction != null, "the assistant stage owns a separate pilot reaction layer")
	t.ok(guide._pilot_figure.texture is Texture2D, "the assistant stage loads a pilot texture")
	var crop: Control = guide._pilot_figure.get_parent()
	t.eq(String(crop.name), "AssistantPilotBustupCrop", "the store assistant uses a display-only bust-up crop frame")
	t.ok(crop.clip_contents, "the bust-up crop clips only the display frame")
	t.eq(crop.size.y, 300.0, "the display crop keeps the upper-body window height")
	t.ok(crop.offset_left > 0.0, "the assistant crop is slightly inset from the left edge")
	t.ok(crop.offset_left < 236.0, "the assistant crop sits to the left of the menu safe edge")
	t.eq(guide._bubble.offset_left - crop.offset_left, 260.0, "the dialogue bubble follows the portrait horizontally")
	t.ok(guide._bubble.offset_top > -ProgressionController.FIGURE_SIZE.y - ProgressionController.ASSISTANT_BOTTOM + 40.0, "the dialogue bubble is lowered in the assistant slot")
	var chrome_bottom: float = main.get_viewport_rect().size.y - ProgressionController.ASSISTANT_BOTTOM
	t.ok(crop.get_global_rect().end.y <= chrome_bottom + 1.0, "the assistant crop stays above the bottom chrome")
	t.ok(guide._bubble.get_global_rect().end.y <= chrome_bottom + 1.0, "the assistant dialogue stays above the bottom chrome")
	t.eq(Vector2((guide._pilot_figure.texture as Texture2D).get_size()), Vector2(1024, 1536), "the source full-body texture remains unmodified")
	panel.set_review_candidate("additional_001")
	await tree.process_frame
	t.ok(guide._stage.visible, "candidate review override makes the assistant stage visible")
	t.ok(guide._pilot_figure.visible, "candidate review override displays the selected full-body candidate")
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, "res://assets/review/derived_alpha/additional_001.png", "candidate review uses the selected derived preview")
	panel.clear_review_candidate()
	var reaction_preview: TextureRect = panel._reaction_image
	t.ok(reaction_preview != null, "bust-up review has a dedicated preview slot")
	panel._show_selected(panel._find("reaction_discovery"))
	t.ok(reaction_preview.visible, "bust-up review uses its dedicated preview slot")
	t.ok(not panel._image.visible, "bust-up review does not use the full-body preview slot")
	panel._show_selected(panel.stage_entry(guide._snap))
	var expected: Dictionary = panel.stage_entry(guide._snap)
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, expected.get("runtime_path", ""), "the stage texture follows the shared pilot route")
	guide.apply_snapshot({"story_cue": "story_start", "progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "active_daily_challenge_id": null, "completed_milestone_ids": []}})
	await tree.process_frame
	t.ok(guide._pilot_reaction.visible, "story start shows the discovery bust-up reaction")
	t.eq((guide._pilot_reaction.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/reaction_discovery.png", "story start loads the discovery reaction texture")
	t.eq(guide._pilot_reaction_symbol.text, "!", "story start renders the registry symbol as a Godot overlay")
	t.ok(guide._pilot_reaction_symbol.visible, "story start shows the independent reaction symbol layer")
	t.ok(not guide._pilot_figure.visible, "story start does not stack the full-body pilot with the reaction")
	guide.apply_snapshot({"story_cue": "story_queue_giveup", "progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "active_daily_challenge_id": null, "completed_milestone_ids": []}})
	await tree.process_frame
	t.ok(guide._pilot_reaction.visible, "queue give-up shows the pleading bust-up reaction")
	t.eq((guide._pilot_reaction.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/reaction_pleading.png", "queue give-up loads the pleading reaction texture")
	t.eq(guide._pilot_reaction_symbol.text, "?", "queue give-up renders the question symbol as a Godot overlay")
	guide.apply_snapshot({"story_cue": "story_first_profit", "progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "active_daily_challenge_id": null, "completed_milestone_ids": []}})
	await tree.process_frame
	t.ok(guide._pilot_reaction.visible, "first profit shows the clean calm bust-up reaction")
	t.eq((guide._pilot_reaction.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/reaction_milestone_calm.png", "first profit loads the clean calm reaction texture")
	t.ok(not guide._pilot_reaction_symbol.visible, "clean calm reaction does not add a duplicate symbol")
	guide.apply_snapshot({"story_cue": "story_first_sale", "progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "active_daily_challenge_id": null, "completed_milestone_ids": []}})
	await tree.process_frame
	t.ok(guide._pilot_reaction.visible, "first sale shows the clean joy bust-up reaction")
	t.eq((guide._pilot_reaction.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/reaction_first_sale_joy.png", "first sale loads the clean joy reaction texture")
	t.ok(not guide._pilot_reaction_symbol.visible, "clean joy reaction does not add a duplicate symbol")
	guide.apply_snapshot({"story_cue": "story_staff_short", "progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "active_daily_challenge_id": null, "completed_milestone_ids": []}})
	await tree.process_frame
	t.ok(not guide._pilot_reaction.visible, "staff shortage does not stack a bust-up reaction")
	t.ok(not guide._pilot_reaction_symbol.visible, "staff shortage hides the reaction symbol layer")
	t.ok(guide._pilot_figure.visible, "staff shortage shows its dedicated full-body pose")
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_staff_short.png", "staff shortage loads the dedicated full-body texture")
	guide.say_day_end("通常決算の確認", "normal")
	await tree.process_frame
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_day_report.png", "normal day-end uses the report pilot in the runtime stage")
	guide.say_day_end("赤字決算の確認", "worried")
	await tree.process_frame
	t.eq((guide._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_day_end_review.png", "worried day-end uses the review pilot in the runtime stage")
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
	main.open_goods_order()
	await tree.process_frame
	t.eq(pc._pilot_cue_id, "order_help", "opening the order screen requests the purchasing guidance pose")
	t.ok(pc._stage.visible, "order guidance remains visible over the management screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_order_help.png", "order screen uses the purchasing guidance pose")
	var chrome := main.get_node_or_null("MockupChrome")
	if chrome != null:
		t.ok(not chrome.get_node("WindowLayer/Rikka").visible, "mockup assistant figure is hidden while the pilot is active")
		t.ok(not chrome.get_node("WindowLayer/Bubble").visible, "mockup assistant bubble is hidden while the pilot is active")
	main.open_screen_tab("経営")
	await tree.process_frame
	t.eq(pc._pilot_cue_id, "opening_checklist", "opening the setup management screen requests the opening checklist pose")
	t.ok(pc._stage.visible, "opening checklist remains visible over the management screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_opening_checklist.png", "setup management uses the opening checklist pose")
	main.open_restock_section()
	await tree.process_frame
	t.eq(pc._pilot_cue_id, "restock_help", "opening the restock section requests the replenishment guidance pose")
	t.ok(pc._stage.visible, "restock guidance remains visible over the management screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_restock_guidance.png", "restock section uses the replenishment guidance pose")
	main.call("open_screen_tab", "店員")
	await tree.process_frame
	t.eq(pc._pilot_cue_id, "staff_schedule_open", "opening the staff screen requests the schedule pose")
	t.ok(pc._stage.visible, "the schedule pose remains visible over the staff screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_staff_schedule.png", "staff screen uses the schedule pose")
	player.pilot_cue_requested.emit("low_stock_notice", {})
	await tree.process_frame
	t.ok(pc._stage.visible, "low-stock warning remains visible over an open management screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_low_stock.png", "open management screen uses the low-stock pilot pose")
	player.pilot_cue_requested.emit("expiry_notice", {})
	await tree.process_frame
	t.ok(pc._stage.visible, "expiry warning remains visible over an open management screen")
	t.eq((pc._pilot_figure.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/functional_expiry.png", "open management screen uses the expiry pilot pose")
	pc._pilot_cue_timer.stop()
	pc._clear_pilot_cue()
	await tree.process_frame
	if chrome != null:
		t.ok(chrome.get_node("WindowLayer/Rikka").visible, "mockup assistant figure returns after the pilot cue")
		t.ok(chrome.get_node("WindowLayer/Bubble").visible, "mockup assistant bubble returns after the pilot cue")
	main.queue_free()
	await tree.process_frame


func test_runtime_event_panel_shows_selected_event_pilot(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var panel: Node = main.get_node("CharacterVisualPilotPanel")
	var events: Node = main.get_node("EventController")
	var view := {
		"status": "active",
		"event_id": "evt_roadworks",
		"name_ja": "近隣の工事",
		"description_ja": "近所の工事で、日中の通行客が減るようです。",
		"event_start_sec": 0,
		"event_end_sec": 3600,
		"start_sec": 0,
		"end_sec": 3600,
		"traffic": 0.75,
		"categories": {},
		"tone": "challenge",
	}
	events.apply_snapshot({"gameplay_event": view, "event_catalog": [], "event_history": [], "time_sec": 1800, "stocked_categories": []})
	var picture: TextureRect = events._pilot_picture
	var reaction_picture: TextureRect = events._pilot_reaction_picture
	t.ok(panel.is_pilot_enabled(), "event pilot is enabled for the QA runtime")
	t.ok(events._visual_row != null, "event visuals use a dedicated horizontal layout row")
	t.ok(events._pilot_column != null and events._pilot_column.get_parent() == events._visual_row, "pilot slots share the event visual row")
	t.ok(picture.visible, "active events show the selected event pilot")
	t.ok(not reaction_picture.visible, "full-body event pilots do not use the reaction slot")
	t.eq((picture.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/event_roadworks.png", "roadworks selects the event pilot texture")
	t.ok(picture.size.x > 0.0, "event pilot has a visible layout width")
	t.ok(picture.size.y > 0.0, "event pilot has a visible layout height")
	view["event_id"] = "evt_quiet_street"
	events.apply_snapshot({"gameplay_event": view, "event_catalog": [], "event_history": [], "time_sec": 1800, "stocked_categories": []})
	t.ok(not picture.visible, "reaction events do not use the full-body slot")
	t.ok(reaction_picture.visible, "events without a dedicated illustration show a reaction pilot")
	t.eq((reaction_picture.texture as Texture2D).resource_path, "res://assets/runtime/character_pilot/derived_alpha/reaction_deadpan.png", "quiet street uses the deadpan reaction pilot")
	t.ok(reaction_picture.size.x > 0.0 and reaction_picture.size.y > 0.0, "reaction pilot has a visible layout size")
	t.eq(events._pilot_reaction_symbol.text, "...", "event reaction uses the registry symbol as a separate Godot overlay")
	t.ok(events._pilot_reaction_symbol.visible, "event reaction symbol has its own visible layer")
	main.queue_free()
	await tree.process_frame
