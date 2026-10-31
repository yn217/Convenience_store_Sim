extends SceneTree
## Times GameState.snapshot() on a busy day: ROWS confirmed sales today and as many yesterday (the walks of the
## rankings, the hourly chart and the per-fixture sums all go over them).
##   Godot --headless --path . --script res://tools/bench_snapshot.gd -- 3000

const Seeds := preload("res://tests/support/test_seeds.gd")


func _init() -> void:
	var rows := 3000
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			rows = int(a)
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var s := GameState.from_balance(balance, Seeds.SEEDS, fx, pr)
	s.ledger.cash_yen = 100000000
	var skus := ["snack_001", "drink_001", "rice_001"]
	for d in [1, 2]:
		s.day = d
		for i in rows:
			s.ledger.record("SALE", "b%d_%d" % [d, i], 150, d, d * 86400 + (i * 17) % 86400,
				{"reservation_id": "r", "sku_id": skus[i % 3], "qty": 1, "fixture_id": "fx_%d" % (i % 12)}, {"revenue": 150, "cogs": 90})
	s.snapshot()   # warm up
	var n := 20
	var t0 := Time.get_ticks_usec()
	for i in n:
		s.snapshot()
	var per := float(Time.get_ticks_usec() - t0) / n / 1000.0
	print("BENCH rows_per_day=%d snapshot_ms=%.2f" % [rows, per])
	var parts := {
		"units_sold_today": func(): s.units_sold_today(), "fixture_sales_today": func(): s.fixture_sales_today(),
		"fixture_money_today": func(): s.fixture_money_today(), "best_sellers x2": func(): s.best_sellers(2); s.best_sellers(1),
		"shelf_ranking x2": func(): s.shelf_ranking(2); s.shelf_ranking(1), "sales_by_hour x2": func(): s.sales_by_hour(2); s.sales_by_hour(1),
		"today_summary": func(): s.today_summary(),
		"Company.views": func(): Company.views(s), "milestone_progress": func(): ProgressionService.milestone_progress(s, 3),
		"event catalog": func(): EventService.catalog(s), "AssistantService": func(): AssistantService.current(s),
		"challenge_progress": func(): ProgressionService.challenge_progress(s), "opening": func(): BusinessService.opening_report(s),
		"daily_reports dup": func(): s.daily_reports.duplicate(true),
	}
	for k in parts:
		var t1 := Time.get_ticks_usec()
		for i in n:
			parts[k].call()
		print("  %s %.2f ms" % [k, float(Time.get_ticks_usec() - t1) / n / 1000.0])
	quit()
