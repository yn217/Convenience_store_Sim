extends RefCounted
## Issue #61: the original UI icon set loads from the SVG text at any size, is cached, and is single-colour white.

const NAMES := [
	"store", "box", "person", "megaphone", "bar-chart", "gear", "cash", "wallet", "users", "sun", "chevron-right",
	"trash", "rotate", "move", "heart", "calendar", "music-note", "drop", "eye", "cart", "truck", "tag", "grid", "play", "pause",
]


func test_every_listed_icon_loads_at_the_requested_size(t, _tree) -> void:
	for name in NAMES:
		var tex := UiIcons.texture(name, 24)
		t.ok(tex != null, "icon loads: " + name)
		if tex != null:
			t.eq(tex.get_size(), Vector2(24, 24), "24 px: " + name)
	t.eq(UiIcons.texture("store", 32).get_size(), Vector2(32, 32), "rasterised at 32 px, not scaled from 24")
	t.eq(UiIcons.texture("store", 20).get_size(), Vector2(20, 20), "rasterised at 20 px")


func test_icon_is_cached_per_name_and_size(t, _tree) -> void:
	var a := UiIcons.texture("gear", 24)
	t.ok(is_same(a, UiIcons.texture("gear", 24)), "same instance on the second call")
	t.ok(not is_same(a, UiIcons.texture("gear", 32)), "a different size is a different texture")


func test_missing_icon_is_null(t, _tree) -> void:
	t.ok(UiIcons.texture("does-not-exist", 24) == null, "unknown name gives null")
	t.ok(not UiIcons.exists("does-not-exist"), "exists() is false for unknown names")
	t.ok(UiIcons.exists("store"), "exists() is true for a real icon")


func test_icon_files_are_white_single_colour_svg(t, _tree) -> void:
	var colour := RegEx.create_from_string("#(?!ffffff)[0-9a-fA-F]{6}")
	for name in NAMES:
		var svg := FileAccess.get_file_as_string("res://assets/ui/icons/%s.svg" % name)
		t.ok(svg.contains('viewBox="0 0 24 24"'), "24x24 viewBox: " + name)
		t.ok(colour.search(svg) == null, "only #ffffff colour: " + name)
	t.ok(FileAccess.file_exists("res://assets/ui/icons/README.md"), "provenance README is in the folder")
