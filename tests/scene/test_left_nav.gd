extends RefCounted
## UI redesign Phase 1: the left rail is a slim icon strip (icon over a short label). Each entry emits its id;
## 店舗 / 商品 / 経営 / データ / 設定 are the only entries (スタッフ is not in the rail).


func test_rail_entries_are_short_and_ordered(t, tree) -> void:
	var nav := LeftNav.new()
	tree.root.add_child(nav)
	await tree.process_frame
	t.eq(nav.entry_count(), 6, "six entries")
	var titles: Array = []
	for i in nav.entry_count():
		titles.append(nav.entry_title(i))
	t.eq(titles, ["店舗", "商品", "発注", "経営", "データ", "設定"], "entry labels in order (no スタッフ)")
	t.eq(nav.custom_minimum_size.x, 72.0, "rail is 72 px wide")
	nav.free()


func test_each_entry_emits_its_id(t, tree) -> void:
	var nav := LeftNav.new()
	tree.root.add_child(nav)
	await tree.process_frame
	var got: Array = []
	nav.item_pressed.connect(func(id): got.append(id))
	nav.entry_button(0).pressed.emit()
	nav.entry_button(2).pressed.emit()
	nav.entry_button(4).pressed.emit()
	t.eq(got, ["store", "order", "data"], "pressing an entry emits its id")
	nav.free()


func test_set_active_marks_one_entry(t, tree) -> void:
	var nav := LeftNav.new()
	tree.root.add_child(nav)
	await tree.process_frame
	nav.set_active("management")
	t.eq(nav.active_id, "management", "active id follows set_active")
	nav.set_active("")
	t.eq(nav.active_id, "", "clearing the mark")
	nav.free()


func test_real_scene_has_the_rail(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var nav := main.get_node("Layout/MainArea/LeftNav") as LeftNav
	t.ok(nav != null, "rail is in the main area")
	t.eq(nav.entry_count(), 6, "six entries in the real scene")
	main.queue_free()
	await tree.process_frame
