extends RefCounted
## #105 B1: the HUD's time-of-day and season icons. Pure functions of the game clock and the calendar season word (#135).

const Hud := preload("res://scripts/presentation/game_hud.gd")
const Cal := preload("res://scripts/domain/game_calendar.gd")


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


func test_season_icon_per_season_word(t, _tree) -> void:
	t.eq(Hud.season_icon("春"), "sakura", "spring")
	t.eq(Hud.season_icon("夏"), "leaf", "summer")
	t.eq(Hud.season_icon("秋"), "maple", "autumn")
	t.eq(Hud.season_icon("冬"), "snowflake", "winter")


func test_season_icon_follows_the_calendar_season(t, _tree) -> void:
	# DAY 0 is 4月 (春), DAY 8 is 6月 (夏), DAY 36 is 1月 (冬)
	t.eq(Hud.season_icon(Cal.season_of(0)), "sakura", "DAY 0 shows sakura")
	t.eq(Hud.season_icon(Cal.season_of(8)), "leaf", "DAY 8 shows leaf")
	t.eq(Hud.season_icon(Cal.season_of(36)), "snowflake", "DAY 36 shows snowflake")
