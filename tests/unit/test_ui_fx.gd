extends RefCounted
## Game feel helpers (UiFx): the pure curves and the direction rules. The Tween helpers run only on events and are
## covered by the scene tests.

const Fx := preload("res://scripts/presentation/ui_fx.gd")


func test_press_scale_sinks_and_lifts(t, _tree) -> void:
	t.eq(Fx.press_scale(false, false), 1.0, "idle is 1")
	t.eq(Fx.press_scale(true, false), 1.04, "hover lifts to 1.04")
	t.eq(Fx.press_scale(true, true), 0.96, "press squashes to 0.96")
	t.eq(Fx.press_scale(false, true), 0.96, "press without hover still squashes")


func test_hover_tint_brightens_only_while_hovered(t, _tree) -> void:
	t.eq(Fx.hover_tint(false, false), Color.WHITE, "idle is untinted")
	t.ok(Fx.hover_tint(true, false).r > 1.0, "hover brightens")
	t.ok(Fx.hover_tint(true, true).r < 1.0, "press darkens")


func test_pop_scale_eases_from_112_to_1(t, _tree) -> void:
	t.ok(absf(Fx.pop_scale(0.0) - 1.12) < 0.0001, "starts at 1.12")
	t.ok(absf(Fx.pop_scale(Fx.POP_SECONDS) - 1.0) < 0.0001, "settles at 1 when done")
	t.ok(absf(Fx.pop_scale(Fx.POP_SECONDS * 2.0) - 1.0) < 0.0001, "holds at 1 after the end")
	var mid := Fx.pop_scale(Fx.POP_SECONDS * 0.5)
	t.ok(mid > 1.0 and mid < 1.12, "mid pop is between the ends: %f" % mid)
	t.ok(Fx.pop_scale(Fx.POP_SECONDS * 0.25) > mid, "the pop shrinks over time")


func test_direction_is_sign_of_change(t, _tree) -> void:
	t.eq(Fx.direction(100, 150), 1, "increase")
	t.eq(Fx.direction(150, 100), -1, "decrease")
	t.eq(Fx.direction(7, 7), 0, "unchanged")


func test_flash_colour_follows_direction(t, _tree) -> void:
	t.eq(Fx.flash_color(1), Fx.FLASH_UP, "increase flashes green")
	t.eq(Fx.flash_color(-1), Fx.FLASH_DOWN, "decrease flashes red")
	t.eq(Fx.flash_color(0), Fx.FLASH_NEUTRAL, "neutral flashes warm white")
	t.ok(Fx.FLASH_UP.g > Fx.FLASH_UP.r and Fx.FLASH_DOWN.r > Fx.FLASH_DOWN.g, "green and red are the hues they say")


func test_selected_row_has_glow(t, _tree) -> void:
	var box := UiTheme.selected_row_box()
	t.ok(box.shadow_size > 0, "selected palette row glows")
	t.eq(box.border_color, UiTheme.HIGHLIGHT_BLUE, "selected row has the blue rim")


## Value pops: after the flash ends the label is back in its resting colour, also when pops overlap (the cash label
## pops on every change, so a second pop can start while the first flash is still running).
func _label_in_tree(tree) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudCash"
	tree.root.add_child(label)
	return label


func test_pop_returns_to_the_resting_colour(t, tree) -> void:
	var label := _label_in_tree(tree)
	await tree.process_frame
	var rest: Color = label.get_theme_color("font_color")
	Fx.pop(label, -1)
	await tree.create_timer(Fx.POP_SECONDS + 0.2).timeout
	t.eq(label.get_theme_color("font_color"), rest, "after one red pop the colour is the resting one")
	t.eq(label.scale, Vector2.ONE, "and the label is back to full size")
	label.queue_free()


func test_overlapping_pops_do_not_capture_the_flash_colour(t, tree) -> void:
	var label := _label_in_tree(tree)
	await tree.process_frame
	var rest: Color = label.get_theme_color("font_color")
	Fx.pop(label, -1)
	await tree.create_timer(0.05).timeout
	Fx.pop(label, -1)   # starts while the first red flash is still on the label
	await tree.create_timer(Fx.POP_SECONDS + 0.2).timeout
	t.eq(label.get_theme_color("font_color"), rest, "a second pop still settles on the gold, not on the red flash")
	label.queue_free()
