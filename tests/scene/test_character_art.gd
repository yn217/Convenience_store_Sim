extends RefCounted
## ComfyUI character art in the game (2026-10-31): 小春六花's poses, the title figure, portraits in the customer panel
## (#141) and the staff tab (#144), and her worried line when the store stops for unpaid costs.


func _boot(tree) -> Node:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return main


func test_art_is_at_the_game_size(t, _tree) -> void:
	for k in ProgressionController.FIGURES:
		var tex := load(ProgressionController.FIGURES[k]) as Texture2D
		t.ok(tex != null, "%s figure loads" % k)
		t.eq(Vector2(tex.get_size()), ProgressionController.FIGURE_SIZE * 1.5, "%s: 1.5x its 300x436 slot" % k)
	for id in Array(CustomerSprites.VARIANTS).map(func(v): return String(v).trim_prefix(CustomerSprites.CHIBI)) + Array(Portraits.STAFF):
		var p := Portraits.texture(id)
		t.ok(p != null and p.get_size() == Vector2(144, 144), "%s portrait: 144 px for a 96 px slot" % id)
	t.ok(load(TitleScreen.TITLE_RIKKA) is Texture2D)


func test_portrait_choice_is_stable(t, _tree) -> void:
	t.eq(Portraits.id_for_customer("cust_000004"), CustomerSprites.variant_for("cust_000004").trim_prefix(CustomerSprites.CHIBI), "a customer's face is its in-store look")
	t.eq(Portraits.id_for_staff("佐藤"), Portraits.id_for_staff("佐藤"), "the same name, the same face")
	t.ok(Portraits.STAFF.has(Portraits.id_for_staff("木村")))
	t.eq(Portraits.id_for_customer("staff_1", "佐藤"), Portraits.id_for_staff("佐藤"), "staff on the floor keep their face")
	var seen := {}
	for n in ["佐藤", "鈴木", "高橋", "田中", "伊藤", "渡辺", "山本", "中村", "小林", "加藤"]:
		seen[Portraits.id_for_staff(n)] = true
	t.ok(seen.size() >= 3, "names spread over the faces: %s" % [seen.keys()])


func test_story_poses_and_the_payment_stop(t, tree) -> void:
	var main: Node = await _boot(tree)
	var app: Node = main.get_node("AppRoot")
	var pc: ProgressionController = main.get_node("ProgressionController")
	var stage: Control = main.get_node("AssistantStage")
	t.eq(pc.mood(), "welcome", "her first greeting: the welcome pose")
	t.eq(ProgressionController.story_mood("story_register"), "point", "later story lines: explaining")
	app.state.business_state = GameState.PAYMENT_BLOCKED
	app.state.unpaid_cost_yen = 1000
	app._publish_snapshot()
	t.ok(stage.visible and pc._assistant.text == ProgressionController.BLOCKED_LINE, "the store stopped: she says so")
	t.eq(pc.mood(), "worried")
	(stage.find_child("AssistantDismiss", true, false) as Button).pressed.emit()
	t.ok(pc._assistant.text != ProgressionController.BLOCKED_LINE, "閉じる puts it away")
	t.eq(pc._snap["story_cue"], "story_start", "without dismissing her story line")
	main.queue_free()
	await tree.process_frame


func test_staff_tab_and_customer_panel_faces(t, tree) -> void:
	var main: Node = await _boot(tree)
	var app: Node = main.get_node("AppRoot")
	app._publish_snapshot()
	await tree.process_frame
	var card := main.find_child("CandidateCards", true, false) as Control
	var face := card.find_child("Face", true, false) as TextureRect
	t.ok(face != null and face.texture != null, "a candidate card shows a face")
	var oc: Node = main.get_node("OverlayController")
	var world := main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	world.customers = [{"customer_id": "cust_000002", "phase": "BROWSE", "tile": Vector2i(3, 3)}]
	world.selected_customer = "cust_000002"
	oc.refresh_customer()
	t.ok(oc._customer_face.visible, "the selected customer's face shows beside the panel")
	t.eq(oc._customer_face.texture, Portraits.texture(Portraits.id_for_customer("cust_000002")))
	world.selected_customer = ""
	oc.refresh_customer()
	t.ok(not oc._customer_face.visible)
	main.queue_free()
	await tree.process_frame


