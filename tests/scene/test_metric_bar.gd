extends RefCounted
## Issue #61 (GUI side): the bottom metric cards show the same numbers as the top HUD.


func test_metric_texts_from_snapshot(t, _tree) -> void:
	var s := {"today": {"revenue_yen": 12345, "gross_profit_yen": 4000}, "customers": [1, 2, 3], "reputation": 57}
	var m := MetricBar.texts(s)
	t.eq(m["sales"], "¥12,345")
	t.eq(m["profit"], "¥4,000")
	t.eq(m["customers"], "3 人")
	t.eq(m["satisfaction"], "57%")
	t.eq(MetricBar.texts({"reputation": 150})["satisfaction"], "100%", "clamped to 100")
	t.eq(MetricBar.satisfaction_percent(-5), 0, "clamped to 0")
	t.eq(MetricBar.texts({})["sales"], "¥0", "empty snapshot is a real zero")


func test_cards_follow_the_snapshot_on_the_real_scene(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var bar: MetricBar = main.find_child("MetricBar", true, false)
	t.eq(bar.get_child(0).get_child_count(), 4, "four cards")
	var app: Node = main.get_node("AppRoot")
	app._publish_snapshot()
	var values: Array = []
	for card in bar.get_child(0).get_children():
		var labels := card.find_children("*", "Label", true, false)   # title first, value second
		values.append((labels[1] as Label).text)
		t.ok(card.find_child("Icon", true, false) is TextureRect, "every card has an icon")
	t.eq(values[0], "¥0")
	t.eq(values[2], "0 人")
	t.eq(main.get_node("Layout/MainArea/BuildPalette").offset_right - main.get_node("Layout/MainArea/BuildPalette").offset_left, 280.0, "palette is a 280 px floating panel")
	main.queue_free()
	await tree.process_frame
