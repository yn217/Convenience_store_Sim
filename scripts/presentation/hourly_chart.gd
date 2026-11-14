class_name HourlyChart
extends Control
## #19 売上の推移 (PR #175 営業結果 mockup): revenue per hour of one day, 24 bars, with an optional second day drawn
## behind in grey for comparison. Confirmed sales only (the ledger's SALE rows). Hours are labelled every 3 hours
## and the y axis has labelled gridlines (ReportChart's), so colour is never the only cue.

const BAR := UiTheme.INFO_CYAN
const COMPARE := Color(1, 1, 1, 0.22)
const HOURS := 24
## Colours, for the dark panels by default; the cream result screen (DayEndScreen) sets its own.
var background := Color(0, 0, 0, 0.15)
var bar_color := BAR
var grid_color := ReportChart.GRID
var label_color := ReportChart.LABEL

var _values: Array = []    # 24 ints, the day shown
var _compare: Array = []   # 24 ints or empty


func set_hours(values: Array, compare: Array = []) -> void:
	_values = values
	_compare = compare
	queue_redraw()


func values() -> Array:
	return _values


## Bar rectangle of hour `h` inside `area` for the value range `bounds` (wide = the comparison bar behind).
static func hour_rect(h: int, value: float, area: Rect2, bounds: Vector2, wide: bool) -> Rect2:
	var slot := area.size.x / float(HOURS)
	var w := slot * (0.85 if wide else 0.55)
	var x := area.position.x + slot * h + (slot - w) * 0.5
	var y := ReportChart.value_y(value, area, bounds)
	var zero := ReportChart.value_y(0.0, area, bounds)
	return Rect2(x, y, w, zero - y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	if _values.is_empty():
		return
	var area := Rect2(ReportChart.LEFT_MARGIN, 4, size.x - ReportChart.LEFT_MARGIN - 4, size.y - 4 - ReportChart.BOTTOM_MARGIN)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var all: Array = _values + _compare
	var bounds := ReportChart.axis_range(all)
	var font := ThemeDB.fallback_font
	for g in ReportChart.grid_lines(all, area):
		draw_line(Vector2(area.position.x, g["y"]), Vector2(area.end.x, g["y"]), grid_color, 1.0)
		draw_string(font, Vector2(0, g["y"] + 4), g["text"], HORIZONTAL_ALIGNMENT_LEFT, ReportChart.LEFT_MARGIN - 4, 10, label_color)
	for h in HOURS:
		if h < _compare.size() and int(_compare[h]) > 0:
			draw_rect(hour_rect(h, float(_compare[h]), area, bounds, true), COMPARE)
		if h < _values.size() and int(_values[h]) > 0:
			draw_rect(hour_rect(h, float(_values[h]), area, bounds, false), bar_color)
		if h % 3 == 0:
			var x := area.position.x + area.size.x / float(HOURS) * h
			draw_string(font, Vector2(x, size.y - 4), "%d時" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	var zero := ReportChart.value_y(0.0, area, bounds)
	draw_line(Vector2(area.position.x, zero), Vector2(area.end.x, zero), ReportChart.AXIS, 1.0)
