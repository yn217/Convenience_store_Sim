extends RefCounted
## Money figures on the fixed-width chrome labels shrink to fit: a long number is never cut off.


func test_a_long_figure_is_drawn_smaller_and_fits(t, tree) -> void:
	var host := Control.new()
	tree.root.add_child(host)
	var l := MockStyle.label(host, "", Rect2(0, 0, 116, 46), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "ExtraBold")
	MockStyle.set_fitted(l, "¥740")
	t.eq(l.get_theme_font_size("font_size"), 30, "a short figure keeps its size")
	for text in ["¥600,000", "¥12,345,678"]:
		MockStyle.set_fitted(l, text)
		var px := l.get_theme_font_size("font_size")
		t.ok(px < 30, "%s is drawn smaller (%d px)" % [text, px])
		t.ok(l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= l.size.x, "%s fits the label" % text)
	MockStyle.set_fitted(l, "¥740")
	t.eq(l.get_theme_font_size("font_size"), 30, "back to its size when it is short again")
	host.free()
