class_name ReportController
extends Node
## Daily report section of the inspector (SCR-04): the latest closed day with day-over-day change,
## plus a grouped bar chart of revenue and gross profit for the last 7 days. Reads snapshot["daily_reports"] only.

const CHART_DAYS := 7
const RANKING_TITLE := "売れ筋ランキング"
const RANK_ROWS := 5
const SHELF_ROWS := 3
const RANK_ICON := 28.0
const HOURLY_CAPTION := "時間帯別の売上（本日・灰色は前日）"

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
var _ranking_note: Label       # #24 売れ筋ランキング
var _rank_rows: Array = []     # per row: {box, product, amount, bar}
var _ranking_categories: Label
var _ranking_day := "today"    # which day the 売れ筋 and 棚別 rankings show: "today" / "yesterday"
var _shelf_lines: Label
var _day_buttons: Dictionary = {}   # "today" / "yesterday" -> Button
var _last_snap: Dictionary = {}
var _hourly: HourlyChart       # #19 売上の推移: today by hour, yesterday behind
var _day_end_hourly: HourlyChart   # the closed day by hour, on the day-end card


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
	var hourly_title := Label.new()
	hourly_title.text = HOURLY_CAPTION
	hourly_title.theme_type_variation = &"CardTitle"
	_body.add_child(hourly_title)
	_hourly = HourlyChart.new()
	_hourly.name = "HourlyChart"
	_hourly.custom_minimum_size = Vector2(0, 90)
	_body.add_child(_hourly)
	_build_ranking()
	apply_snapshot({})


## #24 売れ筋ランキング: today's best sellers from confirmed sales (no estimates), top RANK_ROWS with a bar each
## against the leader, then units per category.
func _build_ranking() -> void:
	var title := Label.new()
	title.text = RANKING_TITLE
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var days := HBoxContainer.new()   # 本日 / 前日: which day the ranking shows
	days.name = "RankingDays"
	var group := ButtonGroup.new()
	for d in [["today", "本日"], ["yesterday", "前日"]]:
		var b := Button.new()
		b.name = "RankingDay_" + d[0]
		b.text = d[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d[0] == _ranking_day
		b.pressed.connect(_set_ranking_day.bind(d[0]))
		days.add_child(b)
		_day_buttons[d[0]] = b
	_body.add_child(days)
	_mark_ranking_day()
	_ranking_note = Label.new()
	_ranking_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_ranking_note)
	for i in RANK_ROWS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var rank := Label.new()
		rank.text = "%d" % (i + 1)
		rank.custom_minimum_size.x = 22
		rank.theme_type_variation = &"AccentLabel" if i == 0 else &"MutedLabel"
		var product := Label.new()
		product.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		product.clip_text = true
		var amount := Label.new()
		var icon := TextureRect.new()   # the product's icon, as on the 販売価格 card
		icon.name = "RankIcon"
		icon.custom_minimum_size = Vector2(RANK_ICON, RANK_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rank)
		row.add_child(icon)
		row.add_child(product)
		row.add_child(amount)
		box.add_child(row)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0   # exact shares of the leader
		bar.custom_minimum_size.y = UiTheme.BAR_HEIGHT
		box.add_child(bar)
		_body.add_child(box)
		_rank_rows.append({"box": box, "product": product, "amount": amount, "bar": bar, "icon": icon})
	_ranking_categories = Label.new()
	_ranking_categories.name = "RankingCategories"
	_ranking_categories.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_ranking_categories)
	var shelves_title := Label.new()
	shelves_title.text = "棚別売上"
	shelves_title.theme_type_variation = &"CardTitle"
	_body.add_child(shelves_title)
	_shelf_lines = Label.new()
	_shelf_lines.name = "ShelfRanking"
	_shelf_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_shelf_lines)


func _set_ranking_day(which: String) -> void:
	_ranking_day = which
	_mark_ranking_day()
	if not _last_snap.is_empty():
		_render_rankings(_last_snap)


## The day shown is the one in orange (the toggle's pressed look alone was hard to read).
func _mark_ranking_day() -> void:
	for k in _day_buttons:
		var b: Button = _day_buttons[k]
		b.theme_type_variation = &"SelectedButton" if k == _ranking_day else &""


func _render_rankings(snap: Dictionary) -> void:
	var y := _ranking_day == "yesterday"
	_render_ranking(snap.get("best_sellers_yesterday" if y else "best_sellers_today", []))
	_shelf_lines.text = shelf_lines(snap.get("shelf_ranking", {}).get(_ranking_day, []))


## 棚別売上 rows, highest first: '1  汎用棚（3,2）　¥1,200・8個'. "" (no rows) when nothing sold.
static func shelf_lines(shelves: Array) -> String:
	var lines: Array[String] = []
	for i in mini(shelves.size(), SHELF_ROWS):
		var s: Dictionary = shelves[i]
		var at := "（%d,%d）" % [int(s["x"]), int(s["y"])] if int(s["x"]) >= 0 else ""
		lines.append("%d  %s%s　%s・%d個" % [i + 1, s["name"], at, GameHud.format_yen(int(s["revenue_yen"])), int(s["qty"])])
	return "\n".join(lines) if not lines.is_empty() else "まだ売れた棚がありません"


