extends RefCounted
## 店先の飾り in the real game screen (DecorPanel in the 販促 card): 置く buys a decoration, 片付ける takes it away, and
## the store's street side draws it.


func test_the_panel_buys_and_removes_a_decoration(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: AppRoot = main.get_node("AppRoot")
	app._publish_snapshot()
	await tree.process_frame
	var buy := main.find_child("BuyDecor_cherry_tree", true, false) as Button
	t.ok(buy != null, "the decoration is offered")
	var panel := main.find_child("DecorPanel", true, false)
	t.ok(panel != null and String((panel.get_child(0) as Label).text).contains("見た目だけ"), "the panel says it is looks only")
	buy.pressed.emit()
	t.eq(app.state.decor, ["cherry_tree"], "置く buys it")
	app._publish_snapshot()
	await tree.process_frame
	var front := main.find_child("FrontDecor", true, false) as StoreDecor
	t.eq(front.decor, ["cherry_tree"], "the street side draws it")
	var remove := main.find_child("RemoveDecor_cherry_tree", true, false) as Button
	t.ok(remove != null, "片付ける once bought")
	remove.pressed.emit()
	t.eq(app.state.decor, [], "片付ける takes it away")
	main.queue_free()
	await tree.process_frame
