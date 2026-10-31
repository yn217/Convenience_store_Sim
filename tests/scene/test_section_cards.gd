extends RefCounted
## Issue #61 (GUI side): each section is a Card whose content starts with its SectionTitle label. After the
## redesign the selection cards stay in the inspector and the rest sit in the management window tabs.

const TABS := ["商品", "経営", "店員", "データ", "設定"]


func test_sections_are_cards_in_the_right_place(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var body: Node = main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body")
	var loose := 0
	var selection_titles: Array = []
	for c in body.get_children():
		if c is PanelContainer and c.theme_type_variation == &"Card":
			selection_titles.append(_title_of(c))
		else:
			loose += 1
	t.eq(loose, 0, "the inspector body holds only cards")
	t.eq(selection_titles, ["インスペクタ"], "the inspector is one window card: title, fixture block, actions, customer line")
	var tab_cards := 0
	var tabs: Node = main.find_child("ScreenTabs", true, false)
	t.ok(tabs != null, "management window has tabs")
	for tab in TABS:
		var page: Node = tabs.get_node(tab + "/Body")
		for c in page.get_children():
			if c is PanelContainer and c.theme_type_variation == &"Card":
				tab_cards += 1
				var column: Node = c.get_child(0)
				var first: Node = column.get_child(0)
				t.ok(first is Label and first.theme_type_variation == &"SectionTitle", "%s card starts with its section title" % tab)
	t.eq(tab_cards, 15, "fifteen cards are in the management tabs (店員 #144, 販促 #137, 媒体広告 #136, 店頭くじ #138, タイトルへ #172, 売れ筋ランキング #24)")
	t.ok(main.find_child("MoveButton", true, false) != null, "nodes are still reachable by name")
	main.queue_free()
	await tree.process_frame


func _title_of(card: Node) -> String:
	var column: Node = card.get_child(0)
	var first: Node = column.get_child(0)
	if first is HBoxContainer:   # the heading row: a heading icon, the title, the × button
		for n in first.get_children():
			if n is Label:
				return (n as Label).text
	return (first as Label).text
