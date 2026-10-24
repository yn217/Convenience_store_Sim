extends RefCounted
## GUI v3 (#112): pure helpers and width budgets. The bottom band must fit a 1280 px window, the top bar's value
## variations pick gold / green / white, and the icons the band and the rail use exist and rasterise.

const Hud := preload("res://scripts/presentation/game_hud.gd")
const Bar := preload("res://scripts/presentation/metric_bar.gd")


func test_bottom_band_fits_a_1280_window(t, _tree) -> void:
	# 1280 px window minus the 12 px gap on each side (MainLayout.GAP).
	t.ok(Bar.band_budget_width() <= 1280.0 - 24.0, "band minimum %.0f px fits 1256 px" % Bar.band_budget_width())
	t.ok(Bar.band_budget_width() > 1000.0, "band minimum is a real budget, not zero")


func test_top_bar_values_take_gold_green_and_white(t, _tree) -> void:
	t.eq(Hud.value_variation("CashLabel"), &"HudCash", "money stays gold")
	t.eq(Hud.value_variation("SalesLabel"), &"HudCash", "sales stays gold")
	t.eq(Hud.value_variation("ProfitLabel"), &"HudProfit", "gross profit is green")
	t.eq(Hud.value_variation("CustomersLabel"), &"HudCustomers", "visitors are white")


func test_season_word_for_each_season(t, _tree) -> void:
	t.eq(Hud.season_text(4), "春", "April is spring")
	t.eq(Hud.season_text(7), "夏", "July is summer")
	t.eq(Hud.season_text(10), "秋", "October is autumn")
	t.eq(Hud.season_text(1), "冬", "January is winter")


func test_new_band_icons_exist_and_rasterise(t, _tree) -> void:
	for icon_name in ["coin", "clock", "bar-chart", "users", "cart", "person", "move", "rotate", "trash"]:
		t.ok(UiIcons.exists(icon_name), "%s.svg is in assets/ui/icons" % icon_name)
		t.ok(UiIcons.texture(icon_name, 34) != null, "%s rasterises at 34 px" % icon_name)


func test_left_nav_rail_fits_a_720_window(t, _tree) -> void:
	# Rail top = HUD + 12, bottom margin = summary band + 12; six entries + gaps + the panel margin must fit between.
	var room := 720.0 - UiTheme.HUD_HEIGHT - 12.0 - 108.0
	var height := 6.0 * LeftNav.ENTRY_HEIGHT + 5.0 * LeftNav.ENTRY_GAP + 12.0
	t.ok(height <= room, "rail %.0f px fits %.0f px" % [height, room])
