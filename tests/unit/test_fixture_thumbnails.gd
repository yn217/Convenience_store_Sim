extends RefCounted
## Issue #61: palette thumbnails are 56 px, show the fixture's visible pixels, and are cached per type.

const TYPES := [
	"register_basic", "shelf_general", "shelf_onigiri", "warmer_oden", "shelf_noodle",
	"shelf_bread", "fridge_drink", "shelf_snack", "fridge_dessert", "freezer_ice",
]


func test_every_fixture_type_gets_a_56_px_thumbnail(t, _tree) -> void:
	for type_id in TYPES:
		var tex := FixtureThumbnails.texture(type_id)
		t.ok(tex != null, "thumbnail for " + type_id)
		if tex == null:
			continue
		t.eq(tex.get_size(), Vector2(56, 56), "56 px: " + type_id)
		var img := tex.get_image()
		var used := img.get_used_rect()
		t.ok(used.size.x > 0 and used.size.y > 0, "has visible pixels: " + type_id)
		t.ok(used.size.x == 56 or used.size.y == 56, "scaled to fill one side: " + type_id)


func test_thumbnail_is_cached_per_type(t, _tree) -> void:
	var a := FixtureThumbnails.texture("shelf_general")
	t.ok(is_same(a, FixtureThumbnails.texture("shelf_general")), "same instance on the second call")
	t.ok(FixtureThumbnails.cached_count() >= 1, "cache holds the type")


func test_type_without_a_sprite_gets_null(t, _tree) -> void:
	t.ok(FixtureThumbnails.texture("no_such_fixture") == null, "no manifest means no thumbnail")
