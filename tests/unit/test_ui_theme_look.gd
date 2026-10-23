extends RefCounted
## #61 game-style look: the toast helpers and the type variations the HUD and toasts rely on.


func test_achievement_toasts_are_recognised_by_text(t, _tree) -> void:
	var text := CueText.toast_text("milestone_celebrate", {"name_ja": "売上1万円"})
	t.ok(CueText.is_achievement(text), "milestone toast is an achievement: %s" % text)
	t.ok(not CueText.is_achievement(CueText.toast_text("long_queue", {})), "queue notice is a normal toast")
	t.ok(not CueText.is_achievement(""), "empty text is not an achievement")


func test_achievement_toast_box_has_warm_rim(t, _tree) -> void:
	var achievement := UiTheme.toast_box(Color("90caf9"), true)
	t.eq(achievement.border_color, UiTheme.WARM)
	t.eq(achievement.get_border_width(SIDE_TOP), 1)
	var normal := UiTheme.toast_box(Color("90caf9"), false)
	t.ok(normal.border_color != UiTheme.WARM, "normal toasts keep the priority edge colour")
	t.ok(normal.corner_radius_top_left >= 12, "toasts are pills")


func test_theme_provides_segment_and_toggle_variations(t, _tree) -> void:
	var theme := UiTheme.build()
	for variation in ["SegmentLeft", "SegmentMid", "SegmentRight", "PrimaryButton", "ConfirmButton", "DangerButton", "Card"]:
		t.ok(theme.has_stylebox("panel" if variation == "Card" else "normal", variation), "type variation %s has its look" % variation)
	t.ok(theme.has_stylebox("pressed", "SegmentMid"), "selected segment has a pressed look")
	t.ok(theme.has_icon("checked", "CheckButton") and theme.has_icon("unchecked", "CheckButton"), "toggles have pill icons")
	t.ok(theme.has_icon("grabber", "HSlider"), "sliders have a round grabber")


func test_segment_corners_round_only_outer_side(t, _tree) -> void:
	var left := UiTheme._segment_box(UiTheme.SLATE, UiTheme.SLATE_EDGE, true, false, false)
	t.ok(left.corner_radius_top_left > 0 and left.corner_radius_top_right == 0, "left segment rounds its left corners only")
	var mid := UiTheme._segment_box(UiTheme.SLATE, UiTheme.SLATE_EDGE, false, false, false)
	t.eq(mid.corner_radius_top_left + mid.corner_radius_top_right, 0)
