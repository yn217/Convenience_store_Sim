extends RefCounted
## #105 B5: the bottom summary's pure helpers: 客単価 (sales / buyers), goal progress, the next goal and the
## event timeline rows.

const Summary := preload("res://scripts/presentation/metric_bar.gd")
const Progression := preload("res://scripts/presentation/progression_text.gd")
const Events := preload("res://scripts/presentation/event_text.gd")


func test_customer_unit_price_is_sales_per_buyer(t, _tree) -> void:
	t.eq(Summary.unit_price(156320, 42), 3721, "sales divided by buyers, rounded down")
	t.eq(Summary.unit_price(0, 5), 0, "no sales is a zero price")
	t.eq(Summary.unit_price(1000, 0), 0, "no buyers gives no price (shown as a dash)")
	t.eq(Summary.unit_price(1000, -3), 0, "negative buyers never divide")


func test_unit_price_text_is_a_dash_without_purchases(t, _tree) -> void:
	var none := {"today": {"revenue_yen": 0, "gross_profit_yen": 0}, "visit_stats": {"entered": 4, "purchased": 0}}
	t.eq(Summary.texts(none)["unit_price"], "—", "dash with no purchases")
	var some := {"today": {"revenue_yen": 3000, "gross_profit_yen": 900}, "visit_stats": {"entered": 4, "purchased": 2}}
	t.eq(Summary.texts(some)["unit_price"], "¥1,500", "price with purchases")
	t.eq(Summary.texts(some)["customers"], "4 人", "customers are the day's visits")


func test_visitors_and_buyers_default_to_zero(t, _tree) -> void:
	t.eq(Summary.visitors({}), 0, "no visit stats")
	t.eq(Summary.purchased({"visit_stats": {"entered": 3}}), 0, "no purchased count")


func test_goal_progress_is_clamped(t, _tree) -> void:
	t.eq(Summary.goal_progress(50, 200), 0.25, "a quarter of the way")
	t.eq(Summary.goal_progress(300, 200), 1.0, "over the target is done")
	t.eq(Summary.goal_progress(-5, 200), 0.0, "never below zero")
	t.eq(Summary.goal_progress(0, 0), 1.0, "a goal with no target is met")


func test_goal_percent_rounds(t, _tree) -> void:
	t.eq(Summary.goal_percent(156, 200), 78, "78 percent")
	t.eq(Summary.goal_percent(1, 3), 33, "rounded")
	t.eq(Summary.goal_percent(999, 200), 100, "capped at 100")


func test_next_goal_is_the_first_unfinished_milestone(t, _tree) -> void:
	var progress := [
		{"milestone_id": "ms_a", "done": true, "threshold": 1},
		{"milestone_id": "ms_b", "done": false, "threshold": 10},
		{"milestone_id": "ms_c", "done": false, "threshold": 50},
	]
	t.eq(Summary.next_goal(progress)["milestone_id"], "ms_b", "skips the done one")
	t.ok(Summary.next_goal([{"done": true}]).is_empty(), "nothing left: empty")
	t.ok(Summary.next_goal([]).is_empty(), "no milestones: empty")


func test_goal_text_names_the_target(t, _tree) -> void:
	t.eq(Progression.goal_text("total_sales_count", 10), "累計 10 件の会計を達成しよう", "sales count goal")
	t.eq(Progression.goal_text("total_revenue_yen", 10000), "累計売上 ¥10,000 にしよう", "revenue goal")
	t.eq(Progression.goal_text("no_such_metric", 1), "", "unknown metric has no text")


func test_timeline_for_a_scheduled_event(t, _tree) -> void:
	var view := {
		"status": "scheduled", "name_ja": "週末セール", "description_ja": "お昼の来店が増えます",
		"start_sec": 12 * 3600, "end_sec": 14 * 3600, "traffic": 1.2, "categories": {},
	}
	var rows := Events.timeline(view, 9 * 3600, [])
	t.eq(rows.size(), 3, "three rows")
	t.eq(rows[0]["time"], "12:00", "starts at 12:00")
	t.ok(String(rows[0]["text"]).contains("週末セール"), "names the event")
	t.eq(rows[1]["text"], "お昼の来店が増えます", "description line")
	t.eq(rows[2]["time"], "14:00", "ends at 14:00")


func test_timeline_without_an_event_is_one_plain_line(t, _tree) -> void:
	var rows := Events.timeline({"status": "none", "day": 3}, 9 * 3600, [])
	t.eq(rows.size(), 1, "one row")
	t.eq(rows[0]["time"], "", "no time")
	t.eq(rows[0]["text"], "今日の特別なイベントはありません", "the usual sentence")
