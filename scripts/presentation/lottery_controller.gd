class_name LotteryController
extends Node
## 店頭くじ card (issue #138): every prize draw set with its ticket price, tickets and set cost, 仕入れて開始 (one
## set at a time), and the set on sale: tickets sold, takings, days left and the prizes left per tier. Presentation
## only: START_LOTTERY goes through AppRoot; everything shown comes from the snapshot.

const TITLE := "店頭くじ"
const ERRORS := {"not_enough_cash": "現金が足りません", "lottery_running": "販売中のくじがあります", "unknown_set": "くじがありません"}
const STATUS := {"selling": "販売中", "sold_out": "完売", "ended": "終了"}

var _app: Node
var _seq := 0
var _box: VBoxContainer
var _status: Label
var _rows_key := []
var _labels: Dictionary = {}   # set id -> Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node) -> void:
	_app = app
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var hint := _label()
	hint.text = "セットを丸ごと仕入れ、レジで1枚ずつ売ります。どの券にも景品が付き、最後の1枚にはおまけが付きます。売れ残りは終了日に損になります。"
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
	var sets: Array = snap.get("lotteries", [])
	var selling := bool(snap.get("lottery_selling", false))
	var key := [selling] + sets.map(func(v): return v["set_id"])
	if key != _rows_key:
		_rows_key = key
		_rebuild(sets, selling)
	for v in sets:
		var l: Label = _labels.get(v["set_id"])
		if l != null:
			l.text = set_line(v)


func _rebuild(sets: Array, selling: bool) -> void:
	for n in _box.get_children():
		n.queue_free()
	_labels.clear()
	for v in sets:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		_labels[v["set_id"]] = l
		var b := Button.new()
		b.name = "Start_" + String(v["set_id"])
		b.text = "仕入れて開始"
		b.disabled = selling
		b.pressed.connect(start_lottery.bind(String(v["set_id"])))
		row.add_child(b)
		_box.add_child(row)


func start_lottery(set_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_kuji_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"START_LOTTERY", "set_id": set_id})
	_status.text = "くじの販売を始めました。" if r.ok else "始められません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


static func set_line(v: Dictionary) -> String:
	var head := "%s　1回 %s　%d枚　仕入 %s　%d日間" % [v.get("display_name", ""), OverlayModel.yen(int(v.get("ticket_price_yen", 0))), int(v.get("tickets", 0)),
		OverlayModel.yen(int(v.get("set_cost_yen", 0))), int(v.get("days", 0))]
	var run: Dictionary = v.get("run", {})
	if run.is_empty():
		return head
	var left: Array[String] = []
	var rem: Dictionary = run.get("remaining", {})
	for p in v.get("prizes", []):
		left.append("%s賞 %s %d" % [p["tier"], p["name"], int(rem.get(p["tier"], 0))])
	var days := "・残り%d日" % int(run.get("days_left", 0)) if run.get("status", "") == "selling" else ""
	return "%s\n%s%s　%d/%d枚　売上 %s\n残り：%s" % [head, STATUS.get(run.get("status", ""), ""), days, int(run.get("sold", 0)), int(v.get("tickets", 0)),
		OverlayModel.yen(int(run.get("revenue_yen", 0))), "・".join(left)]
