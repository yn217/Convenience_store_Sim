class_name PromotionController
extends Node
## 販促 card (issue #137): every promotion with its setup cost, 開始 (for its default days) or 終了 while it runs,
## and the results so far (units sold on the deal, discount given). Presentation only: START_PROMOTION /
## STOP_PROMOTION go through AppRoot; everything shown comes from the snapshot.

const TITLE := "販促"

var _app: Node
var _seq := 0
var _box: VBoxContainer
var _status: Label
var _rows_key := []
var _labels: Dictionary = {}   # def id -> Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node) -> void:
	_app = app
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var hint := _label()
	hint.text = "セールは値段を下げて買う気を上げます（客数は増えません）。セットは対象を両方買った客から割り引きます。"
	_box = VBoxContainer.new()
	_body.add_child(_box)
	_status = _label()


func _label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func apply_snapshot(snap: Dictionary) -> void:
	if _box == null:
		return
	var promos: Array = snap.get("promotions", [])
	var key := promos.map(func(p): return [p["def_id"], String((p["running"] as Dictionary).get("promotion_id", ""))])
	if key != _rows_key:
		_rows_key = key
		_rebuild(promos)
	for p in promos:
		var l: Label = _labels.get(p["def_id"])
		if l != null:
			l.text = promo_line(p)


func _rebuild(promos: Array) -> void:
	for n in _box.get_children():
		n.queue_free()
	_labels.clear()
	for p in promos:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		_labels[p["def_id"]] = l
		var b := Button.new()
		var running: Dictionary = p["running"]
		if running.is_empty():
			b.name = "Start_" + String(p["def_id"])
			b.text = "開始"
			b.pressed.connect(start_promotion.bind(String(p["def_id"]), int(p.get("default_days", 3))))
		else:
			b.name = "Stop_" + String(p["def_id"])
			b.text = "終了"
			b.pressed.connect(stop_promotion.bind(String(running["promotion_id"])))
		row.add_child(b)
		_box.add_child(row)


func start_promotion(def_id: String, days: int) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_promo_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"START_PROMOTION", "def_id": def_id, "days": days})
	_status.text = "販促を始めました。" if r.ok else "始められません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


func stop_promotion(promotion_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_promo_stop_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"STOP_PROMOTION", "promotion_id": promotion_id})
	_status.text = "販促を終えました。" if r.ok else "終えられません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


const ERRORS := {"not_enough_cash": "現金が足りません", "too_many_promotions": "同時に実施できるのは3つまでです", "promotion_running": "実施中です", "unknown_promotion": "販促がありません", "days_invalid": "日数が不正です"}


static func promo_line(p: Dictionary) -> String:
	var running: Dictionary = p.get("running", {})
	var head := "%s　準備費 %s" % [p.get("display_name", ""), OverlayModel.yen(int(p.get("setup_cost_yen", 0)))]
	if running.is_empty():
		return "%s　%d日間" % [head, int(p.get("default_days", 3))]
	var st: Dictionary = running.get("stats", {})
	var left := int(running.get("days_left", 0))
	match String(p.get("kind", "")):   # #140
		"gift":
			return "%s\n実施中・残り%d日　%s 配布 %d　残り %d%s" % [head, left, p.get("novelty_name", ""), int(st.get("given", 0)), int(st.get("stock", 0)), "（配布終了）" if int(st.get("stock", 0)) == 0 else ""]
		"stamps":
			return "%s\n実施中・残り%d日　カード %d枚　スタンプ %d個　景品 %d　残り %d" % [head, left, int(st.get("issued", 0)), int(st.get("stamps", 0)), int(st.get("redeemed", 0)), int(st.get("stock", 0))]
		"fair", "collab":
			return "%s\n実施中・残り%d日%s" % [head, left, "　限定グッズを発注できます" if p.get("kind", "") == "collab" else ""]
	if p.get("kind", "") == "coupon":
		return "%s\n実施中・残り%d日　配布 %d枚　利用 %d枚　値引き %s" % [head, int(running.get("days_left", 0)), int(st.get("issued", 0)), int(st.get("redeemed", 0)), OverlayModel.yen(int(st.get("discount_yen", 0)))]
	return "%s\n実施中・残り%d日　対象 %d点　値引き %s" % [head, int(running.get("days_left", 0)), int(st.get("units", 0)), OverlayModel.yen(int(st.get("discount_yen", 0)))]
