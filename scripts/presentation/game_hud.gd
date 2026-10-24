class_name GameHud
extends PanelContainer
## Top HUD (mockup #105 B1). Left: time-of-day icon, DAY n, the large clock, the date and a season icon. Centre: the
## money and today's figures, each a small chip with a gold value. Right: the 営業中 badge, a pause / play button and
## the ×1 ×2 ×4 speed segments. Formats the GameState snapshot; the only thing it sends is the speed the player picked
## (`speed_requested`), which AppRoot turns into a SET_SPEED command. Today's sales / gross profit come from the ledger.

signal speed_requested(speed: int)

const NONE := "—"
const HUD_ICON_SIZE := 24
const PAUSE_ICON_SIZE := 18
const NO_CASH := -2147483648   # sentinel: no snapshot seen yet, so the first cash value does not pop
const STATE_TEXT := {
	"SETUP": "準備中", "OPEN": "営業中", "CLOSING": "閉店処理中", "PAYMENT_BLOCKED": "支払不能",
}
const SPEEDS := [1, 2, 4]

var _row: HBoxContainer
var _time_icon: TextureRect
var _day: Label
var _clock: Label
var _date: Label
var _season_icon: TextureRect
var _season: Label
var _cash: Label
var _sales: Label
var _profit: Label
var _customers: Label
var _state: Label
var _state_box: PanelContainer
var _pause: Button
var _speed: Label   # hidden: the "速度 ×4" text the mockup drops; kept so the speed text stays testable
var _speed_buttons: Dictionary = {}
var _is_open := false
var _stopped := true
var _last_cash := NO_CASH
## Game days per month for the calendar label (GameCalendar); AppRoot sets it from the balance config.
var days_per_month := GameCalendar.DEFAULT_DAYS_PER_MONTH


func _ready() -> void:
	theme_type_variation = &"TopBand"   # one translucent band across the top (no separate chips)
	_row = $Row
	_row.add_theme_constant_override("separation", 14)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_left()
	_row.add_child(_spacer())
	_build_centre()
	_row.add_child(_spacer())
	_build_right()
	for lbl in [_clock, _day, _date]:
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_left() -> void:
	_time_icon = _icon("sun")
	_row.add_child(_time_icon)
	_day = _text_label("DayLabel", &"HudDay")
	_row.add_child(_day)
	_clock = _text_label("ClockLabel", &"HudClock")
	_row.add_child(_clock)
	_date = _text_label("DateLabel", &"HudDate")
	_row.add_child(_date)
	_season_icon = _icon("sakura")
	_row.add_child(_season_icon)
	_season = _text_label("SeasonLabel", &"HudDay")   # the season word (春 夏 秋 冬) after its icon
	_row.add_child(_season)


## The centre of the band: four groups (caption, value) divided by thin rules. No chips: one strip, values in gold and green.
func _build_centre() -> void:
	var caption_value := [
		["CashGroup", "所持金", "CashLabel"], ["SalesGroup", "本日の売上", "SalesLabel"],
		["ProfitGroup", "本日の粗利", "ProfitLabel"], ["CustomersGroup", "来店客数", "CustomersLabel"],
	]
	for i in caption_value.size():
		var entry: Array = caption_value[i]
		if i > 0:
			_row.add_child(_divider())
		var line := HBoxContainer.new()
		line.name = entry[0]
		line.add_theme_constant_override("separation", 8)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := Label.new()
		caption.text = entry[1]
		caption.theme_type_variation = &"HudGroupCaption"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(caption)
		var value := Label.new()
		value.name = entry[2]
		value.theme_type_variation = value_variation(entry[2])
		value.text = NONE
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(value)
		_row.add_child(line)
		match entry[2]:
			"CashLabel": _cash = value
			"SalesLabel": _sales = value
			"ProfitLabel": _profit = value
			"CustomersLabel": _customers = value


## Gold for the money, green for the gross profit, white for the visitor count (theme variations, so the value pop keeps them).
static func value_variation(label_name: String) -> StringName:
	match label_name:
		"ProfitLabel": return &"HudProfit"
		"CustomersLabel": return &"HudCustomers"
	return &"HudCash"


func _divider() -> VSeparator:
	var rule := VSeparator.new()
	rule.custom_minimum_size = Vector2(1, 34)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _build_right() -> void:
	_state_box = PanelContainer.new()
	_state_box.name = "StateBadge"
	_state_box.theme_type_variation = &"HudChip"
	_state_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state = Label.new()
	_state.name = "StateLabel"
	_state.theme_type_variation = &"HudValue"
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_box.add_child(_state)
	_row.add_child(_state_box)
	_pause = Button.new()
	_pause.name = "PauseButton"
	_pause.theme_type_variation = &"SegmentLeft"
	_pause.icon = UiIcons.texture("pause", PAUSE_ICON_SIZE)
	_pause.expand_icon = false
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.custom_minimum_size = Vector2(44, 0)
	_pause.pressed.connect(_on_pause_pressed)
	UiFx.attach(_pause)
	_row.add_child(_pause)
	for speed in SPEEDS:
		var b := Button.new()
		b.name = "Speed%d" % speed
		b.text = speed_text(speed)
		b.theme_type_variation = &"SegmentRight" if speed == SPEEDS[-1] else &"SegmentMid"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): speed_requested.emit(speed))
		UiFx.attach(b)
		_row.add_child(b)
		_speed_buttons[speed] = b
	_speed = Label.new()
	_speed.name = "SpeedLabel"
	_speed.visible = false
	_row.add_child(_speed)


