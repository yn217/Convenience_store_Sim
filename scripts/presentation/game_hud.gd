class_name GameHud
extends PanelContainer
## Top HUD (04 §1). Formats the GameState snapshot; the only thing it sends is the speed the
## player picked (`speed_requested`), which AppRoot turns into a SET_SPEED command.
## Today's sales / gross profit come from the ledger rows of the current day.

signal speed_requested(speed: int)

const NONE := "—"
const HUD_ICON_SIZE := 22
const NO_CASH := -2147483648   # sentinel: no snapshot seen yet, so the first cash value does not pop
## (month, days) in calendar order from April; the sum is the 365-day year.
const CALENDAR := [[4, 30], [5, 31], [6, 30], [7, 31], [8, 31], [9, 30], [10, 31], [11, 30], [12, 31], [1, 31], [2, 28], [3, 31]]
const STATE_TEXT := {
	"SETUP": "準備中", "OPEN": "営業中", "CLOSING": "閉店処理中", "PAYMENT_BLOCKED": "支払不能",
}

@onready var _cash: Label = $Row/CashLabel
@onready var _sales: Label = $Row/SalesLabel
@onready var _profit: Label = $Row/ProfitLabel
@onready var _customers: Label = $Row/CustomersLabel
@onready var _clock: Label = $Row/ClockLabel
@onready var _speed: Label = $Row/SpeedLabel
@onready var _state: Label = $Row/StateLabel
var _date: Label
var _speed_buttons: Dictionary = {}
var _is_open := false
var _last_cash := NO_CASH


func _ready() -> void:
	var row: HBoxContainer = $Row
	_date = Label.new()
	_date.name = "DateLabel"
	row.add_child(_date)
	row.move_child(_date, _clock.get_index() + 1)
	var anchor := _speed.get_index()
	for lbl in [_sales, _profit, _customers, _clock, _date, _speed, _state]:
		lbl.theme_type_variation = &"HudValue"
	_cash.theme_type_variation = &"HudCash"
	for speed in [0, 1, 2, 4]:
		var b := Button.new()
		b.text = speed_text(speed)
		b.theme_type_variation = &"SegmentLeft" if speed == 0 else (&"SegmentRight" if speed == 4 else &"SegmentMid")
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): speed_requested.emit(speed))
		UiFx.attach(b)
		row.add_child(b)
		row.move_child(b, anchor + 1 + _speed_buttons.size())
		_speed_buttons[speed] = b
	# Icons sit in their own TextureRects right before each value label; the label texts stay as they are.
	for pair in [[_cash, "cash"], [_sales, "cart"], [_profit, "bar-chart"], [_customers, "users"]]:
		_add_icon_before(pair[0], pair[1])
	# The chips are painted by the row itself, behind its children, so the labels keep their places in the tree.
	row.draw.connect(_draw_chips.bind(row))
	row.sort_children.connect(row.queue_redraw)


## Chip groups as [icon, value] or [value, value] node names, in row order. Each group gets one pill behind it.
const CHIP_GROUPS := [
	["CashLabelIcon", "CashLabel"], ["SalesLabelIcon", "SalesLabel"], ["ProfitLabelIcon", "ProfitLabel"],
	["CustomersLabelIcon", "CustomersLabel"], ["ClockLabel", "DateLabel"],
]


## Paints the pills: one per CHIP_GROUPS entry, and a green badge around the state label while the shop is open.
func _draw_chips(row: Control) -> void:
	for names in CHIP_GROUPS:
		var rect := _group_rect(row, names)
		if rect.size.x > 0.0:
			row.draw_style_box(UiTheme.chip_box(), rect)
	var state_rect := _group_rect(row, ["StateLabel"])
	if state_rect.size.x > 0.0:
		row.draw_style_box(UiTheme.badge_box() if _is_open else UiTheme.chip_box(), state_rect)


