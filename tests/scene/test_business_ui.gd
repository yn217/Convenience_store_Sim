extends RefCounted
## Issue #18: start/close buttons and the next-day advertising selector.


func test_start_needs_a_register_then_opens(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var bc: BusinessController = main.get_node("BusinessController")
	t.ok(bc._start.disabled, "no register: the button is off")
	t.ok(bc._checklist.text.contains("✗ レジが必要です"), "and the checklist says why")
	t.ok(bc._close.disabled, "nothing to close yet")
	var r := bc.start_business()
	t.eq(r.code, &"MISSING_REGISTER")
	t.eq(bc._status.text, CommandMessages.text(&"MISSING_REGISTER", &"missing_register"))
	t.eq(app.state.business_state, GameState.SETUP)
	app.run_command({"command_id": "u1", "kind": &"PLACE_FIXTURE", "type_id": "shelf_onigiri", "x": 4, "y": 5, "rotation": 0})
	app.run_command({"command_id": "u2", "kind": &"PLACE_FIXTURE", "type_id": "register_basic", "x": 8, "y": 5, "rotation": 0})
	app.run_command({"command_id": "u3", "kind": &"ORDER_STOCK", "sku_id": "rice_001", "qty": 5})
	app.run_command({"command_id": "u4", "kind": &"RESTOCK", "instance_id": "fx_0001", "slot_id": "row0", "sku_id": "rice_001", "qty": 5})
	# Pick the 2,000-yen tier through the selector.
	var idx := -1
	for i in bc._ad.item_count:
		if bc._ad.get_item_metadata(i) == 2000:
			idx = i
	bc._ad.select(idx)
	t.ok(bc.set_next_day_ad(2000).ok)
	t.ok(bc._ad_info.text.contains("今日の広告: なし"), "today is not changed by tomorrow's choice")
	t.ok(bc._ad_info.text.contains("¥2,000"))
	t.ok(not bc._start.disabled, "register + reachable stock + cash: ready")
	t.ok(bc._checklist.text.contains("✓ レジあり") and bc._checklist.text.contains("支払えます"))
	t.ok(bc.start_business().ok)
	t.eq(app.state.business_state, GameState.OPEN)
	t.ok(bc._start.disabled)
	t.ok(not bc._close.disabled)
	t.ok(bc._ad_info.text.contains("今日の広告: ¥2,000"))
	t.ok(bc.request_close().ok)
	t.eq(app.state.business_state, GameState.CLOSING)
	t.eq(bc.set_next_day_ad(777).code, &"INVALID_OPERATION")
	t.eq(bc._status.text, CommandMessages.text(&"INVALID_OPERATION", &"ad_tier_invalid"))
	main.queue_free()
	await tree.process_frame


func test_tier_item_text_and_plan_summary(t, _tree) -> void:
	var tiers := [{"yen_per_day": 0, "arrival_multiplier": 1}, {"yen_per_day": 2000, "arrival_multiplier": 1.18}]
	t.eq(BusinessController.tier_item_text(tiers[0]), "明日の広告: なし ×1.00")
	t.eq(BusinessController.tier_item_text(tiers[1]), "明日の広告: ¥2,000 ×1.18")
	var none := BusinessController.plan_summary_text(tiers, 0)
	t.ok(none.contains("プラン: なし"), "no advertising: the plan is named なし")
	t.ok(none.contains("広告費: ¥0"))
	t.ok(none.contains("効果予測: 来店 ×1.00"))
	t.eq(BusinessController.plan_summary_text(tiers, 2000), "プラン: ¥2,000/日\n広告費: ¥2,000\n効果予測: 来店 ×1.18")
	t.ok(BusinessController.plan_summary_text(tiers, 777).contains("来店 ×1.00"), "a tier that is not listed counts as ×1.00")


## #150: the 地図で選ぶ button opens the area map; a site clicked there and confirmed becomes the store's site.
func test_the_site_is_picked_on_the_area_map(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var bc: BusinessController = main.get_node("BusinessController")
	bc.open_map()
	await tree.process_frame
	t.ok(bc._map_window.visible, "the map opens")
	bc.show_map("aoba_town_v1")   # the site facts below are those of the first 青葉市 map
	bc._show_plot("P02")
	t.ok(not bc._map_pick.disabled, "an available site can be picked")
	t.ok(bc._map_info.text.contains("学校前"), bc._map_info.text)
	bc._map_pick.pressed.emit()
	t.eq([app.state.plot_id, app.state.location_id, app.state.facilities], ["P02", "school", ["university", "highway"]], "picked through the button")
	await tree.process_frame
	t.ok(bc._map_pick.disabled, "the current site needs no second pick")
	t.ok(bc._location_info.text.contains("地図："), "the 経営 tab names the site: %s" % bc._location_info.text)
	bc._show_plot("P06")
	t.ok(bc._map_pick.disabled and bc._map_info.text.contains("今後の更新"), "a locked site is shown, not picked")
	main.queue_free()
	await tree.process_frame


## #154: the map window switches between 青葉市 and Kakogawa; a site picked there belongs to that map.
func test_the_map_window_switches_maps(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	var bc: BusinessController = main.get_node("BusinessController")
	bc.open_map()
	await tree.process_frame
	t.eq(bc._map_view.map_id, WorldMap.DEFAULT_MAP, "青葉市 first")
	bc._map_choice.select(1)
	bc._map_choice.item_selected.emit(1)
	t.eq(bc._map_view.map_id, "kakogawa_city_v1", "switched")
	t.ok(bc._map_view._background != null, "drawn on its picture")
	bc._show_plot("P09")
	bc._map_pick.pressed.emit()
	t.eq([app.state.map_id, app.state.plot_id], ["kakogawa_city_v1", "P09"], "the site belongs to the map shown")
	bc.show_map(WorldMap.DEFAULT_MAP)
	t.eq(bc._map_view.current, "", "on 青葉市 the store has no site")
	main.queue_free()
	await tree.process_frame
