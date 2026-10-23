extends RefCounted
## Issue #19: the daily report view reads only the closed-day records.


func _report(day: int, revenue: int, profit: int) -> Dictionary:
	return {
		"day_index": day, "revenue_yen": revenue, "cogs_yen": revenue * 2 / 3, "gross_profit_yen": revenue / 3, "wastage_yen": 0,
		"advertising_yen": 0, "electricity_yen": 65, "fixed_cost_yen": 1000, "operating_profit_yen": profit,
		"net_cash_delta_yen": profit, "cash_end_yen": 400000 + profit, "store_reputation": 50, "potential_customers": 10,
		"visitors": 9, "purchasing_customers": 6, "lost_customers": 1, "units_sold": 6,
	}


func test_summary_text_shows_figures_deltas_and_dashes(t, _tree) -> void:
	t.ok(ReportController.summary_text([]).contains("まだ"))
	var one := [_report(0, 900, 500)]
	var text := ReportController.summary_text(one)
	t.ok(text.contains("DAY 0"))
	t.ok(text.contains("¥900"))
	t.ok(text.contains("粗利率 33.3%"))
	t.ok(text.contains("前日比 —"), "no previous day: a dash, not a number")
	var two := [_report(0, 900, 500), _report(1, 600, -200)]
	text = ReportController.summary_text(two)
	t.ok(text.contains("前日比 −¥300"), "revenue went down by 300")
	t.ok(text.contains("前日比 −¥700"), "operating profit went down by 700")
	t.ok(text.contains("設備・仕入は損益に入りません"), "cash and profit are kept apart")
	var zero := [_report(0, 0, -1065)]
	text = ReportController.summary_text(zero)
	t.ok(text.contains("粗利率 —"), "zero revenue: no division")
	t.ok(not text.contains("nan") and not text.contains("inf"))


func test_chart_bars_cover_gains_and_losses(t, _tree) -> void:
	var area := Rect2(0, 0, 70, 100)
	var rects := ReportChart.bar_rects([100, -50, 0], area)
	t.eq(rects.size(), 3)
	# span = 150, zero line at y = 100 * 100/150
	var zero_y := 100.0 * 100.0 / 150.0
	t.ok(absf(rects[0].end.y - zero_y) < 1e-3, "gain stands on the zero line")
	t.ok(absf(rects[1].position.y - zero_y) < 1e-3, "loss hangs from the zero line")
	t.ok(absf(rects[0].size.y - 100.0 * 100.0 / 150.0) < 1e-3)
	t.ok(absf(rects[1].size.y - 100.0 * 50.0 / 150.0) < 1e-3)
	t.eq(rects[2].size.y, 0.0, "a break-even day is a flat bar")
	t.eq(ReportChart.bar_rects([], area).size(), 0)
	t.eq(ReportChart.bar_rects([0, 0], area).size(), 2, "all-zero data does not divide by zero")


func test_panel_updates_when_a_day_closes(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var rc: ReportController = main.get_node("ReportController")
	t.ok(rc._label.text.contains("まだ"))
	app.state.close_day_once(0)
	app.run_command({"command_id": "z", "kind": &"SET_PRICE", "sku_id": "rice_001", "price_yen": 160})   # republishes the snapshot
	t.ok(rc._label.text.contains("DAY 0"))
	t.eq(rc._chart._reports.size(), 1)
	for d in range(1, 10):
		app.state.close_day_once(d)
	app.run_command({"command_id": "z2", "kind": &"SET_PRICE", "sku_id": "rice_001", "price_yen": 170})
	t.eq(rc._chart._reports.size(), 7, "the chart shows the last 7 days")
	t.ok(rc._label.text.contains("DAY 9"))
	main.queue_free()
	await tree.process_frame


## The chart changed from operating profit (green/red) to revenue and gross profit per day, so the
## legend now names 売上 (INFO_CYAN) and 粗利 (SUCCESS_GREEN) instead of 黒字/赤字.
func test_legend_matches_the_bar_colours(t, _tree) -> void:
	var entries := ReportController.legend_entries()
	t.eq(entries.size(), 2)
	t.eq(entries[0]["color"], ReportChart.REVENUE, "revenue dot uses the bar colour")
	t.eq(entries[1]["color"], ReportChart.GROSS, "gross profit dot uses the bar colour")
	t.eq(entries[0]["text"], "売上")
	t.eq(entries[1]["text"], "粗利")
	t.eq(UiTheme.SUCCESS_GREEN, Color("43c67d"))
	t.eq(UiTheme.INFO_CYAN, Color("5caefd"))


func test_grouped_bars_put_revenue_and_gross_side_by_side(t, _tree) -> void:
	var area := Rect2(0, 0, 70, 100)
	var groups := ReportChart.grouped_bar_rects([[300, 0], [100, 0]], area)
	t.eq(groups.size(), 2, "one group per day")
	t.eq(groups[0].size(), 2, "one bar per series")
	t.ok(groups[0][1].position.x > groups[0][0].position.x, "gross profit bar sits right of revenue")
	t.ok(absf(groups[0][0].size.y) > absf(groups[0][1].size.y), "higher value is taller")
	t.eq(groups[1][0].size.y, 0.0, "zero revenue is a flat bar")


func test_axis_uses_nice_steps_and_yen_labels(t, _tree) -> void:
	t.eq(ReportChart.axis_step(0.0), 1.0, "no sales: a small nice step, no division by zero")
	t.eq(ReportChart.axis_step(900.0), 500.0, "900 yen fits in three 500 yen steps")
	t.eq(ReportChart.axis_step(120000.0), 50000.0, "120000 yen fits in three 5万 steps")
	t.eq(ReportChart.axis_label(500), "500円")
	t.eq(ReportChart.axis_label(50000), "5万円")
	t.eq(ReportChart.axis_label(25000), "2.5万円")
	var lines := ReportChart.grid_lines([120000, 0], Rect2(0, 0, 70, 100))
	t.eq(lines.size(), ReportChart.GRID_LINES, "three gridlines")
	t.eq(lines[2]["text"], "15万円")
	t.ok(absf(lines[2]["y"] - 0.0) < 1e-3, "top gridline sits at the top of the area")
