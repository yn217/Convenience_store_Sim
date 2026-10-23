class_name ReportChart
extends Control
## Bars of operating profit per day (green above zero, red below). Colour is never the only cue:
## the zero line is drawn and each bar carries its day number.

const UP := UiTheme.SUCCESS_GREEN
const DOWN := Color("e07a7a")
const AXIS := Color("42617b")

var _reports: Array = []


func set_reports(reports: Array) -> void:
	_reports = reports
	queue_redraw()


## Bar rectangles for the given profits inside `area`; the zero line sits at `zero_y`.
static func bar_rects(profits: Array, area: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if profits.is_empty():
		return out
	var lo := 0
	var hi := 0
	for p in profits:
		lo = mini(lo, int(p))
		hi = maxi(hi, int(p))
	var span := float(maxi(hi - lo, 1))
	var zero_y := area.position.y + area.size.y * float(hi) / span
	var slot := area.size.x / float(profits.size())
	for i in profits.size():
		var h := area.size.y * absf(float(profits[i])) / span
		var y := zero_y - h if profits[i] >= 0 else zero_y
		out.append(Rect2(area.position.x + slot * i + slot * 0.15, y, slot * 0.7, h))
	return out


func _draw() -> void:
	var area := Rect2(4, 4, size.x - 8, size.y - 22)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15))
	if _reports.is_empty():
		return
	var profits: Array = []
	for r in _reports:
		profits.append(int(r["operating_profit_yen"]))
	var rects := bar_rects(profits, area)
	var font := ThemeDB.fallback_font
	for i in rects.size():
		draw_rect(rects[i], UP if profits[i] >= 0 else DOWN)
		draw_string(font, Vector2(rects[i].position.x, size.y - 4), "D%d" % int(_reports[i]["day_index"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var hi := 0
	for p in profits:
		hi = maxi(hi, int(p))
	var lo := 0
	for p in profits:
		lo = mini(lo, int(p))
	var zero_y := area.position.y + area.size.y * float(hi) / float(maxi(hi - lo, 1))
	draw_line(Vector2(area.position.x, zero_y), Vector2(area.end.x, zero_y), AXIS, 1.0)
