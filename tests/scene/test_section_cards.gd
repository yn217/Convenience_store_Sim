extends RefCounted
## Issue #61 (GUI side): each inspector section is a Card whose content starts with its SectionTitle label.


func test_inspector_sections_are_cards(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var body: Node = main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body")
	var cards := 0
	var loose := 0
	for c in body.get_children():
		if c is PanelContainer and c.theme_type_variation == &"Card":
			cards += 1
			var column: Node = c.get_child(0)
			var first: Node = column.get_child(0)
			t.ok(first is Label and first.theme_type_variation == &"SectionTitle", "card %d starts with its section title" % cards)
		else:
			loose += 1
	t.ok(cards >= 5, "section cards: %d" % cards)
	t.eq(loose, 0, "the inspector body holds only cards")
	t.ok(main.find_child("MoveButton", true, false) != null, "nodes are still reachable by name")
	main.queue_free()
	await tree.process_frame
