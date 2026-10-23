class_name GameHud
extends PanelContainer
## Top HUD (04 §1). Formats the GameState snapshot; the only thing it sends is the speed the
## player picked (`speed_requested`), which AppRoot turns into a SET_SPEED command.
## Today's sales / gross profit come from the ledger rows of the current day.

signal speed_requested(speed: int)

const NONE := "—"
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
var _speed_buttons: Dictionary = {}


func _ready() -> void:
	var row: HBoxContainer = $Row
	var anchor := _speed.get_index()
	for lbl in [_cash, _sales, _profit, _customers, _clock, _speed, _state]:
		lbl.theme_type_variation = &"HudValue"
	for speed in [0, 1, 2, 4]:
		var b := Button.new()
		b.text = speed_text(speed)
		b.theme_type_variation = &"HudSpeedButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): speed_requested.emit(speed))
		row.add_child(b)
		row.move_child(b, anchor + 1 + _speed_buttons.size())
		_speed_buttons[speed] = b


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


func apply_snapshot(s: Dictionary) -> void:
	var metrics := get_node_or_null("../MetricBar")
	if metrics != null:
		metrics.apply_snapshot(s)
	_cash.text = "所持金 " + format_yen(int(s["cash_yen"]))
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	_sales.text = "本日の売上 " + format_yen(int(today["revenue_yen"]))
	_profit.text = "本日の粗利 " + format_yen(int(today["gross_profit_yen"]))
	_customers.text = "店内客 %d" % s.get("customers", []).size()
	var day := int(s["day"])
	_clock.text = "DAY %d  %s" % [day, format_clock(int(s["time_sec"]))]
	_clock.tooltip_text = "%s（%d日目）" % [weekday_text(day), day + 1]
	_speed.text = "速度 " + speed_text(int(s["speed_setting"]))
	_state.text = STATE_TEXT.get(s["business_state"], String(s["business_state"]))
	var running: bool = s["business_state"] == "OPEN" or s["business_state"] == "CLOSING"
	for speed in _speed_buttons:
		var b: Button = _speed_buttons[speed]
		b.button_pressed = int(s["speed_setting"]) == speed
		b.disabled = not running and speed != 0   # SETUP has no clock; PAYMENT_BLOCKED stays stopped
