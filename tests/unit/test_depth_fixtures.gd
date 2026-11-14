extends RefCounted
## The depth_v1 fixture art (2026-11-14): products baked into the picture, so it is shown only while a fixture is more
## than half full (issue #91 FULL); below that the fixture falls back to the current art with its items drawn live.

const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")


func test_every_depth_manifest_has_four_rotations_and_waits_for_approval(t, _tree) -> void:
	var found := 0
	for d in DirAccess.get_directories_at("res://assets/generated/fixtures"):
		var path := "res://assets/generated/fixtures/%s/%s_depth_v1.visual.json" % [d, d]
		if not FileAccess.file_exists(path):
			continue
		found += 1
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		t.ok(VisualVariants.products_baked(m), "%s: products are baked" % d)
		t.eq(m.get("runtime_approved"), false, "%s: not approved until the user checks it" % d)
		for r in 4:
			var rot: Dictionary = m["rotations"][str(r)]
			for layer in rot["layers"].values():
				t.ok(ResourceLoader.exists("res://assets/generated/fixtures/%s/%s" % [d, layer]), "%s r%d: %s exists" % [d, r, layer])
	t.ok(found >= 20, "the depth art covers most fixtures: %d" % found)


func test_the_stock_state_follows_the_fill(t, _tree) -> void:
	t.eq(Presenter.stock_state({}, 0), "FULL", "a fixture without stock is always full")
	t.eq(Presenter.stock_state({"row0": 12, "row1": 13}, 48), "FULL", "more than half")
	t.eq(Presenter.stock_state({"row0": 24}, 48), "HALF", "half is not full")
	t.eq(Presenter.stock_state({"row0": 1}, 48), "HALF")
	t.eq(Presenter.stock_state({}, 48), "EMPTY")


func test_the_depth_variant_is_chosen_only_with_the_override_and_the_base_stays_reachable(t, _tree) -> void:
	var prefs := VisualVariants.load_preferences()
	t.eq(String(VisualVariants.resolve(prefs, "fixtures", "shelf_snack", "")["variant"]), "a", "not approved: the game keeps the current art")
	t.eq(String(VisualVariants.resolve(prefs, "fixtures", "shelf_snack", "depth_v1")["variant"]), "depth_v1", "the override shows it")
	var sprites := FixtureSprites.new()
	var base := sprites.base_entry("shelf_snack", 0)
	t.eq(String(base.get("variant", "")), "a", "the fallback is the current art")
	t.ok(not bool(base.get("baked", true)), "whose items are drawn live")
