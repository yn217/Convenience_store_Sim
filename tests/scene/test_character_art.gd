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
	var r := title.get_node("TitleRikka") as TextureRect
	t.ok(r != null and r.texture != null, "she greets on the title screen")
	t.ok(r.get_global_rect().end.x > tree.root.get_visible_rect().size.x * 0.6, "at the right, clear of the menu")
	title.queue_free()
	await tree.process_frame


## #104 / #134: six chibi looks, a walk cycle with stride poses (the feet move), and a seated eating pose at the eat-in.
func test_chibi_looks_walk_and_eat(t, _tree) -> void:
	t.eq(CustomerSprites.VARIANTS.size(), 6, "six looks for the customers")
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
		t.ok((sheet["animations"] as Dictionary).has("eat"), "%s has the eating pose" % vid)
