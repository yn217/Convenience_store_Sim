class_name MetricBar
extends Control
## Bottom summary: four floating cards in one centred row (docs/qa/UI_ARCHITECTURE.md). Each card has a round icon
## badge on the left, a small title above a big outlined value, and (sales only) a tiny sparkline on the right.
## Sales, profit, customers in store, customer satisfaction (客層満足度, a percent derived from reputation). Display
## only; fed by the same snapshot as the top HUD. The row takes no mouse input; only the cards stop it.
## Game look (#61): a changed number pops, and the sales card keeps a sparkline of its last HISTORY publishes
## (a ring buffer, presentation only; it restarts when the day changes).

const CARDS := [
	{"id": "sales", "title": "本日の売上", "icon": "cart", "tint": UiTheme.INFO_CYAN},
	{"id": "profit", "title": "本日の粗利", "icon": "bar-chart", "tint": UiTheme.SUCCESS_GREEN},
	{"id": "customers", "title": "店内客", "icon": "users", "tint": UiTheme.WARM},
	{"id": "satisfaction", "title": "客層満足度", "tip": "評判から算出", "icon": "heart", "tint": Color("ff7a9c")},
]
const HEIGHT := 64          # card height
const GAP := 12             # space between cards
const CARD_MIN := 170       # narrowest card (the row shrinks cards down to this)
const CARD_MAX := 220       # widest card (the row never stretches them past this)
const ICON_SIZE := 20
const BADGE_SIZE := 36
const SPARK_SIZE := Vector2(40, 22)
const HISTORY := 24

var _values: Dictionary = {}   # id -> value Label
var _last: Dictionary = {}     # id -> last number shown (ints), for the pop
var _cards: Array[PanelContainer] = []
var _spark: Spark
var _samples := PackedFloat32Array()
var _head := 0
var _count := 0
var _day := -1


## Sparkline of today's sales: draws the ring buffer oldest to newest. Redrawn only when a snapshot arrives.
class Spark extends Control:
	var samples := PackedFloat32Array()
	var head := 0
	var count := 0
	var tint := UiTheme.INFO_CYAN

	func _ready() -> void:
		custom_minimum_size = SPARK_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := samples.size()
		if count < 2 or n == 0:
			return
		var lo := INF
		var hi := -INF
		for i in count:
			var v := samples[(head - count + i + n) % n]
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var span := maxf(hi - lo, 1.0)
		var points := PackedVector2Array()
		for i in count:
			var v := samples[(head - count + i + n) % n]
			var x := size.x * float(i) / float(count - 1)
			var y := size.y - 2.0 - (size.y - 4.0) * (v - lo) / span
			points.append(Vector2(x, y))
		draw_polyline(points, Color(tint, 0.9), 2.0, true)
		draw_circle(points[points.size() - 1], 2.5, tint)


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
	_samples.resize(HISTORY)
	for c in CARDS:
		_add_card(row, c)
	_fit_cards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_cards()


## One floating card: badge | title over value | (sales) sparkline.
func _add_card(row: HBoxContainer, c: Dictionary) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SummaryCard"
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(CARD_MIN, HEIGHT)
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
	value.text = "—"
	value.clip_text = true
	if c.has("tip"):
		value.tooltip_text = c["tip"]
	box.add_child(value)
	if c["id"] == "sales":
		_spark = Spark.new()
		_spark.tint = c["tint"]
		_spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(_spark)
	row.add_child(card)
	_cards.append(card)
	_values[c["id"]] = value


## The cards share the row width: each gets an equal slice, kept between CARD_MIN and CARD_MAX so the group stays
## compact and centred instead of stretching across the window.
func _fit_cards() -> void:
	if _cards.is_empty():
		return
	var free := size.x - GAP * (_cards.size() - 1)
	var width := clampf(floorf(free / _cards.size()), CARD_MIN, CARD_MAX)
	for card in _cards:
		card.custom_minimum_size.x = width


static func texts(s: Dictionary) -> Dictionary:
	var n := numbers(s)
	return {
		"sales": GameHud.format_yen(n["sales"]),
		"profit": GameHud.format_yen(n["profit"]),
		"customers": "%d 人" % n["customers"],
		"satisfaction": "%d%%" % n["satisfaction"],
	}


## The numbers behind the card texts (ints), so a change can be detected without comparing strings.
static func numbers(s: Dictionary) -> Dictionary:
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	return {
		"sales": int(today["revenue_yen"]),
		"profit": int(today["gross_profit_yen"]),
		"customers": s.get("customers", []).size(),
		"satisfaction": satisfaction_percent(int(s.get("reputation", 0))),
	}


## Reputation is already a 0..100 score (see ReputationModel), so the percent is the clamped value.
static func satisfaction_percent(rep: int) -> int:
	return clampi(rep, 0, 100)


func apply_snapshot(s: Dictionary) -> void:
	var t := texts(s)
	var n := numbers(s)
	for id in _values:
		var label: Label = _values[id]
		label.text = t[id]
		if _last.has(id) and _last[id] != n[id]:
			UiFx.pop(label, UiFx.direction(int(_last[id]), int(n[id])))
		_last[id] = n[id]
	_push_sample(int(s.get("day", 0)), float(n["sales"]))


## Ring buffer of today's sales, one sample per snapshot. A new day clears it.
func _push_sample(day: int, revenue: float) -> void:
	if _spark == null:
		return
	if day != _day:
		_day = day
		_count = 0
		_head = 0
	_samples[_head] = revenue
	_head = (_head + 1) % HISTORY
	_count = mini(_count + 1, HISTORY)
	_spark.samples = _samples
	_spark.head = _head
	_spark.count = _count
	_spark.queue_redraw()
