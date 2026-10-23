extends RefCounted
## HUD weekday text for the ClockLabel tooltip: DAY 0 is 月曜日, the week repeats every 7 days.

const Hud := preload("res://scripts/presentation/game_hud.gd")


func test_weekday_over_two_weeks(t, _tree) -> void:
	var expected := ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"]
	for day in 14:
		t.eq(Hud.weekday_text(day), expected[day % 7], "day %d" % day)
