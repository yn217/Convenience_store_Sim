class_name DayEndScreen
extends Control
## The day's result screen (#19 SCR-13, redone 2026-11-14 for a commercial look): over a dimmed store, a cream card in
## the 経営管理 window's style with the day and a grade (S/A/B/C), four figure tiles that count up with the change
## from the day before, the day by hour, the day's topics (event, challenge, titles) and 履歴を詳しく見る / 翌日の経営へ.
## It slides in; the grade pops after the figures. Presentation only: ReportController feeds it the closed report.

signal history_requested
signal next_requested

const CARD_WIDTH := 900
const COUNT_SECONDS := 0.8
const LEFT_ROOM := 420.0
const GRADE_COLORS := {"S": Color("e8a100"), "A": Color("f07a14"), "B": Color("2f74c8"), "C": Color("8a8a8a")}
const GRADE_WORDS := {"S": "過去最高の売上！", "A": "好調な一日", "B": "まずまずの一日", "C": "赤字の一日"}

var _card: PanelContainer
var _title: Label
var _date: Label
var _badge: PanelContainer
var _grade: Label
var _grade_word: Label
var _tiles: Dictionary = {}   # key -> {value: Label, delta: Label}
var _hourly: HourlyChart
var _topics: Label
var _tween: Tween


func _init() -> void:
	name = "DayEndPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.build_window()
	_build()


## Shows the closed day. `reports` are all closed days, oldest first (the last is `closed`); `topics` the history
## lines (event, challenge, titles); `hours` the day's sales by hour ([] hides the chart); `date_text` e.g. "4月 第1週".
func show_day(closed: Dictionary, reports: Array, topics: Array, hours: Array, date_text: String = "") -> void:
	var day := int(closed["day_index"])
	_title.text = "DAY %d　営業結果" % day
	_date.text = date_text
	var g := grade(closed, reports)
	_grade.text = g
	_grade_word.text = String(GRADE_WORDS[g])
	(_badge.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GRADE_COLORS[g]
	var prev: Dictionary = reports[reports.size() - 2] if reports.size() >= 2 else {}
	_set_tile("revenue", int(closed["revenue_yen"]), prev.get("revenue_yen"), true)
	_set_tile("gross", int(closed["gross_profit_yen"]), prev.get("gross_profit_yen"), true)
	_set_tile("operating", int(closed["operating_profit_yen"]), prev.get("operating_profit_yen"), true)
	var visitors := int(closed["visitors"])
	var buyers := int(closed["purchasing_customers"])
	_set_tile("buyers", buyers, prev.get("purchasing_customers"), false)
	(_tiles["buyers"]["caption"] as Label).text = "来店 %d人 ／ 購買率 %d%%" % [visitors, int(round(100.0 * buyers / maxf(visitors, 1)))]
	var lines: Array[String] = []
	for l in topics:
		lines.append("・" + String(l))
	if int(closed.get("wastage_yen", 0)) > 0:
		lines.append("・廃棄 %s" % GameHud.format_yen(int(closed["wastage_yen"])))
	_topics.text = "\n".join(lines)
	_hourly.set_hours(hours)
	_hourly.visible = not hours.is_empty()
	visible = true
	_animate()


func close() -> void:
	visible = false


## Everything the card says, as plain text (tests and screen readers).
func card_text() -> String:
	var parts: Array[String] = [_title.text, _grade.text, _grade_word.text]
	for k in ["revenue", "gross", "operating", "buyers"]:
		var t: Dictionary = _tiles[k]
		parts.append("%s %s %s %s" % [(t["name"] as Label).text, _final_text(k), (t["delta"] as Label).text, (t["caption"] as Label).text])
	parts.append(_topics.text)
	return "\n".join(parts)


## S: the best day's revenue so far (from the second day on); A: at least the average of the days before (the first day:
## in profit); B: in profit; C: an operating loss.
static func grade(closed: Dictionary, reports: Array) -> String:
	var revenue := int(closed["revenue_yen"])
	if int(closed["operating_profit_yen"]) < 0:
		return "C"
	var before: Array = reports.slice(0, maxi(reports.size() - 1, 0))
	if before.is_empty():
		return "A"
	var best := 0
	var sum := 0
	for r in before:
		best = maxi(best, int(r["revenue_yen"]))
		sum += int(r["revenue_yen"])
	if revenue > best:
		return "S"
	return "A" if revenue * before.size() >= sum else "B"


## "前日比 +¥1,234" / "前日比 −3人" / "初日".
static func delta_text(value: int, previous, money: bool) -> String:
	if previous == null:
		return "初日"
	var d := value - int(previous)
	var amount := GameHud.format_yen(absi(d)) if money else "%d人" % absi(d)
	return "前日比 %s%s" % ["+" if d >= 0 else "−", amount]


var _finals: Dictionary = {}


func _final_text(key: String) -> String:
	var v := int(_finals.get(key, 0))
	return "%d人" % v if key == "buyers" else GameHud.format_yen(v)


func _set_tile(key: String, value: int, previous, money: bool) -> void:
	_finals[key] = value
	var t: Dictionary = _tiles[key]
	var delta := t["delta"] as Label
	delta.text = delta_text(value, previous, money)
	var good := previous == null or value >= int(previous)
	delta.add_theme_color_override("font_color", UiTheme.W_GOOD if good else Color("c0392b"))
	(t["value"] as Label).text = _final_text(key)
	if key == "operating":
		(t["value"] as Label).add_theme_color_override("font_color", Color("c0392b") if value < 0 else UiTheme.W_ACCENT)


## Slides the card in, counts the figures up and pops the grade (all short; skipped values end exact).
func _animate() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	_badge.pivot_offset = _badge.size * 0.5
	_badge.scale = Vector2.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for key in ["revenue", "gross", "operating", "buyers"]:
		var label := _tiles[key]["value"] as Label
		var target := int(_finals[key])
		_tween.parallel().tween_method(func(v: float): label.text = "%d人" % int(v) if key == "buyers" else GameHud.format_yen(int(v)), 0.0, float(target), COUNT_SECONDS).set_delay(0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_badge, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_badge, "scale", Vector2.ONE, 0.12)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = LEFT_ROOM   # Rikka comments on the day from the bottom-left corner: the card stands right of her
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.name = "DayEndCard"
	_card.theme_type_variation = &"WindowFrame"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)
	# Header: the day on a ribbon, the date, and the grade badge on the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", _ribbon_box())
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	titles.add_child(ribbon)
	_title = Label.new()
	_title.name = "DayEndTitle"
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color.WHITE)
	ribbon.add_child(_title)
	_date = Label.new()
	_date.theme_type_variation = &"MutedLabel"
	titles.add_child(_date)
	var grade_box := VBoxContainer.new()
	grade_box.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(grade_box)
	_badge = PanelContainer.new()
	_badge.name = "DayEndGrade"
	_badge.custom_minimum_size = Vector2(84, 84)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = GRADE_COLORS["A"]
	badge_box.set_corner_radius_all(42)
	badge_box.border_color = Color.WHITE
	badge_box.set_border_width_all(4)
	badge_box.shadow_color = Color(0, 0, 0, 0.25)
	badge_box.shadow_size = 6
	_badge.add_theme_stylebox_override("panel", badge_box)
	grade_box.add_child(_badge)
	_grade = Label.new()
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grade.add_theme_font_size_override("font_size", 46)
	_grade.add_theme_color_override("font_color", Color.WHITE)
	_badge.add_child(_grade)
	_grade_word = Label.new()
	_grade_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_word.add_theme_color_override("font_color", UiTheme.W_ACCENT)
	grade_box.add_child(_grade_word)
	# The four figures.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	col.add_child(tiles)
	for spec in [["revenue", "売上高"], ["gross", "粗利益"], ["operating", "営業利益"], ["buyers", "お買い上げ"]]:
		tiles.add_child(_tile(spec[0], spec[1]))
	# The day by hour and the topics, side by side.
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 12)
	col.add_child(mid)
	var chart_card := _card_box("時間帯別の売上")
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(chart_card)
	_hourly = HourlyChart.new()
	_hourly.name = "DayEndHourly"
	_hourly.custom_minimum_size = Vector2(0, 150)
	_hourly.background = Color(1, 1, 1, 0.7)
	_hourly.bar_color = UiTheme.W_ORANGE
	_hourly.grid_color = Color(UiTheme.W_CARD_RIM, 0.8)
	_hourly.label_color = UiTheme.W_MUTED
	chart_card.get_child(0).add_child(_hourly)
	var topic_card := _card_box("今日のできごと")
	topic_card.custom_minimum_size = Vector2(330, 0)
	mid.add_child(topic_card)
	_topics = Label.new()
	_topics.name = "DayEndTopics"
	_topics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_topics.custom_minimum_size = Vector2(300, 0)
	topic_card.get_child(0).add_child(_topics)
	# Buttons.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var more := Button.new()
	more.name = "DayEndHistory"
	more.text = "履歴を詳しく見る"
	more.custom_minimum_size = Vector2(220, 54)
	more.pressed.connect(func(): history_requested.emit())
	row.add_child(more)
	var next := Button.new()
	next.name = "DayEndNext"
	next.text = "翌日の経営へ"
	next.theme_type_variation = &"PrimaryButton"
	next.custom_minimum_size = Vector2(260, 54)
	next.pressed.connect(func(): next_requested.emit())
	row.add_child(next)


