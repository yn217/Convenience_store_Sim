extends RefCounted
## UiMode transitions (UI redesign Phase 1): NORMAL, BUILD, SELECTED, SCREEN and the events between them.


func test_starts_in_normal(t, _tree) -> void:
	var m := UiMode.new()
	t.eq(m.mode, UiMode.Mode.NORMAL, "normal at start")
	t.eq(m.mode_name(), "NORMAL", "name")


func test_build_opens_and_closes(t, _tree) -> void:
	var m := UiMode.new()
	m.open_build()
	t.ok(m.is_build(), "店舗 / B enters build")
	m.close()
	t.eq(m.mode, UiMode.Mode.NORMAL, "Esc / close returns to normal")


func test_build_wins_over_selection(t, _tree) -> void:
	var m := UiMode.new()
	m.open_build()
	m.select_fixture()
	t.ok(m.is_build(), "clicking a fixture while building keeps build mode")
	m.select_customer()
	t.ok(m.is_build(), "clicking a customer while building keeps build mode")
	m.deselect()
	t.ok(m.is_build(), "deselect does not leave build mode")


func test_selection_opens_and_deselects(t, _tree) -> void:
	var m := UiMode.new()
	m.select_fixture()
	t.ok(m.is_selected(), "fixture selection opens SELECTED")
	m.deselect()
	t.eq(m.mode, UiMode.Mode.NORMAL, "empty floor click returns to normal")
	m.select_customer()
	m.close()
	t.eq(m.mode, UiMode.Mode.NORMAL, "Esc deselects")


func test_build_from_selected_replaces_the_inspector(t, _tree) -> void:
	var m := UiMode.new()
	m.select_fixture()
	m.open_build()
	t.ok(m.is_build(), "B from SELECTED goes to build")


func test_screen_returns_to_previous_mode(t, _tree) -> void:
	var m := UiMode.new()
	m.open_screen("商品")
	t.ok(m.is_screen(), "tab opens the screen")
	t.eq(m.screen_tab, "商品", "tab remembered")
	m.close_screen()
	t.eq(m.mode, UiMode.Mode.NORMAL, "closing returns to normal")
	t.eq(m.screen_tab, "", "no tab when closed")
	m.select_fixture()
	m.open_screen("経営")
	m.close()
	t.ok(m.is_selected(), "closing a screen opened from SELECTED returns to SELECTED")
	m.open_screen("データ")
	m.open_screen("設定")
	t.eq(m.screen_tab, "設定", "switching tabs keeps the screen open")
	t.ok(m.is_screen(), "still in screen mode after a tab switch")
	m.close_screen()
	t.ok(m.is_selected(), "tab switches do not change the return mode")


func test_screen_blocks_build_and_selection(t, _tree) -> void:
	var m := UiMode.new()
	m.open_screen("商品")
	m.open_build()
	m.select_fixture()
	t.ok(m.is_screen(), "build and selection do not open over the screen")
