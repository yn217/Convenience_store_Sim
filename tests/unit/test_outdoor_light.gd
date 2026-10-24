extends RefCounted
## Issue #114: the split between outdoor light (street, pavement, exterior props) and indoor light (the shop).


func _hour(h: float) -> int:
	return int(h * 3600.0)


func test_outdoor_curve_morning_noon_evening_night(t, _tree) -> void:
	var morning := LightingModel.outdoor(_hour(7.0))
	t.ok(morning.b >= morning.r, "morning is cool (blue not below red)")
	t.ok(LightingModel.luma(morning) > 0.9, "morning is bright")
	var noon := LightingModel.outdoor(_hour(12.0))
	t.ok(noon.is_equal_approx(Color(1, 1, 1, 1)), "noon is neutral")
	var evening := LightingModel.outdoor(_hour(18.0))
	t.ok(evening.r > evening.g and evening.g > evening.b, "evening is orange (red > green > blue)")
	var night := LightingModel.outdoor(_hour(2.0))
	t.ok(night.b > night.r, "night is blue")
	var night_luma := LightingModel.luma(night) / LightingModel.luma(noon)
	t.ok(absf(night_luma - 0.45) < 0.05, "night street is about 0.45 of noon luminance (%.3f)" % night_luma)


func test_outdoor_blends_over_an_hour_at_dusk_and_dawn(t, _tree) -> void:
	var mid_dusk := LightingModel.outdoor(_hour(16.5))
	t.ok(mid_dusk.g < 1.0 and mid_dusk.g > LightingModel.OUT_EVENING.g, "16-17 blends noon to evening")
	var mid_night := LightingModel.outdoor(_hour(19.5))
	t.ok(mid_night.g < LightingModel.OUT_EVENING.g and mid_night.g > LightingModel.OUT_NIGHT.g, "19-20 blends evening to night")
	var dawn := LightingModel.outdoor(_hour(5.5))
	t.ok(dawn.b > LightingModel.OUT_NIGHT.b - 0.001 and dawn.r > LightingModel.OUT_NIGHT.r, "05-06 dawn lifts from night")


func test_indoor_stays_bright_at_every_hour(t, _tree) -> void:
	for h in 24:
		var c := LightingModel.indoor(h * 3600)
		t.ok(minf(c.r, minf(c.g, c.b)) >= 0.88, "indoor hour %d keeps its brightness" % h)
		var warmth := c.r - c.b
		t.ok(absf(warmth) <= 0.12,"indoor hour %d is only a slight warm or cool hint" % h)


func test_product_colours_keep_their_luminance_at_night(t, _tree) -> void:
	# Readability rule (#114): a product colour lit by the shop at night stays within about 10% of its noon luminance.
	var product := Color(0.82, 0.46, 0.22)
	var noon := LightingModel.luma(product * LightingModel.indoor(_hour(12.0)))
	for h in [18.0, 20.0, 21.0, 23.0, 0.0, 2.0, 5.0]:
		var lit := LightingModel.luma(product * LightingModel.indoor(_hour(h)))
		var ratio := lit / noon
		t.ok(ratio >= 0.9 and ratio <= 1.1, "product at hour %.0f within 10%% of noon (%.3f)" % [h, ratio])


func test_outdoor_modulate_lands_on_outdoor_curve(t, _tree) -> void:
	# The CanvasModulate carries the indoor tint over everything; the outdoor layers multiply by outdoor_modulate.
	for h in 24:
		var time := h * 3600 + 900
		var effective := LightingModel.indoor(time) * LightingModel.outdoor_modulate(time)
		var want := LightingModel.outdoor(time)
		var err := maxf(absf(effective.r - want.r), maxf(absf(effective.g - want.g), absf(effective.b - want.b)))
		t.ok(err < 0.002, "hour %d outdoor matches the curve (err %.5f)" % [h, err])


func test_outdoor_is_darker_than_the_lit_shop_at_night(t, _tree) -> void:
	var night := _hour(22.0)
	t.ok(LightingModel.luma(LightingModel.indoor(night)) > LightingModel.luma(LightingModel.outdoor(night)) + 0.3, "at night the shop is much brighter than the street")
	t.ok(LightingModel.luma(LightingModel.indoor(_hour(12.0))) > 0.9, "by day the shop reads bright")


func test_dusk_amount_is_zero_by_day_and_one_at_night(t, _tree) -> void:
	t.ok(LightingModel.dusk_amount(_hour(12.0)) < 0.001, "noon has no dusk light")
	t.ok(LightingModel.dusk_amount(_hour(2.0)) > 0.999, "night has full dusk light")
	var evening := LightingModel.dusk_amount(_hour(17.5))
	t.ok(evening > 0.0 and evening < 1.0, "evening is in between")


func test_clock_bucket_changes_every_ten_minutes(t, _tree) -> void:
	t.eq(LightingModel.bucket(_hour(18.0)), LightingModel.bucket(_hour(18.0) + 300), "same bucket within ten minutes")
	t.ok(LightingModel.bucket(_hour(18.0)) != LightingModel.bucket(_hour(18.0) + 600), "next bucket after ten minutes")
