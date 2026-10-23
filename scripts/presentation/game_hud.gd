class_name GameHud
extends PanelContainer
## Top HUD (04 §1). Read-only: formats the GameState snapshot, never changes state.
## Values the Domain does not produce yet (sales, gross profit, customers) show "—"
## instead of a made-up number.

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


func apply_snapshot(s: Dictionary) -> void:
	_cash.text = "所持金 " + format_yen(int(s["cash_yen"]))
	_sales.text = "本日の売上 " + NONE
	_profit.text = "本日の粗利 " + NONE
	_customers.text = "店内客 " + NONE
	_clock.text = "DAY %d  %s" % [int(s["day"]), format_clock(int(s["time_sec"]))]
	_speed.text = "速度 " + speed_text(int(s["speed_setting"]))
	_state.text = STATE_TEXT.get(s["business_state"], String(s["business_state"]))
