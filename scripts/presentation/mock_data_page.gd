class_name MockDataPage
extends Control
## The データ tab as the 2026-11-01 mockup draws it, in code: 日次レポート with today's four figures (and the change
## against the last closed day), 時間帯別の売上 as eight three-hour bars, and 売れ筋ランキング (本日 / 前日) as three cards.
## Fed by ReportController.apply_snapshot. Presentation only; 詳細 opens the full report text (the old cards, kept).

signal details_requested

const SIZE := Vector2(1028, 472)
const KPI := [["sales", "売上", 16, "coins", ""], ["profit", "粗利", 281, "", "chart-up"], ["customers", "来店客数", 546, "", "users"],
	["unit", "客単価", 806, "", "cart"]]
const KPI_W := [250, 250, 247, 212]
const BUCKETS := 8   # three hours a bar
const CHART := Rect2(98, 222, 900, 90)   # the plot area (bars stand on its bottom edge)
const RANK_X := [3, 346, 688]
const RANK_W := 328

var _values: Dictionary = {}
var _deltas: Dictionary = {}
var _bars: Array[UiShape] = []
var _axis: Array[Label] = []
var _ranks: Array[Dictionary] = []
var _day := "today"
var _snap: Dictionary = {}
var _toggles: Dictionary = {}
var _date: Label


func _ready() -> void:
	name = "DataMockup"
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_report()
	_build_chart()
	_build_ranking()


