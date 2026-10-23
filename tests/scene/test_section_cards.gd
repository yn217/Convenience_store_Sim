extends RefCounted
## Issue #61 (GUI side): inspector sections get the heading style and rules, no node is moved.


func test_inspector_titles_are_styled_and_separated(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var body: Node = main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body")
	var titles := 0
	var rules := 0
	for c in body.get_children():
		if c is Label and c.theme_type_variation == &"SectionTitle":
			titles += 1
		if c is HSeparator:
			rules += 1
	t.ok(titles >= 5, "section titles styled: %d" % titles)
	t.eq(rules, titles - 1, "a rule above every heading except the first")
	t.ok(body.get_node_or_null("MoveButton") != null, "existing node paths untouched")
	main.queue_free()
	await tree.process_frame