func test_title_has_her(t, tree) -> void:
	var title: TitleScreen = load("res://scenes/title/Title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	var r := title.get_node_or_null("TitleRikka") as TextureRect
	var background := title.get_node("TitleBackground") as TextureRect
	if TitleScreen.pilot_title_texture() != null:
		t.ok(r == null, "approved title background owns the character without a duplicate overlay")
		t.ok(background.texture != null, "approved title background is visible")
	else:
		t.ok(r != null and r.texture != null, "she greets on the title screen")
		if r != null:
			t.ok(r.get_global_rect().end.x > tree.root.get_visible_rect().size.x * 0.6, "at the right, clear of the menu")
	title.queue_free()
	await tree.process_frame


func test_title_pilot_candidate_does_not_need_a_second_figure(t, _tree) -> void:
	var pilot := TitleScreen.pilot_title_texture("painted_v1")
	t.ok(pilot != null, "the title pilot candidate loads for the explicit QA override")
	if pilot != null:
		t.ok(not pilot.resource_path.is_empty(), "the title pilot has a concrete runtime texture")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/character_visuals_v1.json"))
	var entry: Dictionary = (data.get("assets", []) as Array).filter(func(raw): return raw.get("id", "") == "title_background_pilot")[0]
	t.eq(entry.get("status", ""), "runtime_approved", "title pilot is approved for normal runtime")
	t.eq(entry.get("fallback", ""), "existing_title_background", "held title pilot keeps the daytime fallback")
	t.ok(String(entry.get("source_path", "")).contains("title_screen_bright_sakura_1664x936.png"), "title pilot uses the bright sakura residential-store candidate")
	t.ok(TitleScreen.title_entry_allowed({"runtime_approved": true}, false), "approved title pilot is allowed in a normal build")
	t.ok(not TitleScreen.title_entry_allowed({"runtime_approved": false}, false), "held title pilot stays on the fallback in a normal build")
	t.ok(TitleScreen.title_entry_allowed({"runtime_approved": false}, true, "painted_v1"), "debug title override can inspect a held candidate")


## #104 / #134: six chibi looks, a walk cycle with stride poses (the feet move), and a seated eating pose at the eat-in.
func test_chibi_looks_walk_and_eat(t, _tree) -> void:
	t.eq(CustomerSprites.VARIANTS.size(), 10, "ten looks for the customers")
	t.eq(CustomerSprites.anim_for_state("EAT", false, false), "eat", "seated while eating")
	t.eq(CustomerSprites.anim_for_state("EAT", true, false), "walk", "still walks while moving")
	var sprites := CustomerSprites.new()
	for vid in Array(CustomerSprites.VARIANTS) + [CustomerSprites.CLERK]:
		var sheet := sprites.variant(vid)
		t.ok(not sheet.is_empty(), "%s loads" % vid)
		if sheet.is_empty():
			continue
		var walk: Array = sheet["frames"][CustomerSprites.FACING_S]["walk"]
		t.ok(walk[0].get_image().get_data() != walk[1].get_image().get_data(), "%s: the stride frame is another drawing" % vid)
		t.ok(walk[1].get_image().get_data() != walk[4].get_image().get_data(), "%s: the two strides differ (the other leg forward)" % vid)
		var eats: bool = vid != CustomerSprites.CLERK
		t.eq((sheet["animations"] as Dictionary).has("eat"), eats, "%s: an eating pose only for customers (staff never eat)" % vid)
		t.eq((sheet["animations"] as Dictionary).has("play"), eats, "%s: a crane-game pose only for customers (#132)" % vid)


## 開店！: the cut-in plays when the store goes from setup to open, never for a first snapshot that is already open
## (a load); staff on the floor wear the look of their face.
func test_opening_cutin_and_staff_looks(t, tree) -> void:
	var main: Node = await _boot(tree)
	var app: Node = main.get_node("AppRoot")
	var pc: ProgressionController = main.get_node("ProgressionController")
	t.ok(not pc._cutin.visible, "nothing at boot (setup)")
	app.state.business_state = GameState.OPEN
	app._publish_snapshot()
	t.ok(pc._cutin.visible, "opening the store plays 開店！")
	t.ok(not pc._stage.visible, "opening cut-in suppresses the assistant stage")
	var chrome := main.get_node_or_null("MockupChrome")
	if chrome != null:
		t.ok(not chrome.get_node("WindowLayer/Rikka").visible, "opening cut-in hides the mockup assistant figure")
		t.ok(not chrome.get_node("WindowLayer/Bubble").visible, "opening cut-in hides the mockup assistant bubble")
	pc._cutin.visible = false
	pc._finish_opening_cutin()
	app._publish_snapshot()
	t.ok(not pc._cutin.visible, "only on the change")
	t.ok(pc._stage.visible, "assistant stage returns after opening cut-in")
	if chrome != null:
		t.ok(not chrome.get_node("WindowLayer/Rikka").visible, "mockup assistant figure stays hidden while the generated pilot owns the stage")
		t.ok(not chrome.get_node("WindowLayer/Bubble").visible, "mockup assistant bubble stays hidden while the generated pilot owns the stage")
	pc._last_business = ""   # as after a load: the first snapshot is already open
	app._publish_snapshot()
	t.ok(not pc._cutin.visible, "a loaded open store does not replay it")
	t.eq(CustomerSprites.variant_for("staff_1", "佐藤"), CustomerSprites.CHIBI + Portraits.id_for_staff("佐藤"), "staff wear their face's look")
	t.eq(CustomerSprites.variant_for("staff_1"), CustomerSprites.CLERK, "no name: the shared clerk look")
	main.queue_free()
	await tree.process_frame


## #136 媒体広告: each medium has a thumbnail of 小春六花 in that ad (192x108 for its 128x72 slot).
func test_media_thumbnails(t, tree) -> void:
	var main: Node = await _boot(tree)
	for m in ["newspaper", "radio", "web_ads", "television"]:
		var pic := main.find_child("Thumb_" + m, true, false) as TextureRect
		t.ok(pic != null and pic.texture != null, "%s has its thumbnail" % m)
		if pic != null and pic.texture != null:
			t.eq(pic.texture.get_size(), MediaController.THUMB_SIZE * 1.5, "%s at 1.5x" % m)
	main.queue_free()
	await tree.process_frame


## #140 / #137: the fairs, the mascot collab, the gifts and the stamp rally have a picture (192x108 for 128x72).
func test_promotion_thumbnails(t, tree) -> void:
	var main: Node = await _boot(tree)
	main.get_node("AppRoot")._publish_snapshot()
	await tree.process_frame
	for d in ["fair_autumn", "fair_winter", "fair_summer", "fair_regional", "collab_mascot", "gift_clearfile", "gift_sticker", "stamps_lunch"]:
		var pic := main.find_child("Thumb_" + d, true, false) as TextureRect
		t.ok(pic != null and pic.texture != null and pic.texture.get_size() == PromotionController.THUMB_SIZE * 1.5, "%s has its picture at 1.5x" % d)
	main.queue_free()
	await tree.process_frame


## Text-only cards found by the card audit: the 店頭くじ sets get a prize picture, the 売れ筋 rows a product icon.
func test_kuji_sets_and_ranking_icons(t, tree) -> void:
	var main: Node = await _boot(tree)
	var app: Node = main.get_node("AppRoot")
	app._publish_snapshot()
	await tree.process_frame
	for k in Lottery.data()["sets"].map(func(d): return String(d["set_id"])):   # every set in the data
		var pic := main.find_child("Thumb_" + k, true, false) as TextureRect
		t.ok(pic != null and pic.texture != null and pic.texture.get_size() == LotteryController.THUMB_SIZE * 1.5, "%s has its prize picture at 1.5x" % k)
	app.state.ledger.cash_yen = 100000
	app.state.ledger.record("SALE", "ri1", 150, app.state.day, 0, {"reservation_id": "r", "sku_id": "snack_001", "qty": 1}, {"revenue": 150})
	app._publish_snapshot()
	var rc: ReportController = main.get_node("ReportController")
	t.ok(rc._rank_rows[0]["icon"].texture != null, "the best seller shows its product icon")
	main.queue_free()
	await tree.process_frame


## Screen audit 2026-11-01: she steps aside in build mode (the catalog is at the left edge) and while the map is open.
func test_assistant_steps_aside_for_build_and_map(t, tree) -> void:
	var main: Node = await _boot(tree)
	var stage: Control = main.get_node("AssistantStage")
	t.ok(stage.visible, "the story line is up")
	main.call("toggle_build")
	await tree.process_frame
	t.ok(not stage.visible, "build mode: hidden")
	main.call("close_build")
	await tree.process_frame
	t.ok(stage.visible, "back after building")
	main.get_node("BusinessController").call("open_map")
	await tree.process_frame
	t.ok(not stage.visible, "map open: hidden")
	main.get_node("BusinessController")._map_window.hide()
	await tree.process_frame
	t.ok(stage.visible, "back after the map")
	main.queue_free()
	await tree.process_frame


## Build catalog: every fixture type has a picture, its in-store art or, for types without it yet, a catalog photo
## at the thumbnail size (no grey placeholder box left).
func test_every_catalog_card_has_a_picture(t, _tree) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var items: Array = d if typeof(d) == TYPE_ARRAY else d.get("fixtures", [])
	for e in items:
		var id := String(e["type_id"])
		var empty := FixtureSprites.new().rotation_entry(id, 0).is_empty()
		if empty:
			var photo := BuildCatalog.CATALOG_PHOTOS + id + ".png"
			t.ok(ResourceLoader.exists(photo), "%s has a catalog photo" % id)
			if ResourceLoader.exists(photo):
				t.eq(Vector2i((load(photo) as Texture2D).get_size()), BuildCatalog.THUMB_PIXELS, "%s at the thumbnail size" % id)


## Product icons (ComfyUI, 2026-11-01): every SKU has its picture, scaled to the size the row asks for; the shelf drawing
## in the store keeps the code-made icon (#91).
func test_product_icons_have_pictures(t, _tree) -> void:
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	for id in products.skus:
		var sku: Dictionary = products.get_sku(id)
		t.ok(ResourceLoader.exists(ProductIcons.ART_DIR + String(id) + ".png"), "%s has a picture" % id)
		var tex := ProductIcons.texture(sku, 32)
		t.eq(tex.get_size(), Vector2(32, 32), "%s: drawn at the row size" % id)
		t.ok(tex.get_image().get_data() != ProductIcons.placeholder(sku, 32).get_image().get_data(), "%s: not the placeholder" % id)