func _tile(key: String, caption: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "DayEndTile_" + key
	box.theme_type_variation = &"Card"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var name_label := Label.new()
	name_label.text = caption
	name_label.theme_type_variation = &"CardTitle"
	name_label.add_theme_font_size_override("font_size", 16)
	col.add_child(name_label)
	var value := Label.new()
	value.name = "Value"
	value.add_theme_font_size_override("font_size", 32)
	value.add_theme_color_override("font_color", UiTheme.W_ACCENT)
	col.add_child(value)
	var delta := Label.new()
	delta.add_theme_font_size_override("font_size", 15)
	col.add_child(delta)
	var sub := Label.new()
	sub.theme_type_variation = &"MutedLabel"
	sub.add_theme_font_size_override("font_size", 14)
	col.add_child(sub)
	_tiles[key] = {"name": name_label, "value": value, "delta": delta, "caption": sub}
	return box


func _card_box(caption: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.theme_type_variation = &"Card"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	var l := Label.new()
	l.text = caption
	l.theme_type_variation = &"CardTitle"
	l.add_theme_font_size_override("font_size", 16)
	col.add_child(l)
	return box


static func _ribbon_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = UiTheme.W_RIBBON_BROWN
	b.set_corner_radius_all(10)
	b.content_margin_left = 22
	b.content_margin_right = 28
	b.content_margin_top = 4
	b.content_margin_bottom = 6
	return b
