class_name ReportChart
extends Control
## Grouped bars per day: revenue (cyan) and gross profit (green) side by side, last 7 days at most.
## The snapshot has no hourly data, so the x axis is per day. Operating profit stays in the text summary.
## Colour is never the only cue: each day carries its "DAY n" label and the y axis has labelled gridlines.

const REVENUE := UiTheme.INFO_CYAN
const GROSS := UiTheme.SUCCESS_GREEN
const AXIS := Color("42617b")
const GRID := Color(1, 1, 1, 0.12)
const LABEL := Color(1, 1, 1, 0.7)
const LEFT_MARGIN := 50.0
const BOTTOM_MARGIN := 18.0
const GRID_LINES := 3

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


## Smallest nice step (1, 2, 2.5, 5 or 10 times a power of ten) so that GRID_LINES steps reach `value`.
static func axis_step(value: float) -> float:
	var raw := maxf(value, 3.0) / float(GRID_LINES)
	var base := pow(10.0, floor(log(raw) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if m * base >= raw:
			return m * base
	return 10.0 * base


## Value range (x = bottom, y = top) the chart shows: zero is always inside, the top is a whole number of steps.
static func axis_range(values: Array) -> Vector2:
	var lo := 0.0
	var hi := 0.0
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	return Vector2(lo, axis_step(hi) * GRID_LINES)


## Y coordinate of value `v` inside `area` for the given value range.
static func value_y(v: float, area: Rect2, bounds: Vector2) -> float:
	return area.position.y + area.size.y * (bounds.y - v) / (bounds.y - bounds.x)


## Axis label in 円, switching to 万円 from 10,000 yen.
static func axis_label(yen: int) -> String:
	if yen >= 10000:
		if yen % 10000 == 0:
			return "%d万円" % (yen / 10000)
		return "%.1f万円" % (yen / 10000.0)
	return "%d円" % yen


## Gridlines as [{"y": float, "text": String}], one per step above zero.
static func grid_lines(values: Array, area: Rect2) -> Array:
	var bounds := axis_range(values)
	var step := bounds.y / float(GRID_LINES)
	var out: Array = []
	for k in range(1, GRID_LINES + 1):
		var v := step * k
		out.append({"y": value_y(v, area, bounds), "text": axis_label(int(round(v)))})
	return out


## Grouped bar rectangles: series[s][d] is the value of series s on day d. Result is [day][series] -> Rect2.
static func grouped_bar_rects(series: Array, area: Rect2) -> Array:
	var out: Array = []
	if series.is_empty() or series[0].is_empty():
		return out
	var all: Array = []
	for s in series:
		all.append_array(s)
	var bounds := axis_range(all)
	var zero_y := value_y(0.0, area, bounds)
	var days: int = series[0].size()
	var slot := area.size.x / float(days)
	var bar_w := slot * 0.7 / float(series.size())
	for d in days:
		var day: Array = []
		for s in series.size():
			var y := value_y(float(series[s][d]), area, bounds)
			var x := area.position.x + slot * d + slot * 0.15 + bar_w * s
			day.append(Rect2(x, minf(y, zero_y), bar_w, absf(y - zero_y)))
		out.append(day)
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15))
	if _reports.is_empty():
		return
	var area := Rect2(LEFT_MARGIN, 4, size.x - LEFT_MARGIN - 4, size.y - 4 - BOTTOM_MARGIN)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var revenue: Array = []
	var gross: Array = []
	for r in _reports:
		revenue.append(int(r["revenue_yen"]))
		gross.append(int(r["gross_profit_yen"]))
	var font := ThemeDB.fallback_font
	for g in grid_lines(revenue + gross, area):
		draw_line(Vector2(area.position.x, g["y"]), Vector2(area.end.x, g["y"]), GRID, 1.0)
		draw_string(font, Vector2(0, g["y"] + 4), g["text"], HORIZONTAL_ALIGNMENT_LEFT, LEFT_MARGIN - 4, 10, LABEL)
	var zero_y := value_y(0.0, area, axis_range(revenue + gross))
	var groups := grouped_bar_rects([revenue, gross], area)
	for d in groups.size():
		draw_rect(groups[d][0], REVENUE)
		draw_rect(groups[d][1], GROSS)
		var slot_x := area.position.x + area.size.x / float(groups.size()) * d
		draw_string(font, Vector2(slot_x, size.y - 4), "DAY %d" % int(_reports[d]["day_index"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_line(Vector2(area.position.x, zero_y), Vector2(area.end.x, zero_y), AXIS, 1.0)