func _render_ranking(sellers: Array) -> void:
	if _ranking_note == null:
		return
	var y := _ranking_day == "yesterday"
	_ranking_note.text = ("前日" if y else "本日") + "・確定した会計から" if not sellers.is_empty() else ("前日は商品が売れていません" if y else "今日はまだ商品が売れていません")
	var top := int(sellers[0]["qty"]) if not sellers.is_empty() else 1
	for i in _rank_rows.size():
		var view: Dictionary = _rank_rows[i]
		view["box"].visible = i < sellers.size()
		if i >= sellers.size():
			continue
		var s: Dictionary = sellers[i]
		view["product"].text = String(s["name"])
		view["icon"].texture = ProductIcons.texture({"sku_id": s["sku_id"], "category": s["category"], "display_name": s["name"]}, int(RANK_ICON))
		view["amount"].text = "%d個　%s" % [int(s["qty"]), GameHud.format_yen(int(s["revenue_yen"]))]
		view["bar"].value = float(s["qty"]) / float(maxi(top, 1))
	_ranking_categories.text = category_line(sellers)
	_ranking_categories.visible = not sellers.is_empty()


## 'カテゴリ別：おかし 12・飲料 8' — units per category today, most first (ties keep the ranking order).
static func category_line(sellers: Array) -> String:
	var units := {}
	var order: Array[String] = []
	for s in sellers:
		var c := String(s.get("category", ""))
		if not units.has(c):
			units[c] = 0
			order.append(c)
		units[c] += int(s["qty"])
	var idx := range(order.size())
	idx.sort_custom(func(a, b): return units[order[a]] > units[order[b]] if units[order[a]] != units[order[b]] else a < b)
	var parts: Array[String] = []
	for i in idx:
		parts.append("%s %d" % [FixtureCard.CATEGORY_NAMES.get(order[i], order[i]), int(units[order[i]])])
	return "カテゴリ別：" + "・".join(parts) if not parts.is_empty() else ""


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
	_day_end_hourly = HourlyChart.new()
	_day_end_hourly.name = "DayEndHourly"
	_day_end_hourly.custom_minimum_size = Vector2(0, 80)
	col.add_child(_day_end_hourly)
	var row := HBoxContainer.new()
	var more := Button.new()
	more.name = "DayEndHistory"
	more.text = "履歴を詳しく見る"
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(func():
		_close_day_end()
		if get_parent().has_method("open_screen_tab"):
			get_parent().call("open_screen_tab", "データ"))
	row.add_child(more)
	var next := Button.new()
	next.name = "DayEndNext"
	next.text = "翌日の経営へ"
	next.theme_type_variation = &"PrimaryButton"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_close_day_end)
	row.add_child(next)
	col.add_child(row)
	get_parent().add_child.call_deferred(_day_end)


func _close_day_end() -> void:
	_day_end.visible = false
	var guide := get_node_or_null("../ProgressionController")
	if guide != null and guide.has_method("end_day_end"):
		guide.end_day_end()


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


## The データ tab's mockup page (MockDataPage), fed with every snapshot once MainLayout has set it.
var mockup_page: MockDataPage


func apply_snapshot(snap: Dictionary) -> void:
	if mockup_page != null:
		mockup_page.apply_snapshot(snap)
	var reports: Array = snap.get("daily_reports", [])
	if _day_end != null:   # shown when exactly one more day closed (not on a load or a store switch)
		_note_day(snap)
		if _seen_reports >= 0 and reports.size() == _seen_reports + 1:
			var closed: Dictionary = reports.back()
			var day := int(closed["day_index"])
			_day_end_text.text = day_end_text(closed) + "\n" + "\n".join(day_history_lines(day, _day_log.get(day, {}), snap.get("progression", {})))
			_day_end.visible = true
			var closed_hours: Array = snap.get("hourly_sales", {}).get("yesterday", []) if day == int(snap.get("day", 0)) - 1 else []
			_day_end_hourly.set_hours(closed_hours)
			_day_end_hourly.visible = not closed_hours.is_empty()
			var guide := get_node_or_null("../ProgressionController")   # 小春六花 comments on the day beside the card
			if guide != null and guide.has_method("say_day_end"):
				guide.say_day_end(ProgressionText.day_end_remark(reports), ProgressionText.day_end_mood(closed))
		_seen_reports = reports.size()
	_label.text = summary_text(reports)
	_last_snap = snap
	_render_rankings(snap)
	var hourly: Dictionary = snap.get("hourly_sales", {})
	_hourly.set_hours(hourly.get("today", []), hourly.get("yesterday", []))
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
