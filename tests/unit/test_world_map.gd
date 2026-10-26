extends RefCounted
## Issue #150: the area maps (data/world/maps/) — its data, the site rules (a site sets the
## location and the nearby facilities), the SET_SITE command and the save.

const Run := preload("res://tests/support/basket_run.gd")
## The first, code-drawn 青葉市 (still loadable for older saves): the site rules below are pinned on it.
const V1 := "aoba_town_v1"


func test_map_data_is_consistent(t, _tree) -> void:
	var m := WorldMap.load_map(V1)
	t.eq(m.get("map_id", ""), V1, "the map file loads")
	var cs: Dictionary = m["coordinate_system"]
	var ids := {}
	for q in m["pois"] + m["plots"]:
		t.ok(not ids.has(q["id"]), "unique id " + q["id"])
		ids[q["id"]] = true
		t.ok(float(q["x"]) >= 0 and float(q["x"]) <= float(cs["width"]) and float(q["y"]) >= 0 and float(q["y"]) <= float(cs["height"]), q["id"] + " inside the map")
	t.eq(m["pois"].size(), 20, "twenty facilities")
	var pickable: Array = m["plots"].filter(func(p): return WorldMap.pickable(p)).map(func(p): return p["id"])
	t.eq(pickable, ["P01", "P02", "P03", "P04"], "the four sites of the first release (station, school, office, residential)")
	for fid in WorldMap.FACILITY_OF.values():
		t.ok(not NearbyFacility.find(fid).is_empty(), "facility kind %s exists" % fid)


func test_a_site_brings_its_surroundings(t, _tree) -> void:
	var p02 := WorldMap.site(V1, "P02")
	t.eq(p02["location_id"], "school")
	t.eq(p02["facilities"], ["university", "highway"], "the university and the trunk road are close to the school site")
	var p04 := WorldMap.site(V1, "P04")
	t.eq(p04["location_id"], "residential")
	t.eq(p04["facilities"], ["factory", "hospital"], "logistics centre and hospital near the housing estate")
	t.eq(WorldMap.site(V1, "P03")["facilities"], [], "the office site has no facility close enough")
	t.ok(WorldMap.site(V1, "P05").is_empty(), "a locked site cannot be picked")
	t.ok(WorldMap.site(V1, "R01").is_empty(), "nor the rival's")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	t.ok(WorldMap.forecast_visitors(balance, V1, "P04") > WorldMap.forecast_visitors(balance, V1, "P03"),
		"two facilities add to the forecast")


