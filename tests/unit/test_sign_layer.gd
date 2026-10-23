extends RefCounted
## Issue #61 (signs): label choice and board geometry of the code-drawn category signs.


func test_label_comes_from_the_first_allowed_category(t, _tree) -> void:
	t.eq(SignLayer.label_for({"allowed_categories": ["rice_ball", "bread"]}), "おにぎり", "first category wins")
	t.eq(SignLayer.label_for({"allowed_categories": ["ice_cream"]}), "アイス", "ice cream board")
	t.eq(SignLayer.label_for({"allowed_categories": ["instant_noodle"]}), "カップ麺", "noodle board")


func test_register_and_unlabelled_fixtures_get_no_sign(t, _tree) -> void:
	t.eq(SignLayer.label_for({"allowed_categories": []}), "", "register / no categories")
	t.eq(SignLayer.label_for({}), "", "empty definition")
	t.eq(SignLayer.label_for({"allowed_categories": ["unknown_cat"]}), "", "unknown category has no label")


func test_every_category_colour_has_a_label(t, _tree) -> void:
	var presenter := preload("res://scripts/presentation/fixture_presenter.gd")
	for cat in presenter.CATEGORY_COLOR.keys():
		t.ok(SignLayer.LABELS.has(cat), "label for %s" % cat)


func test_text_size_scales_and_clamps(t, _tree) -> void:
	t.eq(SignLayer.text_size(1.0), 12, "12 px at normal zoom")
	t.eq(SignLayer.text_size(0.6), 9, "clamped up to 9")
	t.eq(SignLayer.text_size(2.0), 16, "clamped down to 16")


func test_board_is_centred_on_the_top_edge_and_slightly_above(t, _tree) -> void:
	var bounds := Rect2(100.0, 200.0, 80.0, 60.0)
	var r := SignLayer.board_rect(bounds, 40.0, 1.0)
	t.ok(absf(r.get_center().x - bounds.get_center().x) < 0.001, "horizontally centred on the fixture")
	t.ok(r.get_center().y < bounds.position.y, "centre sits above the top edge")
	t.ok(r.get_center().y >= bounds.position.y - 8.0, "only slightly above")
	t.ok(r.size.x > 40.0, "board is wider than its text")


func test_board_grows_with_zoom_and_text(t, _tree) -> void:
	var bounds := Rect2(0.0, 0.0, 80.0, 60.0)
	var small := SignLayer.board_rect(bounds, 30.0, 0.6)
	var big := SignLayer.board_rect(bounds, 30.0, 1.5)
	t.ok(big.size.y > small.size.y, "taller at higher zoom")
	var wide := SignLayer.board_rect(bounds, 90.0, 1.0)
	t.ok(wide.size.x > SignLayer.board_rect(bounds, 30.0, 1.0).size.x, "wider for longer text")
