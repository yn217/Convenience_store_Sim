extends RefCounted
## Rikka's live reactions: the data names real cues and images, lines rotate, and cooldowns keep her from chattering.


func test_the_reaction_data_names_known_cues_and_existing_images(t, _tree) -> void:
	var r := RikkaReactions.load_default()
	var known := {}
	for cue in JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/cues_v1.json")):
		known[String(cue["cue_id"])] = true
	t.ok(r.cue_ids().size() >= 15, "she reacts to many gameplay cues (%d)" % r.cue_ids().size())
	for cue_id in r.cue_ids():
		t.ok(known.has(cue_id), "%s is a cue the game plays" % cue_id)
		t.ok(ResourceLoader.exists(r.image_for(cue_id)), "%s has its reaction image" % cue_id)
	t.ok(not r.handles("checkout_success"), "every sale is too frequent for a reaction")


func test_lines_rotate_and_cooldowns_hold(t, _tree) -> void:
	var r := RikkaReactions.new()
	r.load_text(JSON.stringify({"global_cooldown_sec": 5, "reactions": [
		{"cue_id": "long_queue", "image": "res://a.png", "cooldown_sec": 30, "lines": ["one", "two"]},
		{"cue_id": "bake_done", "image": "res://b.png", "cooldown_sec": 30, "lines": ["bread"]}]}))
	t.eq(r.pick("long_queue", 0.0).get("line"), "one", "the first line first")
	t.eq(r.pick("long_queue", 1.0), {}, "the same cue cools down")
	t.eq(r.pick("bake_done", 2.0), {}, "another cue waits for the gap between reactions")
	t.eq(r.pick("bake_done", 6.0).get("line"), "bread", "after the gap another cue reacts")
	t.eq(r.pick("long_queue", 31.0).get("line"), "two", "after its cooldown the next line")
	t.eq(r.pick("long_queue", 70.0).get("line"), "one", "and the lines wrap around")
	t.eq(r.pick("unknown", 200.0), {}, "an unknown cue has no reaction")


func test_a_bad_file_only_costs_the_reactions(t, _tree) -> void:
	var r := RikkaReactions.new()
	r.load_text("not json")
	t.eq(r.cue_ids().size(), 0, "no rows from a broken file")
	r.load_text(JSON.stringify({"reactions": [{"cue_id": "long_queue", "image": "", "lines": ["x"]}, {"cue_id": "bake_done", "image": "res://b.png", "lines": []}, "junk"]}))
	t.eq(r.cue_ids().size(), 0, "rows without an image or lines are skipped")
