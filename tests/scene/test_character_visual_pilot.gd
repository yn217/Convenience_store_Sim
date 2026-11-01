extends RefCounted
## Focused registry and routing checks for the Issue #230 character visual pilot.


func test_registry_assets_and_story_routes_load(t, _tree) -> void:
	var panel: Node = load("res://scripts/presentation/character_visual_pilot_panel.gd").new()
	panel._entries = panel._load_entries()
	t.eq(panel._entries.size(), 18, "the pilot registry exposes all 18 selected visuals")
	for entry in panel._entries:
		var id := String(entry.get("id", ""))
		var path := String(entry.get("runtime_path", ""))
		t.ok(not bool(entry.get("runtime_approved", true)), "%s remains review-only" % id)
		t.ok(ResourceLoader.exists(path), "%s runtime path exists" % id)
		t.ok(load(path) is Texture2D, "%s runtime texture loads" % id)
	for pair in [
		["story_start", "reaction_discovery"],
		["story_register", "fullbody_tutorial_layout"],
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
	t.eq(panel.stage_entry({"story_cue": "story_start", "gameplay_event": {}, "progression": {}}).get("kind", ""), "functional_pose", "story start stage avoids a bust-up asset")
	t.eq(panel.stage_entry({"story_cue": "story_queue_giveup", "gameplay_event": {}, "progression": {}}).get("kind", ""), "fullbody", "queue reaction stage uses a full-body asset")
	t.eq(panel.event_entry("evt_neighbor_mentions").get("id", ""), "event_neighbor_mentions", "neighbor mentions uses the selected event pilot")
	for event_id in ["evt_local_fair", "evt_roadworks", "evt_hot_day", "evt_cold_day", "evt_sweets_spotlight", "evt_snack_buzz", "evt_after_work"]:
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
