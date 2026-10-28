class_name ReportController
extends Node
## Daily report section of the inspector (SCR-04): the latest closed day with day-over-day change,
## plus a grouped bar chart of revenue and gross profit for the last 7 days. Reads snapshot["daily_reports"] only.

const CHART_DAYS := 7

var _label: Label
var _chart: ReportChart

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


var _detail_button: Button
var _company: Label   # #146: all stores of the company together
var _day_end: PanelContainer   # #19 SCR-13: the day's result when the date moves on
var _day_end_text: Label
var _seen_reports := -1
var _day_log := {}             # day -> {event, titles}: what each day had, gathered from the snapshots (#19)
var _done_titles = null        # completed milestone ids at the last snapshot (null before the first)


func setup(_app: Node) -> void:
	_build_day_end()
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
	_company = Label.new()
	_company.name = "CompanyTotals"
	_company.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_company)
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
		{"color": ReportChart.REVENUE, "text": "売上"},
		{"color": ReportChart.GROSS, "text": "粗利"},
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


## SCR-13 (#19): a centred card when a day closes — its sales, gross and operating profit, visitors, buyers and
## wastage from the closed report (the ledger), with 履歴を詳しく見る (the データ tab) and 翌日の経営へ (close).
func _build_day_end() -> void:
	_day_end = PanelContainer.new()
	_day_end.name = "DayEndPanel"
	_day_end.theme_type_variation = &"Card"
	_day_end.visible = false
	_day_end.custom_minimum_size = Vector2(420, 0)
	_day_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_day_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_day_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_day_end.add_child(col)
	_day_end_text = Label.new()
	_day_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_day_end_text)
	var row := HBoxContainer.new()
	var more := Button.new()
	more.name = "DayEndHistory"
	more.text = "履歴を詳しく見る"
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(func():
		_day_end.visible = false
		if get_parent().has_method("open_screen_tab"):
			get_parent().call("open_screen_tab", "データ"))
	row.add_child(more)
	var next := Button.new()
	next.name = "DayEndNext"
	next.text = "翌日の経営へ"
	next.theme_type_variation = &"PrimaryButton"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(func(): _day_end.visible = false)
	row.add_child(next)
	col.add_child(row)
	get_parent().add_child.call_deferred(_day_end)


## Gathers the day's event and the titles won since the last snapshot into _day_log (the day-end card lists them).
func _note_day(snap: Dictionary) -> void:
	var ev: Dictionary = snap.get("gameplay_event", {})
	if String(ev.get("status", "")) in ["active", "ended"]:
		_entry(int(ev["day"]))["event"] = String(ev["name_ja"])
	var done: Array = snap.get("progression", {}).get("completed_milestone_ids", [])
	if _done_titles != null:
		for m in snap.get("milestone_progress", []):
			if done.has(m["milestone_id"]) and not (_done_titles as Array).has(m["milestone_id"]):
				_entry(int(snap.get("day", 0)))["titles"].append(String(m["name_ja"]))
	_done_titles = done.duplicate()


func _entry(day: int) -> Dictionary:
	if not _day_log.has(day):
		_day_log[day] = {"event": "", "titles": []}
	return _day_log[day]


