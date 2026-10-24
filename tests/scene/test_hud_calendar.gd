extends RefCounted
## #135: the top bar shows the compressed calendar (1 month = 4 days, DAY 0 = 春 4月 第1週) through the real AppRoot snapshot.
## No weekday anywhere; the season word and icon come from GameCalendar.

const DAY_SECONDS := 86400


func test_top_bar_labels_follow_the_compressed_calendar(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var date := main.find_child("DateLabel", true, false) as Label
	var season := main.find_child("SeasonLabel", true, false) as Label
	var clock := main.find_child("ClockLabel", true, false) as Label
	var cases := [
		[0, "春", "4月 第1週", "春 4月 第1週（1日目）"],
		[3, "春", "4月 第4週", "春 4月 第4週（4日目）"],
		[4, "春", "5月 第1週", "春 5月 第1週（5日目）"],
		[47, "春", "3月 第4週", "春 3月 第4週（48日目）"],
		[48, "春", "4月 第1週", "春 4月 第1週（49日目）"],
	]
	for c in cases:
		var day: int = c[0]
		app.state.day = day
		app.state.time_sec = day * DAY_SECONDS
		app._publish_snapshot()
		t.eq(season.text, c[1], "DAY %d season word" % day)
		t.eq(date.text, c[2], "DAY %d date line" % day)
		t.eq(clock.tooltip_text, c[3], "DAY %d tooltip label" % day)
		t.ok(not clock.tooltip_text.contains("曜"), "DAY %d shows no weekday" % day)
	main.queue_free()
	await tree.process_frame
