extends RefCounted
## Issue #61 (GUI side) and #105 B5: the bottom summary shows the same numbers as the top HUD.


func test_metric_texts_from_snapshot(t, _tree) -> void:
	var s := {"today": {"revenue_yen": 12345, "gross_profit_yen": 4000}, "visit_stats": {"entered": 3, "purchased": 1}}
	var m := MetricBar.texts(s)
	t.eq(m["sales"], "¥12,345")
	t.eq(m["profit"], "¥4,000")
	t.eq(m["customers"], "3 人", "the day's visits, not the people inside now")
	t.eq(m["unit_price"], "¥12,345", "sales per buyer")
	t.eq(MetricBar.texts({})["sales"], "¥0", "empty snapshot is a real zero")
	t.eq(MetricBar.texts({})["unit_price"], "—", "no buyers, no price")


func test_cards_follow_the_snapshot_on_the_real_scene(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var bar: MetricBar = main.find_child("MetricBar", true, false)
	var metrics: Node = bar.find_child("Metrics", true, false)
	t.eq(metrics.get_child_count(), 4, "four metric cards")
	var app: Node = main.get_node("AppRoot")
	app._publish_snapshot()
	var values: Array = []
	for card in metrics.get_children():
		var labels := card.find_children("*", "Label", true, false)   # title first, value second
		values.append((labels[1] as Label).text)
		t.ok(card.find_child("Icon", true, false) is TextureRect, "every card has an icon")
	t.eq(values[0], "¥0")
	t.eq(values[2], "0 人")
	t.eq(main.get_node("Layout/MainArea/BuildPalette").offset_right - main.get_node("Layout/MainArea/BuildPalette").offset_left, 380.0, "palette is a 380 px floating window")
	main.queue_free()
	await tree.process_frame
