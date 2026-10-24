class_name MetricBar
extends PanelContainer
## Bottom band (GUI v3, #112): ONE translucent band under the store. Left: 本日の目標 (the first milestone not yet reached,
## with a progress bar and a %). Centre: 本日の売上 / 本日の粗利 / 来店客数 / 客単価 (売上 ÷ 購入客数, "—" with no purchases),
## each with a large coloured icon. Right: 本日のイベント, today's event as a timeline of up to three rows (clock icons; a row
## that is too long is trimmed with an ellipsis and its full text is the tooltip). Display only, fed by the same snapshot as
## the top HUD. The band stops the mouse (it is a real strip, not a click-through overlay). Repeat rate is not in the model.
## A changed number pops (presentation only).

const METRICS := [
	{"id": "sales", "title": "本日の売上", "icon": "bar-chart", "tint": UiTheme.SUCCESS_GREEN},
	{"id": "profit", "title": "本日の粗利", "icon": "coin", "tint": UiTheme.GOLD},
	{"id": "customers", "title": "来店客数", "tip": "店に入った人数（1人が複数点を買うことがあります。購入客数は日報）", "icon": "users", "tint": UiTheme.INFO_CYAN},
	{"id": "unit_price", "title": "客単価", "tip": "売上 ÷ 購入客数", "icon": "cart", "tint": UiTheme.TEXT_PRIMARY},
]
const HEIGHT := 96          # band height (the summary strip is this plus the gap under it, see MainLayout.BOTTOM_HEIGHT)
const CARD_HEIGHT := 88     # the tiles inside the band: the band's 4 px top and bottom margins come off HEIGHT
const GAP := 12             # space between the groups
const GOAL_WIDTH := 200     # 200 + 4 x 168 + 260 + the gaps and band padding = 1204 px: the band fits a 1280 px window
const EVENT_WIDTH := 260
const METRIC_MIN := 168     # each KPI tile (min width; the tiles share the spare width of a wide window)
const ICON_SIZE := 32       # the KPI icons: large and coloured (bar chart green, coin gold, people blue, cart white)
const HEADING_ICON := 16
const TIMELINE_ROWS := 3
const CLOCK_ICON := 14
const NONE := "—"

var _values: Dictionary = {}   # id -> value Label
var _last: Dictionary = {}     # id -> last number shown (ints), for the pop
var _goal_text: Label
var _goal_bar: ProgressBar
var _goal_percent: Label
var _timeline: Array = []      # per row: {box, time, text}


func _ready() -> void:
	name = "MetricBar"
	theme_type_variation = &"BottomBand"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(_goal_card())
	var metrics := HBoxContainer.new()
	metrics.name = "Metrics"
	metrics.add_theme_constant_override("separation", 8)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the KPI tiles take the band's spare width
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(metrics)
	for c in METRICS:
		_add_metric(metrics, c)
	row.add_child(_event_card())


## 本日の目標: a title with its icon, the goal sentence, and a bar with the percent.
func _goal_card() -> PanelContainer:
	var card := _summary_card("GoalCard", GOAL_WIDTH)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_heading("本日の目標", "target", UiTheme.WARM))
	_goal_text = Label.new()
	_goal_text.name = "GoalText"
	_goal_text.clip_text = true
	_goal_text.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	column.add_child(_goal_text)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_row)
	_goal_bar = ProgressBar.new()
	_goal_bar.name = "GoalBar"
	_goal_bar.show_percentage = false
	_goal_bar.max_value = 1.0
	_goal_bar.custom_minimum_size.y = UiTheme.BAR_HEIGHT
	_goal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_goal_bar)
	_goal_percent = Label.new()
	_goal_percent.name = "GoalPercent"
	_goal_percent.theme_type_variation = &"SummaryValue"
	_goal_percent.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL + 2)
	bar_row.add_child(_goal_percent)
	return card


## 本日のイベント: a title with its icon and up to TIMELINE_ROWS timeline rows (time, then text).
func _event_card() -> PanelContainer:
	var card := _summary_card("EventCard", EVENT_WIDTH)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # a wide window gives the timeline room: fewer ellipses
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_heading("本日のイベント", "star", UiTheme.WARM))
	for i in TIMELINE_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_PASS   # passes the mouse on, but keeps the row's tooltip
		column.add_child(line)
		var clock := TextureRect.new()
		clock.texture = UiIcons.texture("clock", CLOCK_ICON)
		clock.custom_minimum_size = Vector2(CLOCK_ICON, CLOCK_ICON)
		clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		clock.modulate = UiTheme.WARM
		clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(clock)
		var time := Label.new()
		time.theme_type_variation = &"CardTitle"
		time.add_theme_color_override("font_color", UiTheme.WARM)
		time.custom_minimum_size.x = 40
		time.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(time)
		var text := Label.new()
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # never a hard cut: an ellipsis, the full text in the tooltip
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(text)
		_timeline.append({"box": line, "time": time, "text": text})
	return card


