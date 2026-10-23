extends RefCounted
## 09 §1 fixed step, 08 §1 speed/command semantics, 08 §4 tests 1 and 6.

const Seeds := preload("res://tests/support/test_seeds.gd")


func _new_state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS)


func test_clock_step_count_independent_of_frame_rate(t, _tree) -> void:
	var coarse := GameClock.new()
	var fine := GameClock.new()
	var coarse_steps := 0
	var fine_steps := 0
	for i in 60:
		coarse_steps += coarse.advance(1.0 / 60.0, 1)
	coarse_steps += 0
	for i in 240:
		fine_steps += fine.advance(1.0 / 240.0, 1)
	t.eq(coarse_steps, 30, "1x speed = 30 steps per real second @60fps")
	t.eq(fine_steps, 30, "1x speed = 30 steps per real second @240fps")


func test_clock_speed4_and_pause(t, _tree) -> void:
	var c := GameClock.new()
	t.eq(c.advance(1.0, 0), 0, "speed 0 runs no steps")
	t.eq(c.advance(1.0, 4), 120, "4x = 120 steps/s")


func test_clock_never_skips_steps_over_cap(t, _tree) -> void:
	var c := GameClock.new()
	t.eq(c.advance(10.0, 1, 100), 100, "capped steps")
	t.eq(c.advance(0.0, 1, 1000), 200, "remaining 300-100 steps are paid back, not dropped")


func test_new_game_is_empty_setup_paused(t, _tree) -> void:
	var s := _new_state()
	t.eq(s.business_state, GameState.SETUP)
	t.eq(s.speed_setting, 0)
	t.eq(s.cash_yen, 500000)
	t.eq(s.store_width, 16)
	t.eq(s.store_height, 12)
	t.eq(s.rng_states["arrivals"], 1234)


func test_setup_never_advances_time(t, _tree) -> void:
	var s := _new_state()
	var runner := SimulationRunner.new(s)
	t.eq(runner.process_frame(5.0), 0, "SETUP runs no steps")
	t.eq(s.time_sec, 0)


func test_open_advances_time_and_pause_stops_it(t, _tree) -> void:
	var s := _new_state()
	s.business_state = GameState.OPEN
	s.speed_setting = 1
	var runner := SimulationRunner.new(s)
	runner.process_frame(1.0)
	t.eq(s.time_sec, 60, "1 real second at 1x = 60 game seconds")
	s.speed_setting = 0
	runner.process_frame(1.0)
	t.eq(s.time_sec, 60, "speed 0 freezes time")


func test_set_speed_command_runs_while_clock_stopped(t, _tree) -> void:
	var s := _new_state()
	s.business_state = GameState.OPEN
	var cmds := GameCommands.new(s)
	var r := cmds.execute({"command_id": "c1", "kind": &"SET_SPEED", "speed": 2})
	t.ok(r.ok, "SET_SPEED accepted at speed 0")
	t.eq(r.new_revision, 1)
	t.eq(s.speed_setting, 2)
	t.eq(s.time_sec, 0, "command phase does not advance the clock")


func test_set_speed_rejects_nonzero_in_setup_and_bad_values(t, _tree) -> void:
	var s := _new_state()
	var cmds := GameCommands.new(s)
	var r1 := cmds.execute({"command_id": "c1", "kind": &"SET_SPEED", "speed": 1})
	t.ok(not r1.ok, "SETUP rejects non-zero speed")
	t.eq(r1.new_revision, 0, "failure keeps revision")
	var r2 := cmds.execute({"command_id": "c2", "kind": &"SET_SPEED", "speed": 3})
	t.ok(not r2.ok, "3 is not a valid speed")
	t.eq(s.revision, 0)
	t.eq(s.applied_command_ids.size(), 0, "failed commands are not recorded")


func test_duplicate_command_id_is_idempotent(t, _tree) -> void:
	var s := _new_state()
	s.business_state = GameState.OPEN
	var cmds := GameCommands.new(s)
	cmds.execute({"command_id": "c1", "kind": &"SET_SPEED", "speed": 2})
	var again := cmds.execute({"command_id": "c1", "kind": &"SET_SPEED", "speed": 4})
	t.ok(not again.ok)
	t.eq(again.code, &"ALREADY_APPLIED")
	t.eq(s.speed_setting, 2, "replayed command changes nothing")
	t.eq(s.revision, 1)


func test_unknown_kind_is_rejected(t, _tree) -> void:
	var s := _new_state()
	var r := GameCommands.new(s).execute({"command_id": "c9", "kind": &"PLACE_FIXTURE"})
	t.eq(r.code, &"INVALID_OPERATION")
	t.eq(s.revision, 0)
