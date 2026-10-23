class_name ReportController
extends Node
## Daily report section of the inspector (SCR-04): the latest closed day with day-over-day change,
## plus a bar chart of operating profit for the last 7 days. Reads snapshot["daily_reports"] only.

const CHART_DAYS := 7

var _label: Label
var _chart: ReportChart

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


var _detail_button: Button


func setup(_app: Node) -> void:
	var title := Label.new()
	title.text = "日次レポート"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var head := HBoxContainer.new()   # the 詳細 toggle sits on the row under the title, at the right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_detail_button = Button.new()
	_detail_button.text = "詳細"
	_detail_button.toggle_mode = true
	_detail_button.button_pressed = true
	_detail_button.add_theme_font_size_override("font_size", 13)
	_detail_button.toggled.connect(func(shown: bool): _label.visible = shown)
	head.add_child(_detail_button)
	_body.add_child(head)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_label)
	_chart = ReportChart.new()
	_chart.custom_minimum_size = Vector2(0, 90)
	_body.add_child(_chart)
	_body.add_child(_legend())
	apply_snapshot({})


## Colour key for the chart bars: the same colours ReportChart draws with.
static func legend_entries() -> Array[Dictionary]:
	return [
		{"color": ReportChart.UP, "text": "営業損益（黒字）"},
		{"color": ReportChart.DOWN, "text": "営業損益（赤字）"},
	]


func _legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	for entry in legend_entries():
		var dot := ColorRect.new()
		dot.color = entry["color"]
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var text := Label.new()
		text.text = entry["text"]
		text.add_theme_font_size_override("font_size", 12)
		row.add_child(text)
	return row


func apply_snapshot(snap: Dictionary) -> void:
	var reports: Array = snap.get("daily_reports", [])
	_label.text = summary_text(reports)
	_chart.set_reports(reports.slice(maxi(reports.size() - CHART_DAYS, 0)))


static func _delta(reports: Array, key: String) -> String:
	var d = DailyReport.day_over_day(reports, key)
	if d == null:
		return "—"
	return ("+" if d >= 0 else "−") + GameHud.format_yen(absi(d))


## Text for the latest closed day; "—" stands for anything that cannot be computed.
static func summary_text(reports: Array) -> String:
	if reports.is_empty():
		return "まだ締めた日がありません（0:00 を越えると最初の日次レポートができます）"
	var r: Dictionary = reports[reports.size() - 1]
	var margin = DailyReport.gross_margin_percent(r)
	var margin_text := "—" if margin == null else "%.1f%%" % margin
	return "DAY %d\n売上 %s（前日比 %s）\n売上原価 %s ／ 粗利 %s（粗利率 %s）\n廃棄 %s ／ 広告 %s ／ 電気 %s ／ 固定 %s\n営業損益 %s（前日比 %s）\n現金残高 %s（この日の増減 %s）※設備・仕入は損益に入りません\n来店希望 %d ／ 入店 %d ／ 購入 %d ／ 失客 %d ／ 販売 %d 個" % [
		int(r["day_index"]), GameHud.format_yen(int(r["revenue_yen"])), _delta(reports, "revenue_yen"),
		GameHud.format_yen(int(r["cogs_yen"])), GameHud.format_yen(int(r["gross_profit_yen"])), margin_text,
		GameHud.format_yen(int(r["wastage_yen"])), GameHud.format_yen(int(r["advertising_yen"])),
		GameHud.format_yen(int(r["electricity_yen"])), GameHud.format_yen(int(r["fixed_cost_yen"])),
		GameHud.format_yen(int(r["operating_profit_yen"])), _delta(reports, "operating_profit_yen"),
		GameHud.format_yen(int(r["cash_end_yen"])), GameHud.format_yen(int(r["net_cash_delta_yen"])),
		int(r["potential_customers"]), int(r["visitors"]), int(r["purchasing_customers"]), int(r["lost_customers"]), int(r["units_sold"]),
	]
