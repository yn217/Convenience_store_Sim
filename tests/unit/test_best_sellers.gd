extends RefCounted
## Issue #24 売れ筋: today's ranking comes from confirmed product sales only, most units first.

const Seeds := preload("res://tests/support/test_seeds.gd")


func _state() -> GameState:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	return GameState.from_balance(balance, Seeds.SEEDS, fx, pr)


func _sale(s: GameState, id: String, sku: String, qty: int, revenue: int) -> void:
	s.ledger.record("SALE", id, revenue, s.day, s.time_sec, {"reservation_id": "r_" + id, "sku_id": sku, "qty": qty, "fixture_id": "fx"}, {"revenue": revenue, "cogs": 0})


func test_ranking_counts_todays_product_sales(t, _tree) -> void:
	var s := _state()
	s.ledger.cash_yen = 100000
	s.day = 0
	_sale(s, "old", "drink_001", 9, 900)   # yesterday does not count
	s.day = 1
	_sale(s, "a", "snack_001", 2, 300)
	_sale(s, "b", "drink_001", 3, 450)
	_sale(s, "c", "snack_001", 1, 150)
	_sale(s, "d", "rice_001", 3, 600)
	s.ledger.record("SALE", "crane:x:1", 100, s.day, s.time_sec, {"fixture_id": "fx", "crane_play": 1, "qty": 1}, {"revenue": 100})
	s.ledger.record("SALE", "kuji:k:1", 700, s.day, s.time_sec, {"lottery_id": "k", "ticket": 1, "tier": "A", "qty": 1}, {"revenue": 700})
	var top := s.best_sellers_today()
	t.eq(top.map(func(e): return e["sku_id"]), ["rice_001", "drink_001", "snack_001"], "most units first; ties by revenue")
	t.eq(top[0]["qty"], 3)
	t.eq(top[0]["revenue_yen"], 600)
	t.eq(top[2]["qty"], 3, "rows of the same sku add up")
	t.eq(top[0]["name"], s.products.get_sku("rice_001")["display_name"])
	t.eq(top.size(), 3, "crane plays and lottery tickets are not products")
	t.ok(s.snapshot().has("best_sellers_today"))


func test_category_line(t, _tree) -> void:
	var sellers := [
		{"category": "drink", "qty": 3}, {"category": "snack", "qty": 2}, {"category": "drink", "qty": 1}, {"category": "rice_ball", "qty": 2},
	]
	t.eq(ReportController.category_line(sellers), "カテゴリ別：飲料 4・おかし 2・おにぎり 2")
	t.eq(ReportController.category_line([]), "")


## #19 売上の推移: the day's SALE revenue per hour of the day (crane plays and tickets are sales too).
func test_sales_by_hour(t, _tree) -> void:
	var s := _state()
	s.ledger.cash_yen = 100000
	s.day = 1
	s.time_sec = 86400 + 9 * 3600 + 120
	_sale(s, "a", "snack_001", 1, 150)
	s.time_sec = 86400 + 9 * 3600 + 3500
	_sale(s, "b", "drink_001", 1, 200)
	s.time_sec = 86400 + 18 * 3600
	s.ledger.record("SALE", "crane:x:1", 100, s.day, s.time_sec, {"crane_play": 1, "qty": 1}, {"revenue": 100})
	s.day = 2
	s.time_sec = 2 * 86400 + 3600
	_sale(s, "c", "snack_001", 1, 150)
	var day1 := s.sales_by_hour(1)
	t.eq(day1.size(), 24)
	t.eq(day1[9], 350, "two sales in the 9 o'clock hour")
	t.eq(day1[18], 100)
	t.eq(day1.reduce(func(a, v): return a + v, 0), 450, "nothing from other days")
	t.eq(s.sales_by_hour(2)[1], 150)
	var hourly: Dictionary = s.snapshot()["hourly_sales"]
	t.eq(hourly["today"][1], 150)
	t.eq(hourly["yesterday"][9], 350)
