extends RefCounted
## data/balance/mvp_v1.json must keep the 00_BASELINE §2 defaults.


func test_balance_defaults(t, _tree) -> void:
	var b = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	t.ok(typeof(b) == TYPE_DICTIONARY, "balance json parses")
	t.eq(int(b["store_width_tiles"]), 16)
	t.eq(int(b["store_height_tiles"]), 12)
	t.eq(int(b["starting_cash_yen"]), 500000)
	t.eq(int(b["simulation_step_game_seconds"]), 2)
	t.eq(int(b["game_seconds_per_real_second"]), 60)
	t.eq(b["game_speed_options"], [0.0, 1.0, 2.0, 4.0], "speed options")
