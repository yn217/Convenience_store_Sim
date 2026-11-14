extends RefCounted
## The day's grade and the change from the day before on the result screen (DayEndScreen, 2026-11-14).


func _r(rev: int, op: int) -> Dictionary:
	return {"revenue_yen": rev, "operating_profit_yen": op}


func test_the_grade_follows_the_day(t, _tree) -> void:
	t.eq(DayEndScreen.grade(_r(1000, 100), [_r(1000, 100)]), "A", "the first day in profit")
	t.eq(DayEndScreen.grade(_r(1000, -5), [_r(1000, -5)]), "C", "a loss")
	t.eq(DayEndScreen.grade(_r(3000, 10), [_r(1000, 1), _r(2000, 1), _r(3000, 10)]), "S", "the best day so far")
	t.eq(DayEndScreen.grade(_r(1600, 10), [_r(1000, 1), _r(2000, 1), _r(1600, 10)]), "A", "at least the average")
	t.eq(DayEndScreen.grade(_r(1200, 10), [_r(1000, 1), _r(2000, 1), _r(1200, 10)]), "B", "below the average, in profit")


func test_the_change_from_the_day_before(t, _tree) -> void:
	t.eq(DayEndScreen.delta_text(1500, 1000, true), "前日比 +¥500")
	t.eq(DayEndScreen.delta_text(8, 10, false), "前日比 −2人")
	t.eq(DayEndScreen.delta_text(5, null, true), "初日")
