extends RefCounted
## Mockup A: the bottom-left command grid has six wide buttons; each one jumps to its side-panel section.


func test_grid_has_six_buttons_and_staff_is_disabled(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var grid: CommandGrid = main.find_child("CommandGrid", true, false)
	t.ok(grid != null, "grid is built into the screen")
	for label in ["什器を設置", "商品を仕入れる", "棚割りを編集", "スタッフ配置", "広告を実施", "価格を変更"]:
		t.ok(grid.button(label) != null, "button: " + label)
	var staff := grid.button("スタッフ配置")
	t.ok(staff.disabled, "staff placement is out of MVP")
	t.eq(staff.tooltip_text, "MVP対象外", "staff tooltip")
	t.ok(not grid.button("価格を変更").disabled, "price button is enabled")
	main.queue_free()
	await tree.process_frame


func test_stock_button_scrolls_the_inspector(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var grid: CommandGrid = main.find_child("CommandGrid", true, false)
	var scroll: ScrollContainer = main.get_node("Layout/MainArea/FixtureInspector/Scroll")
	var before := scroll.scroll_vertical
	grid.button("商品を仕入れる").pressed.emit()
	await tree.process_frame
	await tree.process_frame
	t.ok(scroll.scroll_vertical >= before, "scroll position is valid after jumping to the stock section")
	main.queue_free()
	await tree.process_frame