func _group_rect(row: Control, names: Array) -> Rect2:
	var rect := Rect2()
	var first := true
	for node_name in names:
		var c := row.get_node_or_null(node_name) as Control
		if c == null or not c.is_visible_in_tree():
			continue
		rect = c.get_rect() if first else rect.merge(c.get_rect())
		first = false
	return rect.grow_individual(8, 4, 8, 4) if not first else Rect2()


func _add_icon_before(label: Label, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.name = label.name + "Icon"
	icon.texture = UiIcons.texture(icon_name, HUD_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
	icon.modulate = UiTheme.WARM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.get_parent().add_child(icon)
	label.get_parent().move_child(icon, label.get_index())


static func format_yen(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-¥" if amount < 0 else "¥") + out


static func format_clock(time_sec: int) -> String:
	var t := time_sec % 86400
	return "%02d:%02d" % [t / 3600, (t % 3600) / 60]


static func speed_text(speed: int) -> String:
	return "停止" if speed == 0 else "×%d" % speed


## Day 0 is a Monday (the game calendar starts on 月曜日).
static func weekday_text(day: int) -> String:
	const NAMES := ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"]
	return NAMES[posmod(day, 7)]


## Calendar date for the mockup HUD, e.g. "春 4月1日(月)". DAY 0 is 4月1日 of a non-leap 365-day year;
## the weekday comes from weekday_text so both labels agree. Pure: no randomness, no state.
static func date_text(day: int) -> String:
	var rest := posmod(day, 365)
	for entry in CALENDAR:
		var month: int = entry[0]
		var length: int = entry[1]
		if rest < length:
			return "%s %d月%d日(%s)" % [season_text(month), month, rest + 1, weekday_text(day).substr(0, 1)]
		rest -= length
	return ""


static func season_text(month: int) -> String:
	if month >= 3 and month <= 5:
		return "春"
	if month >= 6 and month <= 8:
		return "夏"
	if month >= 9 and month <= 11:
		return "秋"
	return "冬"


func apply_snapshot(s: Dictionary) -> void:
	var metrics: Node = find_parent("Layout").find_child("MetricBar", true, false) if find_parent("Layout") != null else null   # bottom row, inside Layout
	if metrics != null:
		metrics.apply_snapshot(s)
	# FloatCards is a child of Main, one level above Layout (where this HUD lives).
	var floats := get_node_or_null("../../FloatCards")
	if floats != null:
		floats.apply_snapshot(s)
	var cash := int(s["cash_yen"])
	_cash.text = "所持金 " + format_yen(cash)
	if _last_cash != NO_CASH and cash != _last_cash:
		UiFx.pop(_cash, UiFx.direction(_last_cash, cash))
	_last_cash = cash
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	_sales.text = "本日の売上 " + format_yen(int(today["revenue_yen"]))
	_profit.text = "本日の粗利 " + format_yen(int(today["gross_profit_yen"]))
	_customers.text = "店内客 %d" % s.get("customers", []).size()
	var day := int(s["day"])
	_clock.text = "DAY %d  %s" % [day, format_clock(int(s["time_sec"]))]
	_clock.tooltip_text = "%s（%d日目）" % [weekday_text(day), day + 1]
	_date.text = date_text(day)
	_speed.text = "速度 " + speed_text(int(s["speed_setting"]))
	_state.text = STATE_TEXT.get(s["business_state"], String(s["business_state"]))
	_is_open = s["business_state"] == "OPEN"
	_state.add_theme_color_override("font_color", Color.WHITE if _is_open else UiTheme.TEXT_SECONDARY)
	($Row as Control).queue_redraw()
	var running: bool = s["business_state"] == "OPEN" or s["business_state"] == "CLOSING"
	for speed in _speed_buttons:
		var b: Button = _speed_buttons[speed]
		b.button_pressed = int(s["speed_setting"]) == speed
		b.disabled = not running and speed != 0   # SETUP has no clock; PAYMENT_BLOCKED stays stopped
