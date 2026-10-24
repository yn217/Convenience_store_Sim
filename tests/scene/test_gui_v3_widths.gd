extends RefCounted
## GUI v3 (#112): the top bar's content fits a 1280 px window, and the value pop works on a label that never had its meta.


func test_top_bar_content_fits_a_1280_window(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var row := main.get_node("Layout/TopHUD/Row") as Control
	var needed := row.get_combined_minimum_size().x
	t.ok(needed <= 1280.0, "top bar needs %.0f px, window is 1280" % needed)
	t.ok(main.find_child("SeasonLabel", true, false) is Label, "the season word sits in the top bar")
	t.ok(main.find_child("ProfitLabel", true, false) is Label, "the gross profit value is in the top bar")
	main.queue_free()
	await tree.process_frame


func test_value_pop_without_meta_is_quiet(t, tree) -> void:
	UiFx.reduced = false   # the pop only runs with motion on (another test may have set reduced motion)
	var label := Label.new()
	tree.root.add_child(label)
	await tree.process_frame
	UiFx.pop(label, 1)   # first pop: no tween meta yet
	UiFx.pop(label, -1)  # second pop replaces the first
	t.ok(label.has_meta(UiFx.META_POP), "the pop records its tween")
	label.queue_free()
	await tree.process_frame
