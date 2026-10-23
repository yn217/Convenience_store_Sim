extends RefCounted
## Issue #30 (presentation side): limits, mute / reduce_motion, missing sounds, synthesized SFX,
## time-of-day tint and the whole chain on the real screen.

const TEST_SETTINGS := "user://test_cue_settings.json"


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var player: CuePlayer = main.get_node("CuePlayer")
	player.settings_path = TEST_SETTINGS
	return [main, main.get_node("AppRoot"), player]


func _req(cue_id: String, priority: String, payload: Dictionary = {}, sfx = null, dur: float = 1.0) -> Dictionary:
	return {"cue_id": cue_id, "source_event_id": "ev", "tick": 0, "priority": priority, "animation_id": "x", "sfx_key": sfx, "duration_seconds": dur, "payload": payload}


func _done(r: Array, tree) -> void:
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)
	r[0].queue_free()
	await tree.process_frame


func test_limits_of_the_decorations(t, tree) -> void:
	var r: Array = await _boot(tree)
	var p: CuePlayer = r[2]
	var reqs: Array = []
	for i in 12:
		reqs.append(_req("long_queue", "normal", {"register_id": "r%d" % i}))   # same text: stacked once
		reqs.append(_req("expiry_notice", "important", {"qty": i}))
		reqs.append(_req("checkout_success", "normal", {"revenue_yen": 100 + i, "register_id": "fx_x"}, "register_beep"))
		reqs.append(_req("milestone_celebrate", "important", {"name_ja": "称号%d" % i}, "milestone"))
	p.play(reqs)
	t.ok(p.toasts.size() <= CuePlayer.MAX_TOASTS, "toasts: %d" % p.toasts.size())
	t.ok(p.floats.size() <= CuePlayer.MAX_FLOATS, "sales floats: %d" % p.floats.size())
	t.ok(p.particles.size() <= CuePlayer.MAX_PARTICLES, "particles: %d" % p.particles.size())
	t.ok(p.particles.size() > 0)
	t.eq(p._players.size(), CuePlayer.MAX_SFX, "eight sound voices")
	var playing := 0
	for v in p._players:
		if v.playing:
			playing += 1
	t.ok(playing <= CuePlayer.MAX_SFX)
	# Everything expires with real time.
	p.advance(10.0)
	t.ok(not p.has_motion(), "all decorations ended")
	await _done(r, tree)


func test_text_survives_mute_and_reduce_motion(t, tree) -> void:
	var r: Array = await _boot(tree)
	var p: CuePlayer = r[2]
	p.set_muted(true)
	p.set_reduce_motion(true)
	p.play([_req("milestone_celebrate", "important", {"name_ja": "はじめての会計"}, "milestone"), _req("checkout_success", "normal", {"revenue_yen": 300, "register_id": "fx_x"}, "register_beep"),
			_req("low_stock_notice", "normal", {"fixture_id": "nope"}, "warning_soft")])
	t.eq(p.sfx_played.size(), 0, "muted: no sound")
	t.eq(p.particles.size(), 0, "reduce_motion: no confetti")
	t.eq(p.floats.size(), 0, "reduce_motion: no rising +¥")
	var texts := p.toasts.map(func(x): return x["text"])
	t.ok(texts.any(func(x): return x.contains("はじめての会計")), "the notice text is still shown: %s" % str(texts))
	t.ok(texts.any(func(x): return x.contains("残りわずか")))
	t.ok(FileAccess.file_exists(TEST_SETTINGS), "settings are saved")
	var again := CuePlayer.new()
	again.settings_path = TEST_SETTINGS
	again.load_settings()
	t.ok(again.muted and again.reduce_motion, "and restored")
	again.free()
	await _done(r, tree)


func test_missing_sound_or_unknown_cue_never_breaks(t, tree) -> void:
	var r: Array = await _boot(tree)
	var p: CuePlayer = r[2]
	p.play([_req("expiry_notice", "important", {"qty": 3}, "no_such_sound"), _req("brand_new_cue", "ambient", {}, "also_missing")])
	t.eq(p.sfx_played.size(), 0)
	t.eq(p.toasts.size(), 1, "the written notice is there even though the sound is missing")
	t.eq(p.handled, ["expiry_notice", "brand_new_cue"])
	await _done(r, tree)


