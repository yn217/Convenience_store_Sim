extends RefCounted
## The depth_v1 fixture art (2026-11-14, the game's default by the user's decision): products baked into the picture, so
## the picture follows the stock (issue #91 FULL / HALF / EMPTY); a machine without state pictures keeps its picture.

const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")


func test_every_depth_manifest_has_four_rotations_and_is_approved(t, _tree) -> void:
	var found := 0
	for d in DirAccess.get_directories_at("res://assets/generated/fixtures"):
		var path := "res://assets/generated/fixtures/%s/%s_depth_v1.visual.json" % [d, d]
		if not FileAccess.file_exists(path):
			continue
		found += 1
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		t.ok(VisualVariants.products_baked(m), "%s: products are baked" % d)
		t.eq(m.get("runtime_approved"), true, "%s: approved for the game (user, 2026-11-14)" % d)
		for r in 4:
			var rot: Dictionary = m["rotations"][str(r)]
			for layer in rot["layers"].values():
				t.ok(ResourceLoader.exists("res://assets/generated/fixtures/%s/%s" % [d, layer]), "%s r%d: %s exists" % [d, r, layer])
	t.eq(found, 28, "every fixture has depth art")


func test_the_stock_state_follows_the_fill(t, _tree) -> void:
	t.eq(Presenter.stock_state({}, 0), "FULL", "a fixture without stock is always full")
	t.eq(Presenter.stock_state({"row0": 12, "row1": 13}, 48), "FULL", "more than half")
	t.eq(Presenter.stock_state({"row0": 24}, 48), "HALF", "half is not full")
	t.eq(Presenter.stock_state({"row0": 1}, 48), "HALF")
	t.eq(Presenter.stock_state({}, 48), "EMPTY")


func test_the_depth_variant_is_the_default_and_the_base_stays_reachable(t, _tree) -> void:
	var prefs := VisualVariants.load_preferences()
	t.eq(String(VisualVariants.resolve(prefs, "fixtures", "shelf_snack", "")["variant"]), "depth_v1", "the game shows the depth art")
	t.eq(String(VisualVariants.resolve(prefs, "fixtures", "register_basic", "")["variant"]), "depth_v1", "the register too (its back redone 2026-11-14)")
	t.eq(String(VisualVariants.resolve(prefs, "fixtures", "shelf_snack", "a")["variant"]), "a", "the override can still force the current art")
	var sprites := FixtureSprites.new()
	var base := sprites.base_entry("shelf_snack", 0)
	t.eq(String(base.get("variant", "")), "a", "the fallback is the current art")
	t.ok(not bool(base.get("baked", true)), "whose items are drawn live")


func test_a_shelf_has_half_and_empty_pictures_of_the_same_unit(t, _tree) -> void:
	var sprites := FixtureSprites.new()
	for state in ["HALF", "EMPTY"]:
		var e := sprites.state_entry("shelf_general", 1, state)
		t.ok(not e.is_empty(), "shelf_general has a %s picture" % state)
		t.ok(bool(e.get("baked", false)), "its goods are part of the picture")
		t.eq(e["anchor"], sprites.rotation_entry("shelf_general", 1)["anchor"], "it stands exactly where the FULL picture does")
	t.ok(sprites.state_entry("coffee_machine", 0, "EMPTY").is_empty(), "a machine whose goods do not show has none: its picture stays")