func test_the_site_is_chosen_on_the_map_before_opening(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	var r := cmds.execute({"command_id": "m1", "kind": &"SET_SITE", "map_id": V1, "plot_id": "P04"})
	t.ok(r.ok, "picked")
	t.eq([s.map_id, s.plot_id, s.location_id, s.facilities], [V1, "P04", "residential", ["factory", "hospital"]], "the site sets location and facilities")
	r = cmds.execute({"command_id": "m2", "kind": &"SET_SITE", "map_id": V1, "plot_id": "P07"})
	t.ok(not r.ok and r.message_key == &"site_unavailable", "a locked site is refused")
	t.eq(s.plot_id, "P04", "and changes nothing")
	var saved := SaveGame.to_dict(s, "map", "2026-10-26T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq([(lr["state"] as GameState).map_id, (lr["state"] as GameState).plot_id], [V1, "P04"], "the site survives a save")
	cmds.execute({"command_id": "m3", "kind": &"SET_LOCATION", "location_id": "office"})
	t.eq(s.plot_id, "", "a location chosen by hand is no longer the map site")
	cmds.execute({"command_id": "m4", "kind": &"SET_SITE", "map_id": V1, "plot_id": "P01"})
	Run.restock(s, cmds, 0)
	cmds.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	SimulationRunner.new(s)._run_step()
	r = cmds.execute({"command_id": "m5", "kind": &"SET_SITE", "map_id": V1, "plot_id": "P02"})
	t.ok(not r.ok and r.message_key == &"site_locked", "fixed once the store has opened")


func test_the_map_view_picks_a_site(t, tree) -> void:
	var view := MapView.new()
	view.size = Vector2(1000, 680)
	tree.root.add_child(view)
	view.set_map(V1)
	var p := WorldMap.plot(V1, "P02")
	var at := view.to_screen(float(p["x"]), float(p["y"]))
	t.eq(view.plot_at(at), "P02", "a click on the site hits it")
	t.eq(view.plot_at(at + Vector2(60, 60)), "", "a click beside it does not")
	var got: Array = []
	view.plot_clicked.connect(func(id): got.append(id))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	view._gui_input(ev)
	var release := ev.duplicate()
	release.pressed = false
	view._gui_input(release)
	t.eq(got, ["P02"], "the click (press and release in place) is reported")
	var text := BusinessController.plot_text(V1, "P02")
	t.ok(text.contains("学校前") and text.contains("みどり大学") and text.contains("予想来店数"), "the panel explains the site: %s" % text)
	view.queue_free()


## Phase 2: the forecast by hour adds up to the day's forecast and follows the site's people.
func test_the_forecast_by_hour(t, _tree) -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	for id in ["P01", "P02", "P03", "P04"]:
		var h := WorldMap.forecast_by_hour(balance, V1, id)
		var sum: float = h.reduce(func(a, x): return a + x, 0.0)
		t.ok(absf(sum - float(WorldMap.forecast_visitors(balance, V1, id))) <= 1.0, "%s: the hours add up to the day (%.1f)" % [id, sum])
	var office := WorldMap.forecast_by_hour(balance, V1, "P03")
	t.ok(office[12] > office[3] * 3.0, "the office site peaks at lunch, not at night")
	var school := WorldMap.forecast_by_hour(balance, V1, "P02")
	var school_only := WorldMap.forecast_by_hour(balance, V1, "P03")
	t.ok(school[22] > school_only[22], "the university near the school site brings people late in the evening")
	t.eq(WorldMap.forecast_by_hour(balance, V1, "P06").max(), 0.0, "a locked site has no forecast")
	var text := BusinessController.peak_hours_text(office)
	t.ok(text.contains("12時"), "the busiest hours are named: %s" % text)


## Phase 2: wheel zoom keeps the point under the cursor, a drag pans without picking a site, the view resets.
func test_the_map_zooms_and_pans(t, tree) -> void:
	var view := MapView.new()
	view.size = Vector2(1000, 680)
	tree.root.add_child(view)
	view.set_map(V1)
	var p := WorldMap.plot(V1, "P03")
	var before := view.to_screen(float(p["x"]), float(p["y"]))
	view.zoom_at(before, 2.0)
	t.eq(view.zoom, 2.0, "zoomed in")
	t.ok(view.to_screen(float(p["x"]), float(p["y"])).distance_to(before) < 0.01, "the site under the cursor stays put")
	view.zoom_at(before, 10.0)
	t.eq(view.zoom, MapView.ZOOM_MAX, "at most %.1fx" % MapView.ZOOM_MAX)
	var got: Array = []
	view.plot_clicked.connect(func(id): got.append(id))
	var at := view.to_screen(float(p["x"]), float(p["y"]))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	view._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.position = at + Vector2(40, 10)
	move.relative = Vector2(40, 10)
	view._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at + Vector2(40, 10)
	view._gui_input(up)
	t.eq(got, [], "a drag does not pick the site")
	t.ok(view.to_screen(float(p["x"]), float(p["y"])).distance_to(at + Vector2(40, 10)) < 0.01, "it moves the map with the pointer")
	view.reset_view()
	t.eq([view.zoom, view.pan], [1.0, Vector2.ZERO], "全体表示 resets the view")
	view.set_forecast_hour(12, JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json")))
	t.eq(view._forecast.size(), 4, "the forecast layer covers the four sites")
	view.queue_free()


## Phase 2: the actual visitors per hour are counted beside the forecast, kept for yesterday and saved; the map
## panel puts them side by side per time band.
func test_actual_visitors_beside_the_forecast(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	cmds.execute({"command_id": "m1", "kind": &"SET_SITE", "map_id": V1, "plot_id": "P03"})
	Run.run_days(s, cmds, 1)
	var y: Array = s.visitors_by_hour_yesterday
	t.eq(y.size(), 24, "yesterday's visitors by hour are kept")
	var total: int = y.reduce(func(a, x): return a + int(x), 0)
	t.ok(total > 20, "people came (%d)" % total)
	t.ok(int(y[11]) + int(y[12]) + int(y[13]) > int(y[1]) + int(y[2]) + int(y[3]), "the office site is busy at lunch, quiet at night: %s" % str(y))
	var saved := SaveGame.to_dict(s, "act", "2026-10-26T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).visitors_by_hour_yesterday, y, "and survive a save")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var text := BusinessController.actual_vs_forecast_text(WorldMap.forecast_by_hour(balance, V1, "P03"), [], y)
	t.ok(text.contains("昼 10-14時") and text.contains("目安"), text)
	var lunch := "%d" % (int(y[10]) + int(y[11]) + int(y[12]) + int(y[13]))
	t.ok(text.contains("／－／" + lunch), "today unknown, yesterday's lunch count shown: %s" % text)


## #154: the Kakogawa concept map (user package 2026-10-26) beside 青葉市: picture background, image-pixel
## coordinates, all nine sites pickable, the standard store for sites without a location profile.
func test_the_kakogawa_map(t, _tree) -> void:
	var id := "kakogawa_city_v1"
	t.ok(WorldMap.MAPS.has(id), "listed")
	t.eq(WorldMap.map_size(id), Vector2(1672, 940), "image pixels")
	t.ok(load(WorldMap.BACKGROUND[id]) is Texture2D, "the background picture loads")
	var m := WorldMap.load_map(id)
	t.eq(m["pois"].size(), 20, "twenty facilities")
	var ids: Array = m["plots"].filter(func(p): return WorldMap.pickable(p)).map(func(p): return p["id"])
	t.eq(ids, ["P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09"], "all nine sites can be picked")
	for p in m["pois"] + m["plots"]:
		t.ok(float(p["x"]) >= 0 and float(p["x"]) <= 1672 and float(p["y"]) >= 0 and float(p["y"]) <= 940, p["id"] + " inside the picture")
	t.eq(WorldMap.site(id, "P01")["location_id"], "station", "加古川駅前 is a station site")
	var factory := WorldMap.site(id, "P06")
	t.eq(factory["location_id"], "", "物流工場前 opens as the standard store")
	t.eq(factory["facilities"][0], "factory", "with the logistics area as its first facility")
	t.eq(WorldMap.site(id, "P09")["facilities"][0], "highway", "a roadside site always has the trunk road")
	t.ok(BusinessController.plot_text(id, "P06").contains("物流・工場"), BusinessController.plot_text(id, "P06"))
	var s := Run.new_state(100.0)
	var cmds := Run.place_layout(s)
	t.ok(cmds.execute({"command_id": "k1", "kind": &"SET_SITE", "map_id": id, "plot_id": "P06"}).ok, "picked on Kakogawa")
	var saved := SaveGame.to_dict(s, "kako", "2026-10-26T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq([(lr["state"] as GameState).map_id, (lr["state"] as GameState).plot_id, (lr["state"] as GameState).facilities], [id, "P06", s.facilities], "and saved")


## The maps of the user package ui_free_map_bundle.zip: positions re-measured on the pictures, so every site sits on
## a red pin drawn in the picture; names and pins are baked in (the view draws only the clickable sites).
func test_the_picture_maps_match_their_pins(t, _tree) -> void:
	t.eq(WorldMap.DEFAULT_MAP, "aoba_city_central_district_v2", "the remade 青葉市 is the default map")
	for id in ["aoba_city_central_district_v2", "kobe_akashi_awaji_region_v2"]:
		var m := WorldMap.load_map(id)
		t.ok(WorldMap.MAPS.has(id) and bool(m.get("labels_baked", false)), id + ": listed, labels in the picture")
		var img := Image.load_from_file(ProjectSettings.globalize_path(WorldMap.BACKGROUND[id]))
		t.eq(Vector2(img.get_width(), img.get_height()), WorldMap.map_size(id), id + ": coordinates in picture pixels")
		var ids := {}
		for q in m["pois"] + m["plots"]:
			t.ok(not ids.has(q["id"]), "unique " + q["id"])
			ids[q["id"]] = true
		for p in m["plots"]:
			t.ok(WorldMap.pickable(p), "%s %s can be picked" % [id, p["id"]])
			var red := false
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					var c := img.get_pixel(int(p["x"]) + dx, int(p["y"]) + dy)
					red = red or (c.r > 0.78 and c.g < 0.3 and c.b < 0.35)
			t.ok(red, "%s %s sits on the red pin of the picture" % [id, p["id"]])
	var aoba := "aoba_city_central_district_v2"
	t.eq(WorldMap.site(aoba, "P05")["location_id"], "school", "学園周辺 is a school site")
	t.ok((WorldMap.site(aoba, "P05")["facilities"] as Array).has("university"), "with みどり大学 close by")
	t.eq(WorldMap.site(aoba, "P01")["location_id"], "station")
	var kobe := "kobe_akashi_awaji_region_v2"
	t.eq(WorldMap.site(kobe, "P03")["location_id"], "office", "三宮中心街 is an office site")
	t.eq(WorldMap.site(kobe, "P08")["facilities"][0], "highway", "淡路SA is on the expressway")
	t.eq(WorldMap.site(kobe, "P07")["location_id"], "", "淡路夢舞台 opens as the standard store")
	t.eq(WorldMap.plot(kobe, "P10"), {}, "the unnumbered pin at Iwaya is not a site")
