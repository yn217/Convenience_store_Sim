extends RefCounted
## HUD formatting (04 §1: ¥123,456, Japanese labels).

const Hud := preload("res://scripts/presentation/game_hud.gd")


func test_yen(t, _tree) -> void:
	t.eq(Hud.format_yen(500000), "¥500,000")
	t.eq(Hud.format_yen(0), "¥0")
	t.eq(Hud.format_yen(999), "¥999")
	t.eq(Hud.format_yen(1234567), "¥1,234,567")
	t.eq(Hud.format_yen(-1234), "-¥1,234")


func test_clock_and_speed(t, _tree) -> void:
	t.eq(Hud.format_clock(0), "00:00")
	t.eq(Hud.format_clock(3661), "01:01")
	t.eq(Hud.format_clock(86400 + 60), "00:01", "wraps at day boundary")
	t.eq(Hud.speed_text(0), "停止")
	t.eq(Hud.speed_text(4), "×4")