## The day's history under the result: its event, its daily challenge (achieved or not) and the titles won.
## `entry` is {event, titles} for the day; `progression` the snapshot's (completed challenge ids).
static func day_history_lines(day: int, entry: Dictionary, progression: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var ev := String(entry.get("event", ""))
	out.append("今日のイベント：%s" % (ev if ev != "" else "なし"))
	var cid := ProgressionService.challenge_for_day(day)
	if cid != "":
		var done: Array = progression.get("completed_daily_challenge_ids", [])
		var what := String(ProgressionText.CHALLENGE.get(cid, "")).trim_prefix("今日のチャレンジ: ")
		out.append("チャレンジ：%s　%s" % ["達成" if done.has(ProgressionService.challenge_event_id(day, cid)) else "未達成", what])
	var titles: Array = entry.get("titles", [])
	out.append("獲得した称号：%s" % ("、".join(titles) if not titles.is_empty() else "なし"))
	return out


## What the card says for one closed day.
static func day_end_text(r: Dictionary) -> String:
	# One row per line, joined with \n (the multi-line literal showed blank lines between the first rows on the card).
	return "\n".join(["DAY %d　営業結果", "売上高 %s", "粗利益 %s", "営業利益 %s", "今日の来店 %d人 ／ 購買 %d人 ／ 廃棄 %s"]) % [
		int(r["day_index"]), GameHud.format_yen(int(r["revenue_yen"])), GameHud.format_yen(int(r["gross_profit_yen"])),
		GameHud.format_yen(int(r["operating_profit_yen"])), int(r["visitors"]), int(r["purchasing_customers"]), GameHud.format_yen(int(r["wastage_yen"]))]


func apply_snapshot(snap: Dictionary) -> void:
	var reports: Array = snap.get("daily_reports", [])
	if _day_end != null:   # shown when exactly one more day closed (not on a load or a store switch)
		_note_day(snap)
		if _seen_reports >= 0 and reports.size() == _seen_reports + 1:
			var closed: Dictionary = reports.back()
			var day := int(closed["day_index"])
			_day_end_text.text = day_end_text(closed) + "\n" + "\n".join(day_history_lines(day, _day_log.get(day, {}), snap.get("progression", {})))
			_day_end.visible = true
		_seen_reports = reports.size()
	_label.text = summary_text(reports)
	var totals: Dictionary = snap.get("company_totals", {})
	_company.visible = not totals.is_empty()
	_company.text = company_text(totals)
	_chart.set_reports(reports.slice(maxi(reports.size() - CHART_DAYS, 0)))


static func _delta(reports: Array, key: String) -> String:
	var d = DailyReport.day_over_day(reports, key)
	if d == null:
		return "—"
	return ("+" if d >= 0 else "−") + GameHud.format_yen(absi(d))


## All stores of the company for the latest closed day (#146); "" for a one-store company. The lines below are
## the store on screen's own.
static func company_text(t: Dictionary) -> String:
	if t.is_empty():
		return ""
	return "全店合計（%d店・DAY %d）　売上 %s ／ 粗利 %s ／ 営業損益 %s ／ 販売 %d点　会社の現金 %s
（以下はこの店の数字）" % [int(t["stores"]), int(t["day_index"]),
		GameHud.format_yen(int(t["revenue_yen"])), GameHud.format_yen(int(t["gross_profit_yen"])), GameHud.format_yen(int(t["operating_profit_yen"])), int(t["units_sold"]), GameHud.format_yen(int(t["cash_yen"]))]


## Text for the latest closed day; "—" stands for anything that cannot be computed.
static func summary_text(reports: Array) -> String:
	if reports.is_empty():
		return "まだ締めた日がありません（0:00 を越えると最初の日次レポートができます）"
	var r: Dictionary = reports[reports.size() - 1]
	var margin = DailyReport.gross_margin_percent(r)
	var margin_text := "—" if margin == null else "%.1f%%" % margin
	return "DAY %d\n売上 %s（前日比 %s）\n売上原価 %s ／ 粗利 %s（粗利率 %s）\n廃棄 %s ／ 広告 %s ／ 電気 %s ／ 固定 %s ／ 人件費 %s\n営業損益 %s（前日比 %s）\n現金残高 %s（この日の増減 %s）※設備・仕入は損益に入りません\n来店希望 %d ／ 来店客数 %d ／ 購入客数 %d ／ 失客 %d（うち混雑で引き返し %d）\n販売点数 %d 点 ／ 客単価 %s（売上 ÷ 購入客数）%s" % [
		int(r["day_index"]), GameHud.format_yen(int(r["revenue_yen"])), _delta(reports, "revenue_yen"),
		GameHud.format_yen(int(r["cogs_yen"])), GameHud.format_yen(int(r["gross_profit_yen"])), margin_text,
		GameHud.format_yen(int(r["wastage_yen"])), GameHud.format_yen(int(r["advertising_yen"])),
		GameHud.format_yen(int(r["electricity_yen"])), GameHud.format_yen(int(r["fixed_cost_yen"])), GameHud.format_yen(int(r.get("wages_yen", 0))),
		GameHud.format_yen(int(r["operating_profit_yen"])), _delta(reports, "operating_profit_yen"),
		GameHud.format_yen(int(r["cash_end_yen"])), GameHud.format_yen(int(r["net_cash_delta_yen"])),
		int(r["potential_customers"]), int(r["visitors"]), int(r["purchasing_customers"]), int(r["lost_customers"]), int(r.get("balked_customers", 0)),
		int(r["units_sold"]), _unit_price_text(r),
		"
客の満足度 %d / 100（品切れ・予算オーバー・レジ待ちで下がります）" % int(r["satisfaction"]) if r.has("satisfaction") else "",
	]


## 客単価 of one closed day: revenue / buying customers, "—" when nobody bought.
static func _unit_price_text(r: Dictionary) -> String:
	var buyers := int(r["purchasing_customers"])
	return "—" if buyers <= 0 else GameHud.format_yen(int(r["revenue_yen"]) / buyers)
