extends RefCounted
## Issue #61 (light glow): strength is a gentle daylight floor that rises to a bounded night peak.


func test_glow_is_faint_by_day_and_strong_at_night(t, _tree) -> void:
	var noon := LightGlow.intensity(12 * 3600)
	var midnight := LightGlow.intensity(0)
	t.ok(absf(noon - LightGlow.DAY_FLOOR) < 0.01, "noon sits on the small daylight floor")
	t.ok(midnight > 0.5 and midnight <= LightGlow.NIGHT_PEAK + 0.001, "midnight is strong but capped at the night peak")
	t.ok(LightGlow.intensity(18 * 3600) > noon, "evening glows more than noon")
	t.ok(LightGlow.intensity(18 * 3600) < midnight, "evening glows less than full night")


func test_glow_stays_within_bounds_every_hour(t, _tree) -> void:
	for h in 24:
		var v := LightGlow.intensity(h * 3600)
		t.ok(v >= LightGlow.DAY_FLOOR - 0.001 and v <= LightGlow.NIGHT_PEAK + 0.001, "hour %d within [floor, peak]" % h)