func _on_pause_pressed() -> void:
	# Stopped: the same button resumes at ×1. Running: it stops the clock.
	speed_requested.emit(1 if _stopped else 0)


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _icon(icon_name: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(icon_name, HUD_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
	icon.modulate = UiTheme.WARM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _text_label(node_name: String, variation: StringName) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.theme_type_variation = variation
	lbl.text = NONE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


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


## Time-of-day icon name for the game clock: sun from 05:00, sunset from 16:00, moon from 19:00 (until 05:00).
## Presentation only; the weather is not in the model, so there is no weather icon.
static func time_icon(time_sec: int) -> String:
	var hour := posmod(time_sec, 86400) / 3600
	if hour >= 5 and hour < 16:
		return "sun"
	if hour >= 16 and hour < 19:
		return "sunset"
	return "moon"


## Season icon name for a season word from GameCalendar: sakura in 春, leaf in 夏, maple in 秋, snowflake in 冬.
static func season_icon(season: String) -> String:
	match season:
		"春": return "sakura"
		"夏": return "leaf"
		"秋": return "maple"
	return "snowflake"


func apply_snapshot(s: Dictionary) -> void:
	var metrics: Node = find_parent("Layout").find_child("MetricBar", true, false) if find_parent("Layout") != null else null   # bottom row, inside Layout
	if metrics != null:
		metrics.apply_snapshot(s)
	# FloatCards is a child of Main, one level above Layout (where this HUD lives).
	var floats := get_node_or_null("../../FloatCards")
	if floats != null:
		floats.apply_snapshot(s)
	var cash := int(s["cash_yen"])
	_cash.text = format_yen(cash)
	if _last_cash != NO_CASH and cash != _last_cash:
		UiFx.pop(_cash, UiFx.direction(_last_cash, cash))
	_last_cash = cash
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	_sales.text = format_yen(int(today["revenue_yen"]))
	_profit.text = format_yen(int(today["gross_profit_yen"]))
	var visit: Dictionary = s.get("visit_stats", {})
	_customers.text = "%d 人" % int(visit.get("entered", 0))
	_customers.tooltip_text = "来店 %d 人 ／ 購入 %d 人 ／ 販売 %d 点" % [int(visit.get("entered", 0)), int(visit.get("purchased", 0)), int(s.get("units_sold_today", 0))]
	var day := int(s["day"])
	var time_sec := int(s["time_sec"])
	_time_icon.texture = UiIcons.texture(time_icon(time_sec), HUD_ICON_SIZE)
	_day.text = "DAY %d" % day
	_clock.text = format_clock(time_sec)
	_clock.tooltip_text = "%s（%d日目）" % [GameCalendar.label(day, days_per_month), day + 1]
	var season := GameCalendar.season_of(day, days_per_month)
	_date.text = GameCalendar.month_week_text(day, days_per_month)
	_season_icon.texture = UiIcons.texture(season_icon(season), HUD_ICON_SIZE)
	_season_icon.tooltip_text = GameCalendar.label(day, days_per_month)
	_season.text = season
	_speed.text = "速度 " + speed_text(int(s["speed_setting"]))
	_state.text = STATE_TEXT.get(s["business_state"], String(s["business_state"]))
	_is_open = s["business_state"] == "OPEN"
	_state.add_theme_color_override("font_color", Color.WHITE if _is_open else UiTheme.TEXT_SECONDARY)
	_state_box.add_theme_stylebox_override("panel", UiTheme.hud_badge_box() if _is_open else UiTheme.hud_chip_box())
	var running: bool = s["business_state"] == "OPEN" or s["business_state"] == "CLOSING"
	_stopped = int(s["speed_setting"]) == 0
	_pause.icon = UiIcons.texture("play" if _stopped else "pause", PAUSE_ICON_SIZE)
	_pause.tooltip_text = "再開 (×1)" if _stopped else "一時停止"
	_pause.disabled = not running   # SETUP has no clock; PAYMENT_BLOCKED stays stopped
	for speed in _speed_buttons:
		var b: Button = _speed_buttons[speed]
		b.button_pressed = int(s["speed_setting"]) == speed
		b.disabled = not running   # SETUP has no clock to speed up
