extends RefCounted
## #135: compressed in-game calendar. 1 month = 4 game days (each day is one week), 1 year = 12 months = 48 days,
## DAY 0 = 春 4月 第1週. Every label and season is a pure function of the day index.

const Cal := preload("res://scripts/domain/game_calendar.gd")


func test_labels_for_known_days(t, _tree) -> void:
	t.eq(Cal.label(0), "春 4月 第1週", "DAY 0 is the first week of April")
	t.eq(Cal.label(3), "春 4月 第4週", "DAY 3 is the fourth week of April")
	t.eq(Cal.label(4), "春 5月 第1週", "DAY 4 starts May")
	t.eq(Cal.label(47), "春 3月 第4週", "DAY 47 is the last week of the year (March)")
	t.eq(Cal.label(48), "春 4月 第1週", "DAY 48 wraps to the next April")


func test_week_and_month_numbers(t, _tree) -> void:
	t.eq(Cal.week_of_month(0), 1, "week 1")
	t.eq(Cal.week_of_month(5), 2, "DAY 5 is week 2 of May")
	t.eq(Cal.month_of(47), 3, "DAY 47 is March")
	t.eq(Cal.month_of(48), 4, "the year starts again in April")
	t.eq(Cal.year_of(47), 0, "the first 48 days are year 0")
	t.eq(Cal.year_of(48), 1, "DAY 48 starts year 1")


func test_season_for_every_month(t, _tree) -> void:
	# month 4..3 in calendar order, one month = 4 days, so the first day of each month is 4 * index
	var expected := ["春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬", "冬", "冬", "春"]
	for i in 12:
		var day := i * Cal.DEFAULT_DAYS_PER_MONTH
		t.eq(Cal.season_of(day), expected[i], "month index %d (day %d)" % [i, day])
	t.eq(Cal.season_of_month(3), "春", "March is 春")
	t.eq(Cal.season_of_month(5), "春", "May is 春")
	t.eq(Cal.season_of_month(6), "夏", "June is 夏")
	t.eq(Cal.season_of_month(8), "夏", "August is 夏")
	t.eq(Cal.season_of_month(9), "秋", "September is 秋")
	t.eq(Cal.season_of_month(11), "秋", "November is 秋")
	t.eq(Cal.season_of_month(12), "冬", "December is 冬")
	t.eq(Cal.season_of_month(2), "冬", "February is 冬")


func test_days_per_month_from_balance(t, _tree) -> void:
	t.eq(Cal.days_per_month({}), 4, "missing key defaults to 4")
	t.eq(Cal.days_per_month({"days_per_month": 4}), 4, "configured value")
	t.eq(Cal.days_per_month({"days_per_month": 2}), 2, "other values follow the config")
	t.eq(Cal.days_per_year(4), 48, "12 months of 4 days")
	t.eq(Cal.label(2, 2), "春 5月 第1週", "with 2 days per month DAY 2 starts 5月")


func test_no_weekday_in_label(t, _tree) -> void:
	for day in range(0, 96):
		var text := Cal.label(day)
		t.ok(not ("曜" in text), "day %d has no weekday" % day)
