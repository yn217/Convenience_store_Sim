extends RefCounted
## Issue #61 / #114 (light glow): the indoor glow is switched off at every hour (user feedback 2026-10-24:
## the glow over fixtures was distracting; the interior keeps its own bright tint instead).


func test_glow_is_off_at_every_hour(t, _tree) -> void:
	for h in 24:
		t.eq(LightGlow.intensity(h * 3600), 0.0, "hour %d: no indoor glow" % h)
