class_name MetricBar
extends Control
## Bottom summary (mockup #105 B5): three floating groups in one centred row. Left: 本日の目標 (the first milestone not
## yet reached, with a progress bar and a %). Centre: 本日の売上 / 本日の粗利 / 来店客数 / 客単価 (売上 ÷ 購入客数, "—"
## with no purchases). Right: 本日のイベント, today's event as a short timeline. Display only, fed by the same snapshot as
## the top HUD. The row takes no mouse input; only the cards stop it. Repeat rate is not in the model, so it is not shown.
## A changed number pops (presentation only).

const METRICS := [
	{"id": "sales", "title": "本日の売上", "icon": "cart", "tint": UiTheme.INFO_CYAN},
	{"id": "profit", "title": "本日の粗利", "icon": "bar-chart", "tint": UiTheme.SUCCESS_GREEN},
	{"id": "customers", "title": "来店客数", "icon": "users", "tint": UiTheme.WARM},
	{"id": "unit_price", "title": "客単価", "tip": "売上 ÷ 購入客数", "icon": "tag", "tint": Color("ff7a9c")},
]
const HEIGHT := 96          # card height (the summary strip is this plus the gap under it, see MainLayout.BOTTOM_HEIGHT)
const GAP := 12             # space between the groups
const GOAL_WIDTH := 216     # 216 + 4 x 180 + 272 + the gaps = 1256 px: the whole strip fits a 1280 px window
const EVENT_WIDTH := 272
const METRIC_MIN := 180     # each of the four metric cards (min width; the row never stretches them)
const ICON_SIZE := 20
const BADGE_SIZE := 36
const TIMELINE_ROWS := 3
const NONE := "—"

var _values: Dictionary = {}   # id -> value Label
var _last: Dictionary = {}     # id -> last number shown (ints), for the pop
var _goal_text: Label
var _goal_bar: ProgressBar
var _goal_percent: Label
var _timeline: Array = []      # per row: {box, time, text}


func _ready() -> void:
	name = "MetricBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(_goal_card())
	var metrics := HBoxContainer.new()
	metrics.name = "Metrics"
	metrics.add_theme_constant_override("separation", 8)
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_heading("本日のイベント", "star", UiTheme.WARM))
	for i in TIMELINE_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(line)
		var time := Label.new()
		time.theme_type_variation = &"CardTitle"
		time.add_theme_color_override("font_color", UiTheme.WARM)
		time.custom_minimum_size.x = 40
		line.add_child(time)
		var text := Label.new()
		text.clip_text = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		line.add_child(text)
		_timeline.append({"box": line, "time": time, "text": text})
	return card


func _summary_card(card_name: String, width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.theme_type_variation = &"SummaryCard"
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(width, HEIGHT)
	return card


## A card heading: a small icon and a warm title in one row.
func _heading(title: String, icon_name: String, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(icon_name, ICON_SIZE - 4)
	icon.custom_minimum_size = Vector2(ICON_SIZE - 4, ICON_SIZE - 4)
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


## One metric card: badge | title over value | (sales) sparkline.
func _add_metric(row: HBoxContainer, c: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "Metric_" + c["id"]
	card.theme_type_variation = &"SummaryCard"
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(METRIC_MIN, HEIGHT)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UiTheme.SPACE_S)
	card.add_child(line)
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UiTheme.badge_circle(c["tint"], BADGE_SIZE / 2))
	line.add_child(badge)
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
	badge.add_child(icon)
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

