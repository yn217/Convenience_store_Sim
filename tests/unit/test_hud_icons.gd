extends RefCounted
## #105 B1: the HUD's time-of-day and season icons and the short date line. Pure functions of the game clock / day.

const Hud := preload("res://scripts/presentation/game_hud.gd")


func test_time_icon_follows_the_game_hour(t, _tree) -> void:
	t.eq(Hud.time_icon(9 * 3600), "sun", "09:00 is daytime")
	t.eq(Hud.time_icon(15 * 3600 + 59 * 60), "sun", "just before 16:00 is still day")
	t.eq(Hud.time_icon(16 * 3600), "sunset", "16:00 is sunset")
	t.eq(Hud.time_icon(18 * 3600 + 59 * 60), "sunset", "until 19:00")
	t.eq(Hud.time_icon(19 * 3600), "moon", "19:00 is night")
	t.eq(Hud.time_icon(2 * 3600), "moon", "02:00 is night")
	t.eq(Hud.time_icon(5 * 3600), "sun", "05:00 is morning again")
	t.eq(Hud.time_icon(86400 + 9 * 3600), "sun", "the clock wraps every day")


func test_time_icon_never_shows_weather(t, _tree) -> void:
	for hour in 24:
		var icon_name: String = Hud.time_icon(hour * 3600)
		t.ok(icon_name in ["sun", "sunset", "moon"], "hour %d uses a time-of-day icon" % hour)


func test_season_icon_per_season(t, _tree) -> void:
	t.eq(Hud.season_icon(3), "sakura", "spring starts in March")
	t.eq(Hud.season_icon(5), "sakura", "May is spring")
	t.eq(Hud.season_icon(7), "leaf", "summer")
	t.eq(Hud.season_icon(10), "maple", "autumn")
	t.eq(Hud.season_icon(12), "snowflake", "winter")
	t.eq(Hud.season_icon(2), "snowflake", "February is winter")


func test_season_icon_matches_season_text(t, _tree) -> void:
	for month in range(1, 13):
		var text := Hud.season_text(month)
		var icon_name := Hud.season_icon(month)
		t.ok((text == "春") == (icon_name == "sakura"), "month %d spring icon" % month)
		t.ok((text == "冬") == (icon_name == "snowflake"), "month %d winter icon" % month)


func test_short_date_and_full_date(t, _tree) -> void:
	t.eq(Hud.short_date_text(0), "4月1日(月)", "DAY 0 is 4月1日 of a Monday")
	t.eq(Hud.date_text(0), "春 4月1日(月)", "full line keeps the season")
	t.eq(Hud.short_date_text(29), "4月30日(火)", "last day of April")
	t.eq(Hud.short_date_text(30), "5月1日(水)", "May starts the next day")
	t.eq(Hud.date_text(365), "春 4月1日(火)", "the year repeats the dates; the weekday keeps counting")