func test_synthesized_sfx_are_quiet_enough_and_short(t, _tree) -> void:
	for key in SfxBank.NOTES:
		t.ok(SfxBank.peak_dbfs(key) <= -1.0, "%s peak %.1f dBFS" % [key, SfxBank.peak_dbfs(key)])
		t.ok(SfxBank.duration_sec(key) > 0.03 and SfxBank.duration_sec(key) < 1.0, key)
		var wav := SfxBank.stream(key)
		t.ok(wav != null and wav.mix_rate == 48000 and not wav.stereo, "%s is mono 48 kHz" % key)
	# every sfx key the cue data names exists in the bank
	var cues = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/cues_v1.json"))
	for c in cues:
		if c["sfx_key"] != null and c["sfx_key"] != "":
			t.ok(SfxBank.has(c["sfx_key"]), "sfx %s of cue %s" % [c["sfx_key"], c["cue_id"]])


func test_time_of_day_tint(t, _tree) -> void:
	t.eq(LightingModel.phase_name(9 * 3600), "day")
	t.eq(LightingModel.phase_name(18 * 3600), "evening")
	t.eq(LightingModel.phase_name(23 * 3600), "night")
	t.eq(LightingModel.tint(12 * 3600), LightingModel.DAY)
	t.eq(LightingModel.tint(18 * 3600), LightingModel.EVENING)
	t.eq(LightingModel.tint(2 * 3600), LightingModel.NIGHT)
	for h in range(0, 24):
		var c := LightingModel.tint(h * 3600 + 900)
		t.ok(minf(c.r, minf(c.g, c.b)) >= 0.6, "hour %d stays readable" % h)
	var blend := LightingModel.tint(int(16.5 * 3600))
	t.ok(blend.g < 1.0 and blend.g > LightingModel.EVENING.g, "16-17 blends day to evening")
	t.eq(LightingModel.tint(86400 + 12 * 3600), LightingModel.DAY, "the next day repeats")


func test_whole_chain_on_the_real_screen(t, tree) -> void:
	var r: Array = await _boot(tree)
	var app: Node = r[1]
	var p: CuePlayer = r[2]
	var steps: Array = [
		{"command_id": "c1", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0},
		{"command_id": "c2", "kind": &"PLACE_FIXTURE", "type_id": "shelf_general", "x": 4, "y": 5, "rotation": 0},
		{"command_id": "c3", "kind": &"ORDER_STOCK", "sku_id": "snack_001", "qty": 12},
		{"command_id": "c4", "kind": &"RESTOCK", "instance_id": "fx_0002", "slot_id": "row0", "sku_id": "snack_001", "qty": 12},
		{"command_id": "c5", "kind": &"START_BUSINESS"},
	]
	for c in steps:
		t.ok(app.run_command(c).ok)
	t.ok(p.handled.has("ui_confirm"), "a successful command raises ui_confirm")
	app.state.balance["base_potential_visitors_per_day"] = 4000
	app.state.speed_setting = 4
	var n := 0
	while app.state.visit_stats["purchased"] < 1 and n < 40000:
		n += app.runner.process_frame(1.0 / 15.0)
	app._publish_snapshot()
	t.ok(app.state.visit_stats["purchased"] >= 1)
	for expected in ["customer_enter", "product_pickup", "checkout_success"]:
		t.ok(p.handled.has(expected), "%s reached the player: %s" % [expected, str(p.handled.slice(0, 12))])
	# Nothing the player does can change money: remove it and play the same run again.
	var cash: int = app.state.cash_yen
	t.ok(cash > 0)
	await _done(r, tree)
	var r2: Array = await _boot(tree)
	var app2: Node = r2[1]
	r2[2].queue_free()   # no CuePlayer at all
	await tree.process_frame
	for c in steps:
		app2.run_command(c)
	app2.state.balance["base_potential_visitors_per_day"] = 4000
	app2.state.speed_setting = 4
	n = 0
	while app2.state.visit_stats["purchased"] < 1 and n < 40000:
		n += app2.runner.process_frame(1.0 / 15.0)
	t.eq(app2.state.cash_yen, cash, "same cash with the whole presentation side missing")
	await _done(r2, tree)
