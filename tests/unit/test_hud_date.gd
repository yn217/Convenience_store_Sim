extends RefCounted
## HUD calendar date (DateLabel): DAY 0 is 4月1日(月) of a non-leap 365-day year, seasons 春/夏/秋/冬.

const Hud := preload("res://scripts/presentation/game_hud.gd")


func test_date_text_known_days(t, _tree) -> void:
	t.eq(Hud.date_text(0), "春 4月1日(月)", "DAY 0")
	t.eq(Hud.date_text(1), "春 4月2日(火)", "DAY 1")
	t.eq(Hud.date_text(6), "春 4月7日(日)", "DAY 6 is 日曜日")
	t.eq(Hud.date_text(29), "春 4月30日(火)", "DAY 29 is 4月30日")
	t.eq(Hud.date_text(30), "春 5月1日(水)", "DAY 30 is 5月1日")
	t.eq(Hud.date_text(90), "夏 6月30日(日)", "DAY 90 is 6月30日")
	t.eq(Hud.date_text(364), "春 3月31日(月)", "DAY 364 is the last day of the year")
	t.eq(Hud.date_text(365), "春 4月1日(火)", "DAY 365 wraps to 4月1日; weekday keeps cycling by 7")


func test_date_text_seasons(t, _tree) -> void:
	t.eq(Hud.date_text(61), "夏 6月1日(土)", "June starts 夏")
	t.eq(Hud.date_text(153), "秋 9月1日(日)", "September starts 秋")
	t.eq(Hud.date_text(244), "冬 12月1日(日)", "December starts 冬")
	t.eq(Hud.date_text(275), "冬 1月1日(水)", "January is 冬")
	t.eq(Hud.date_text(334), "春 3月1日(土)", "March is 春 again")
