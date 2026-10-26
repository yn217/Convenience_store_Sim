class_name MediaController
extends Node
## 媒体広告 card (issue #136): the four media (what they are good at, setup cost, cost per day, lead time) with 予約
## (their default days; web ads with the chosen budget and target category), and the campaigns with their state,
## money spent and today's estimated lift, 取消 before they start. Presentation only: BOOK_CAMPAIGN /
## CANCEL_CAMPAIGN go through AppRoot; everything shown comes from the snapshot. Lifts are estimates.

const TITLE := "媒体広告"
const PHASES := {"booked": "予約済み", "airing": "放映・掲載中", "fading": "終了（余韻あり）", "ended": "終了", "cancelled": "取消"}
const ERRORS := {"not_enough_cash": "現金が足りません", "too_many_campaigns": "同時に4件までです", "days_invalid": "日数が範囲外です",
	"budget_invalid": "予算が範囲外です", "campaign_started": "始まった広告は取り消せません", "unknown_campaign": "広告がありません",
	"unknown_medium": "媒体がありません", "unknown_category": "分類がありません"}

var _app: Node
var _seq := 0
var _box: VBoxContainer
var _list: VBoxContainer
var _status: Label
var _budget: OptionButton
var _target: OptionButton
var _rows_key := []
var _labels: Dictionary = {}


@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node) -> void:
	_app = app
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var hint := _label()
	hint.text = "予約すると準備費をすぐ払い、準備日数のあとに始まります。掲載中は毎日費用がかかり、効果は少しずつ上がって終わったあとも少し残ります（効果は推定）。"
	_box = VBoxContainer.new()
	_body.add_child(_box)
	for m in Marketing.data()["media"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = medium_line(m)
		row.add_child(l)
		var b := Button.new()
		b.name = "Book_" + String(m["medium"])
		b.text = "予約"
		b.pressed.connect(book.bind(String(m["medium"]), int(m["default_days"])))
		row.add_child(b)
		_box.add_child(row)
		if m["medium"] == "web_ads":
			var opts := HBoxContainer.new()
			_budget = OptionButton.new()
			_budget.name = "WebBudget"
			for yen in [300, 1000, 3000]:
				_budget.add_item("1日 %s" % OverlayModel.yen(yen))
				_budget.set_item_metadata(_budget.item_count - 1, yen)
			_budget.select(1)
			opts.add_child(_budget)
			_target = OptionButton.new()
			_target.name = "WebTarget"
			_target.add_item("分類指定なし")
			_target.set_item_metadata(0, "")
			for cat in ProductCatalog.CATEGORIES:
				_target.add_item(SignLayer.LABELS.get(cat, cat))
				_target.set_item_metadata(_target.item_count - 1, cat)
			opts.add_child(_target)
			_box.add_child(opts)
	_list = VBoxContainer.new()
	_body.add_child(_list)
	_status = _label()


func _label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func apply_snapshot(snap: Dictionary) -> void:
	if _list == null:
		return
	var mk: Dictionary = snap.get("marketing", {})
	var camps: Array = mk.get("campaigns", [])
	var key := camps.map(func(c): return [c["campaign_id"], c["phase"]])
	if key != _rows_key:
		_rows_key = key
		for n in _list.get_children():
			n.queue_free()
		_labels.clear()
		for c in camps.slice(0, 6):
			var row := HBoxContainer.new()
			var l := Label.new()
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
			_labels[c["campaign_id"]] = l
			if c["phase"] == "booked":
				var x := Button.new()
				x.name = "Cancel_" + String(c["campaign_id"])
				x.text = "取消"
				x.pressed.connect(cancel.bind(String(c["campaign_id"])))
				row.add_child(x)
			_list.add_child(row)
	for c in camps.slice(0, 6):
		var l: Label = _labels.get(c["campaign_id"])
		if l != null:
			l.text = campaign_line(c)


func book(medium_id: String, days: int) -> CommandResult:
	_seq += 1
	var cmd := {"command_id": "ui_media_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"BOOK_CAMPAIGN", "medium": medium_id, "days": days}
	if medium_id == "web_ads" and _budget != null:
		cmd["daily_budget_yen"] = int(_budget.get_item_metadata(_budget.selected))
		cmd["category"] = String(_target.get_item_metadata(_target.selected))
	var r: CommandResult = _app.run_command(cmd)
	_status.text = "%sを予約しました。" % Marketing.medium(medium_id).get("display_name", "") if r.ok else "予約できません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


func cancel(campaign_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_media_x_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"CANCEL_CAMPAIGN", "campaign_id": campaign_id})
	_status.text = "取り消しました（準備費は戻りません）。" if r.ok else "取り消せません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


static func medium_line(m: Dictionary) -> String:
	var per := "1日 %s" % OverlayModel.yen(int(m["cost_per_day_yen"])) if m["medium"] != "web_ads" else "1日の予算 %s〜%s" % [OverlayModel.yen(int(m["budget_min_yen"])), OverlayModel.yen(int(m["budget_max_yen"]))]
	return "%s　%s\n準備費 %s　%s　%d日後から%d日間（%d〜%d日）" % [m["display_name"], m["note"], OverlayModel.yen(int(m["setup_cost_yen"])), per,
		int(m["lead_days"]), int(m["default_days"]), int(m["min_days"]), int(m["max_days"])]


static func campaign_line(c: Dictionary) -> String:
	var target := "（%s）" % SignLayer.LABELS.get(c["category"], c["category"]) if String(c.get("category", "")) != "" else ""
	return "%s%s　%s　DAY %d〜%d　費用 %s　今の効果 推定+%d%%" % [c["display_name"], target, PHASES.get(c["phase"], c["phase"]),
		int(c["start_day"]), int(c["end_day"]), OverlayModel.yen(int(c["spent_yen"])), int(round(float(c["lift_now"]) * 100.0))]