func _build_report() -> void:
	MockStyle.ribbon(self, Rect2(0, 0, 280, 42), "日次レポート", MockStyle.RIBBON_BLUE, "bar-chart", 25)
	MockStyle.picture(self, MockStyle.glyph("calendar", 64), Rect2(342, 7, 28, 28), Color("4a3a3a"))
	_date = MockStyle.label(self, "", Rect2(378, 2, 400, 38), 19, MockStyle.INK)
	var more := MockStyle.face_button(self, Rect2(926, 4, 94, 36), "詳細", Color("4f95e8"), Color("1d58b0"), Color("bcdcff"), Color.WHITE, 18, "chevron", 8.0)
	more.pressed.connect(func(): details_requested.emit())
	for i in KPI.size():
		var k: Array = KPI[i]
		var x: float = k[2]
		var w: float = KPI_W[i]
		MockStyle.shape(self, Rect2(x, 52, w, 112), {"top": Color("fff6df"), "bottom": Color("ffe7b8"), "border": Color("e8c88f"), "border_width": 2.0,
			"radius": 12.0, "shadow": Color(0.45, 0.25, 0.1, 0.15), "shadow_offset": Vector2(0, 2)})
		if k[3] != "":
			MockStyle.picture(self, MockStyle.art(k[3]), Rect2(x + 10, 60, 66, 66))
		else:
			MockStyle.picture(self, MockStyle.glyph(k[4], 128), Rect2(x + 12, 62, 62, 60), Color("f0a020") if k[0] == "profit" else (Color("4a9de8") if k[0] == "customers" else Color("e8901a")))
		MockStyle.label(self, k[1], Rect2(x + 94, 58, w - 100, 32), 22, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		_values[k[0]] = MockStyle.label(self, "", Rect2(x + 90, 86, w - 96, 44), 34, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		MockStyle.shape(self, Rect2(x + 30, 130, w - 60, 28), {"top": Color("fffbef"), "bottom": Color("f7ecd3"), "radius": 14.0})
		_deltas[k[0]] = MockStyle.label(self, "", Rect2(x + 30, 130, w - 60, 28), 16, MockStyle.GREEN, HORIZONTAL_ALIGNMENT_CENTER, "ExtraBold")


func _build_chart() -> void:
	MockStyle.card(self, Rect2(0, 172, 1028, 172))
	MockStyle.picture(self, MockStyle.glyph("dot", 32), Rect2(14, 182, 20, 20), Color("3a8ee6"))
	MockStyle.label(self, "時間帯別の売上", Rect2(40, 174, 180, 36), 24, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
	MockStyle.label(self, "（本日・税込）", Rect2(212, 176, 150, 34), 17, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
	for i in 4:
		var y := CHART.end.y - CHART.size.y * float(i) / 3.0
		var line := ColorRect.new()
		line.color = Color(0.55, 0.45, 0.4, 0.25 if i > 0 else 0.7)
		line.position = Vector2(CHART.position.x, y)
		line.size = Vector2(CHART.size.x, 1.5 if i == 0 else 1.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		_axis.append(MockStyle.label(self, "", Rect2(4, y - 12, 90, 24), 15, MockStyle.INK, HORIZONTAL_ALIGNMENT_RIGHT, "Bold"))
	var slot := CHART.size.x / float(BUCKETS)
	for b in BUCKETS:
		var bar := MockStyle.shape(self, Rect2(CHART.position.x + slot * b + slot * 0.5 - 23, CHART.end.y - 2, 46, 2),
			{"top": Color("5fbfff"), "bottom": Color("2a8be6"), "border": Color("8fd3ff"), "border_width": 1.0, "radius": 3.0, "gloss": 0.35})
		_bars.append(bar)
		MockStyle.label(self, "%d時" % (b * 3), Rect2(CHART.position.x + slot * b, CHART.end.y + 3, slot, 22), 15, MockStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, "Bold")


func _build_ranking() -> void:
	var rib := MockStyle.ribbon(self, Rect2(0, 356, 286, 42), "売れ筋ランキング", MockStyle.RIBBON_BROWN, "crown", 23)
	(rib.get_child(0) as CanvasItem).modulate = Color("ffd23c")   # the crown is gold
	for d in [["today", "本日", 856], ["yesterday", "前日", 940]]:
		var b := MockStyle.button(self, Rect2(d[2], 362, 78, 34), d[1])
		var plate := MockStyle.shape(b, Rect2(0, 0, 78, 34), {"radius": 8.0, "border_width": 2.0, "gloss": 0.35})
		var l := MockStyle.label(b, d[1], Rect2(0, 0, 78, 34), 18, MockStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, "Black")
		var which: String = d[0]
		b.pressed.connect(func(): set_day(which))
		_toggles[which] = {"plate": plate, "label": l}
	for i in 3:
		var x: float = RANK_X[i]
		MockStyle.shape(self, Rect2(x, 404, RANK_W, 68), {"top": Color("fffaf2"), "bottom": Color("fbeee0"), "border": Color("e2c3a6"), "border_width": 2.0,
			"radius": 10.0})
		var crown: Color = [Color("ffc928"), Color("c9ced8"), Color("e08a4a")][i]
		MockStyle.picture(self, MockStyle.glyph("crown", 96), Rect2(x + 8, 406, 44, 40), crown)
		MockStyle.label(self, str(i + 1), Rect2(x + 8, 418, 44, 26), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "Black", 3, Color(0.4, 0.25, 0.1, 0.8))
		var pic := MockStyle.picture(self, null, Rect2(x + 46, 414, 100, 56))
		var name_l := MockStyle.label(self, "", Rect2(x + 150, 404, 110, 46), 16, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		name_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		name_l.clip_text = true
		var price := MockStyle.label(self, "", Rect2(x + 150, 444, 110, 28), 21, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		MockStyle.shape(self, Rect2(x + 256, 424, 66, 30), {"top": Color("fff2d2"), "bottom": Color("ffe3a8"), "radius": 15.0})
		var qty := MockStyle.label(self, "", Rect2(x + 256, 424, 66, 30), 18, MockStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, "Black")
		_ranks.append({"pic": pic, "name": name_l, "price": price, "qty": qty})
	set_day("today")


func set_day(which: String) -> void:
	_day = which
	for d in _toggles:
		var on: bool = d == which
		(_toggles[d]["plate"] as UiShape).setup({"top": Color("ffe85a") if on else Color("4f95e8"), "bottom": Color("ffae12") if on else Color("1d58b0"),
			"border": Color("e98b1d") if on else Color("bcdcff")})
		(_toggles[d]["label"] as Label).add_theme_color_override("font_color", MockStyle.INK if on else Color.WHITE)
	if not _snap.is_empty():
		_render_ranking()


func apply_snapshot(s: Dictionary) -> void:
	_snap = s
	var day := int(s.get("day", 0))
	_date.text = "本日（DAY %d）の営業データ" % day
	var n := MetricBar.numbers(s)
	var t := MetricBar.texts(s)
	_values["sales"].text = t["sales"]
	_values["profit"].text = t["profit"]
	_values["customers"].text = "%d人" % n["customers"]
	_values["unit"].text = t["unit_price"]
	var reports: Array = s.get("daily_reports", [])
	var last: Dictionary = reports.back() if not reports.is_empty() else {}
	var buyers := int(last.get("purchasing_customers", 0))
	var prev := {"sales": int(last.get("revenue_yen", 0)), "profit": int(last.get("gross_profit_yen", 0)), "customers": int(last.get("visitors", 0)),
		"unit": int(last.get("revenue_yen", 0)) / buyers if buyers > 0 else 0}
	var now := {"sales": n["sales"], "profit": n["profit"], "customers": n["customers"], "unit": n["unit_price"]}
	for k in _deltas:
		(_deltas[k] as Label).text = delta_text(k, int(now[k]), int(prev[k]), not last.is_empty())
		(_deltas[k] as Label).add_theme_color_override("font_color", MockStyle.GREEN if int(now[k]) >= int(prev[k]) else MockStyle.RED)
	_render_chart(s.get("hourly_sales", {}).get("today", []))
	_render_ranking()


## "▲ 前日比 +16.7%" (yen figures) / "▲ 前日比 +4人" / "▲ 前日比 +¥20"; "前日の記録なし" before the first closed day.
static func delta_text(kind: String, now: int, prev: int, has_prev: bool) -> String:
	if not has_prev:
		return "前日の記録なし"
	var up := now >= prev
	var arrow := "↑" if up else "↓"
	match kind:
		"customers":
			return "%s 前日比 %s%d人" % [arrow, "+" if up else "−", absi(now - prev)]
		"unit":
			return "%s 前日比 %s%s" % [arrow, "+" if up else "−", GameHud.format_yen(absi(now - prev))]
	if prev <= 0:
		return "%s 前日比 —" % arrow
	var pct := 100.0 * float(now - prev) / float(prev)
	return "%s 前日比 %s%.1f%%" % [arrow, "+" if pct >= 0.0 else "−", absf(pct)]


## Eight three-hour sums of a 24-value hourly list.
static func buckets(hours: Array) -> Array[int]:
	var out: Array[int] = []
	for b in BUCKETS:
		var sum := 0
		for h in range(b * 3, b * 3 + 3):
			if h < hours.size():
				sum += int(hours[h])
		out.append(sum)
	return out


## A round top for the axis: 1 / 2 / 5 x 10^n at or above `peak`, three steps to it.
static func axis_top(peak: int) -> int:
	var top := 3000
	var scale := 1000
	while top < peak:
		for m in [3, 6, 15]:
			if scale * m >= peak:
				return scale * m
		scale *= 10
		top = scale * 3
	return top


func _render_chart(hours: Array) -> void:
	var b := buckets(hours)
	var peak := 0
	for v in b:
		peak = maxi(peak, v)
	var top := axis_top(peak)
	for i in _axis.size():
		_axis[i].text = GameHud.format_yen(top * i / 3).replace("¥", "") + "円"
	for i in BUCKETS:
		var h := maxf(2.0, CHART.size.y * float(b[i]) / float(top))
		_bars[i].position.y = CHART.end.y - h
		_bars[i].size.y = h
		_bars[i].tooltip_text = "%d時台 %s" % [i * 3, GameHud.format_yen(b[i])]


func _render_ranking() -> void:
	var sellers: Array = _snap.get("best_sellers_yesterday" if _day == "yesterday" else "best_sellers_today", [])
	for i in _ranks.size():
		var v: Dictionary = _ranks[i]
		if i < sellers.size():
			var s: Dictionary = sellers[i]
			v["pic"].texture = ProductIcons.trimmed({"sku_id": s["sku_id"], "category": s["category"], "display_name": s["name"]}, 56)
			v["name"].text = String(s["name"])
			v["price"].text = GameHud.format_yen(int(s["revenue_yen"]) / maxi(int(s["qty"]), 1))
			v["qty"].text = "%d個" % int(s["qty"])
		else:
			v["pic"].texture = null
			v["name"].text = "—"
			v["price"].text = ""
			v["qty"].text = ""
