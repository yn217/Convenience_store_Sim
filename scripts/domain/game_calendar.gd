class_name GameCalendar
extends RefCounted
## In-game calendar (#135): 1 month = days_per_month game days (default 4), and each game day stands for one week
## (第1週..第4週). 1 year = 12 months = 48 days; DAY 0 = 春 4月 第1週. Months run in calendar order from April.
## Pure: every value is derived from the day index, so nothing is stored and old saves show the right label.
## Economy, expiry, ads and daily reports stay per game day; only display and season decisions use this helper.

const DEFAULT_DAYS_PER_MONTH := 4
const MONTHS := [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]   # month number for each month of the year, DAY 0 first


## days_per_month from a balance dictionary; 4 when the key is missing.
static func days_per_month(balance: Dictionary = {}) -> int:
	return maxi(1, int(balance.get("days_per_month", DEFAULT_DAYS_PER_MONTH)))


static func days_per_year(dpm: int = DEFAULT_DAYS_PER_MONTH) -> int:
	return MONTHS.size() * dpm


## 0-based year count from DAY 0 (the first 48 days are year 0 with the default calendar).
static func year_of(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> int:
	return floori(float(day) / float(days_per_year(dpm)))


## Month position inside the year, 0 = 4月 ... 11 = 3月.
static func month_index_of(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> int:
	return posmod(day, days_per_year(dpm)) / dpm


## Calendar month number (1..12) of a game day.
static func month_of(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> int:
	return MONTHS[month_index_of(day, dpm)]


## Week of the month, 1..days_per_month. One game day is one week.
static func week_of_month(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> int:
	return posmod(day, dpm) + 1


## Season word for a calendar month: 春 3-5, 夏 6-8, 秋 9-11, 冬 12-2.
static func season_of_month(month: int) -> String:
	if month >= 3 and month <= 5:
		return "春"
	if month >= 6 and month <= 8:
		return "夏"
	if month >= 9 and month <= 11:
		return "秋"
	return "冬"


static func season_of(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> String:
	return season_of_month(month_of(day, dpm))


## Month and week without the season, e.g. "4月 第1週".
static func month_week_text(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> String:
	return "%d月 第%d週" % [month_of(day, dpm), week_of_month(day, dpm)]


## Full calendar label, e.g. "春 4月 第1週" for DAY 0.
static func label(day: int, dpm: int = DEFAULT_DAYS_PER_MONTH) -> String:
	return "%s %s" % [season_of(day, dpm), month_week_text(day, dpm)]
