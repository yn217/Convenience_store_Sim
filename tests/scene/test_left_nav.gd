extends RefCounted
## Mockup A left rail: wide entries with title and subtitle, disabled スタッフ, selection follows the last press,
## and the compact strip below COMPACT_WIDTH.


func _nav() -> LeftNav:
	return LeftNav.new()


func test_entries_have_title_and_subtitle(t, tree) -> void:
	var nav := _nav()
	tree.root.add_child(nav)
	t.eq(nav.entry_count(), 6, "six entries")
	t.eq(nav.entry_title(0), "店舗")
	t.eq(nav.entry_subtitle(0), "レイアウト・設備")
	t.eq(nav.entry_title(1), "商品")
	t.eq(nav.entry_subtitle(1), "発注・在庫・棚割")
	t.eq(nav.entry_title(2), "スタッフ")
	t.eq(nav.entry_subtitle(2), "シフト・教育")
	t.eq(nav.entry_title(3), "営業")
	t.eq(nav.entry_subtitle(3), "広告・イベント")
	t.eq(nav.entry_title(4), "データ")
	t.eq(nav.entry_subtitle(4), "売上・顧客分析")
	t.eq(nav.entry_title(5), "設定")
	t.eq(nav.entry_subtitle(5), "店舗設定・その他")
	t.eq(nav.custom_minimum_size.x, 200.0, "wide rail is 200 px")
	t.ok(nav.entry_button(0).get_child(0) is VBoxContainer, "inner column holds the labels")
	nav.free()


func test_staff_is_disabled_with_tooltip(t, tree) -> void:
	var nav := _nav()
	tree.root.add_child(nav)
	var staff := nav.entry_button(2)
	t.ok(staff.disabled, "スタッフ is disabled")
	t.eq(staff.tooltip_text, "MVP対象外")
	t.ok(not nav.entry_button(0).disabled, "店舗 is enabled")
	nav.free()


func test_selection_follows_last_press(t, tree) -> void:
	var nav := _nav()
	tree.root.add_child(nav)
	t.eq(nav.selected_index, 0, "店舗 selected at start")
	var before := nav.entry_button(0).get_theme_stylebox("normal") as StyleBoxFlat
	t.eq(before.border_width_left, nav.BAR_WIDTH, "selected entry has the warm bar")
	nav.entry_button(3).pressed.emit()
	t.eq(nav.selected_index, 3, "営業 selected after press")
	var on := nav.entry_button(3).get_theme_stylebox("normal") as StyleBoxFlat
	var off := nav.entry_button(0).get_theme_stylebox("normal") as StyleBoxFlat
	t.eq(on.border_width_left, nav.BAR_WIDTH, "pressed entry gets the bar")
	t.eq(off.border_width_left, 1, "previous entry loses the bar")
	t.ok(on.bg_color.r > off.bg_color.r or on.bg_color.g > off.bg_color.g, "selected fill is brighter")
	nav.free()


func test_compact_shrinks_and_hides_subtitles(t, tree) -> void:
	var nav := _nav()
	tree.root.add_child(nav)
	nav.set_compact(true)
	t.eq(nav.custom_minimum_size.x, 72.0, "compact rail is 72 px")
	t.ok(nav.is_compact(), "reports compact")
	t.ok(not nav.entry_button(0).get_child(0).get_child(1).visible, "subtitle hidden when compact")
	nav.set_compact(false)
	t.eq(nav.custom_minimum_size.x, 200.0, "back to 200 px")
	t.ok(not nav.is_compact(), "reports wide")
	t.ok(nav.entry_button(0).get_child(0).get_child(1).visible, "subtitle shown when wide")
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
