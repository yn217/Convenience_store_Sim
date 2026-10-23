extends RefCounted
## Issue #61 (art side): the store reads warm at every hour, and never so tinted that colours are lost.


func test_daylight_is_warm_but_legible(t, _tree) -> void:
	var c := LightingModel.tint(12 * 3600)
	t.ok(c.r >= c.g and c.g >= c.b, "red >= green >= blue")
	t.ok(c.b >= 0.9, "blue channel stays above 0.9 so product colours are not lost")
	for h in 24:
		var x := LightingModel.tint(h * 3600)
		t.ok(minf(x.r, minf(x.g, x.b)) >= 0.6, "hour %d is readable" % h)