func _summary_card(card_name: String, width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.theme_type_variation = &"SummaryCard"
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(width, CARD_HEIGHT)
	return card


## A card heading: a small icon and a warm title in one row.
func _heading(title: String, icon_name: String, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(icon_name, HEADING_ICON)
	icon.custom_minimum_size = Vector2(HEADING_ICON, HEADING_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"SectionTitle"
	label.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL + 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


## One KPI tile: a large coloured icon | title over value.
func _add_metric(row: HBoxContainer, c: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "Metric_" + c["id"]
	card.theme_type_variation = &"SummaryCard"
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(METRIC_MIN, CARD_HEIGHT)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UiTheme.SPACE_S)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(line)
	# A large coloured icon with no disc behind it: the icon itself is the colour cue (GUI v3).
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UiIcons.texture(c["icon"], ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = c["tint"]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(box)
	var title := Label.new()
	title.text = c["title"]
	title.theme_type_variation = &"CardTitle"
	title.clip_text = true
	box.add_child(title)
	var value := Label.new()
	value.theme_type_variation = &"SummaryValue"
	value.text = NONE
	value.clip_text = true
	if c.has("tip"):
		value.tooltip_text = c["tip"]
	box.add_child(value)
	row.add_child(card)
	_values[c["id"]] = value


## The narrowest width the band can take: the goal card, the four KPI tiles at their minimum, the event card, and the gaps
## and margins between them. The band must fit the window minus its side gaps (1280 px window: 1256 px).
static func band_budget_width() -> float:
	return GOAL_WIDTH + EVENT_WIDTH + METRIC_MIN * 4 + GAP * 2 + 8 * 3 + 12 * 2


static func texts(s: Dictionary) -> Dictionary:
	var n := numbers(s)
	return {
		"sales": GameHud.format_yen(n["sales"]),
		"profit": GameHud.format_yen(n["profit"]),
		"customers": "%d 人" % n["customers"],
		"unit_price": NONE if purchased(s) <= 0 else GameHud.format_yen(n["unit_price"]),
	}


## The numbers behind the card texts (ints), so a change can be detected without comparing strings.
static func numbers(s: Dictionary) -> Dictionary:
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	var revenue := int(today["revenue_yen"])
	return {
		"sales": revenue,
		"profit": int(today["gross_profit_yen"]),
		"customers": visitors(s),
		"unit_price": unit_price(revenue, purchased(s)),
	}


## Customers who came in today (the real visit count, not the ones inside right now).
static func visitors(s: Dictionary) -> int:
	return int(s.get("visit_stats", {}).get("entered", 0))


## Customers who bought something today.
static func purchased(s: Dictionary) -> int:
	return int(s.get("visit_stats", {}).get("purchased", 0))


## 客単価: today's sales divided by the customers who bought (integer yen, rounded down). 0 when nobody bought yet.
static func unit_price(revenue_yen: int, purchased_count: int) -> int:
	if purchased_count <= 0:
		return 0
	return revenue_yen / purchased_count


## Progress toward a goal in 0..1. A goal with no target is already met.
static func goal_progress(value: int, target: int) -> float:
	if target <= 0:
		return 1.0
	return clampf(float(value) / float(target), 0.0, 1.0)


## Progress toward a goal as a whole percent, 0..100.
static func goal_percent(value: int, target: int) -> int:
	return roundi(goal_progress(value, target) * 100.0)


## The first milestone in a milestone_progress list that is not done yet, or {} when all are done.
static func next_goal(progress: Array) -> Dictionary:
	for entry in progress:
		if not bool(entry.get("done", false)):
			return entry
	return {}


func apply_snapshot(s: Dictionary) -> void:
	var t := texts(s)
	var n := numbers(s)
	for c in METRICS:
		var id: String = c["id"]
		var label: Label = _values[id]
		label.text = t[id]
		if _last.has(id) and _last[id] != n[id]:
			UiFx.pop(label, UiFx.direction(int(_last[id]), int(n[id])))
		_last[id] = n[id]
	_apply_goal(s.get("milestone_progress", []))
	_apply_timeline(s)


func _apply_goal(progress: Array) -> void:
	var goal := next_goal(progress)
	if goal.is_empty():
		_goal_text.text = "すべての目標を達成しました"
		_goal_bar.value = 1.0
		_goal_percent.text = "100%"
		return
	var target := int(goal["threshold"])
	var value := int(goal["value"])
	_goal_text.text = ProgressionText.goal_text(String(goal["metric"]), target)
	_goal_text.tooltip_text = String(goal["name_ja"])
	_goal_bar.value = goal_progress(value, target)
	_goal_percent.text = "%d%%" % goal_percent(value, target)


func _apply_timeline(s: Dictionary) -> void:
	var rows := EventText.timeline(s.get("gameplay_event", {"status": "no_data"}), int(s.get("time_sec", 0)), s.get("stocked_categories", []))
	for i in _timeline.size():
		var row: Dictionary = _timeline[i]
		row["box"].visible = i < rows.size()
		if i < rows.size():
			(row["time"] as Label).text = rows[i]["time"]
			(row["time"] as Label).visible = rows[i]["time"] != ""
			(row["text"] as Label).text = rows[i]["text"]
			(row["text"] as Label).tooltip_text = rows[i]["text"]   # the full line, when the ellipsis trims it
			(row["box"] as Control).tooltip_text = rows[i]["text"]

