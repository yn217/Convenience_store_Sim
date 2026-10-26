class_name StaffController
extends Node
## 店員 tab (issue #144): the staff (skills, fatigue, job, utilisation, daily wage, 解雇), today's candidates
## (採用, limited by the staff room), the line at the register by hour and the advice whether to hire.
## Presentation only: HIRE_STAFF / FIRE_STAFF go through AppRoot; everything shown comes from the snapshot.

const TITLE := "店員"
const FIRST_HOUR := 6

var _app: Node
var _seq := 0
var _summary: Label
var _staff_box: VBoxContainer
var _cand_box: VBoxContainer
var _hours: Label
var _advice: Label
var _status: Label
var _rows_key := []
var _stores: Array = []   # #146: the company's stores (for the transfer choice)
var _staff_labels: Dictionary = {}   # staff id -> Label (texts change every snapshot; rows only when people change)

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node) -> void:
	_app = app
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_summary = _label()
	_staff_box = VBoxContainer.new()
	_body.add_child(_staff_box)
	var cand_title := _label()
	cand_title.text = "採用候補（毎朝入れ替わります）"
	cand_title.add_theme_color_override("font_color", UiTheme.WARM)
	_cand_box = VBoxContainer.new()
	_body.add_child(_cand_box)
	var hours_title := _label()
	hours_title.text = "時間帯別のレジ待ち（今日・平均人数）"
	hours_title.add_theme_color_override("font_color", UiTheme.WARM)
	_hours = _label()
	_hours.add_theme_font_size_override("font_size", 13)
	_advice = _label()
	_status = _label()


func _label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func apply_snapshot(snap: Dictionary) -> void:
	if _summary == null:
		return
	var staffing: Dictionary = snap.get("staffing", {})
	var staff: Array = (snap.get("customers", []) as Array).filter(func(c): return bool(c.get("staff", false)))
	var cands: Array = snap.get("staff_candidates", [])
	var cap := int(snap.get("staff_cap", 0))
	if staffing.is_empty():
		_summary.text = "店員はいません（この設定では店員なしで営業します）。"
		return
	_summary.text = summary_text(staff.size(), cap, int(staffing.get("wages_per_day", 0)))
	_stores = snap.get("stores", [])
	var key := [cap, staff.map(func(s): return s["customer_id"]), cands.map(func(c): return c["candidate_id"]), _stores.size()]
	if key != _rows_key:
		_rows_key = key
		_rebuild(staff, cands, staff.size() >= cap)
	var util: Dictionary = staffing.get("utilisation", {})
	for s in staff:
		var l: Label = _staff_labels.get(s["customer_id"])
		if l != null:
			l.text = staff_line(s, float(util.get(s["customer_id"], 0.0)))
	_hours.text = hours_text(staffing.get("line_today", []), staffing.get("balked_today", []), staffing.get("abandoned_today", []))
	_advice.text = String(staffing.get("advice", ""))


func _rebuild(staff: Array, cands: Array, full: bool) -> void:
	for n in _staff_box.get_children():
		n.queue_free()
	for n in _cand_box.get_children():
		n.queue_free()
	_staff_labels.clear()
	for s in staff:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		_staff_labels[s["customer_id"]] = l
		if _stores.size() > 1:   # #146: move to another store of the company (both closed)
			var to := OptionButton.new()
			to.name = "Transfer_" + String(s["customer_id"])
			to.add_item("異動…")
			to.set_item_metadata(0, null)
			for st in _stores:
				if not bool(st["active"]):
					to.add_item("→ " + String(st["name"]))
					to.set_item_metadata(to.item_count - 1, String(st["store_id"]))
			to.item_selected.connect(func(i): if to.get_item_metadata(i) != null: transfer_staff(String(s["customer_id"]), String(to.get_item_metadata(i))))
			row.add_child(to)
		var fire := Button.new()
		fire.name = "Fire_" + String(s["customer_id"])
		fire.text = "解雇"
		fire.pressed.connect(fire_staff.bind(String(s["customer_id"])))
		row.add_child(fire)
		_staff_box.add_child(row)
	for c in cands:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = candidate_line(c)
		row.add_child(l)
		var hire := Button.new()
		hire.name = "Hire_" + String(c["candidate_id"])
		hire.text = "採用"
		hire.disabled = full
		hire.tooltip_text = "上限に達しています" if full else ""
		hire.pressed.connect(hire_candidate.bind(String(c["candidate_id"])))
		row.add_child(hire)
		_cand_box.add_child(row)
	if cands.is_empty():
		var none := Label.new()
		none.text = "今日の候補はもういません。"
		_cand_box.add_child(none)


func transfer_staff(staff_id: String, to_store_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_transfer_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"TRANSFER_STAFF", "staff_id": staff_id, "to_store_id": to_store_id})
	_status.text = "異動しました。" if r.ok else "異動できません（%s）" % TRANSFER_ERRORS.get(String(r.message_key), String(r.message_key))
	return r


const TRANSFER_ERRORS := {"stores_must_be_closed": "両方の店が準備中のときだけ異動できます", "staff_cap_reached": "異動先の店員が上限です", "unknown_store": "店がありません"}


func hire_candidate(candidate_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_hire_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"HIRE_STAFF", "candidate_id": candidate_id})
	_status.text = "採用しました。" if r.ok else "採用できません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


func fire_staff(staff_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_fire_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"FIRE_STAFF", "staff_id": staff_id})
	_status.text = "解雇しました。" if r.ok else "解雇できません（%s）" % ERRORS.get(String(r.message_key), String(r.message_key))
	return r


const ERRORS := {"staff_cap_reached": "店員の上限です。大きい控え室を置くと増やせます", "unknown_candidate": "候補がいません", "unknown_staff": "店員がいません"}


static func summary_text(count: int, cap: int, wages: int) -> String:
	return "店員 %d / 上限 %d人　人件費 %s/日" % [count, cap, OverlayModel.yen(wages)]


static func staff_line(s: Dictionary, util: float) -> String:
	var lines := OverlayModel.staff_panel_lines(s, "")
	return "%s　%s\n%s　稼働 %d%%　%s" % [lines[0], lines[1], lines[2], int(round(util * 100.0)), lines[3]]


static func candidate_line(c: Dictionary) -> String:
	var sk: Dictionary = c.get("skills", {})
	return "%s（%s）　レジ %d　品出し %d　体力 %d　接客 %d　日給 %s" % [c.get("name", ""), c.get("label", c.get("archetype", "")),
		int(sk.get("register", 0)), int(sk.get("restock", 0)), int(sk.get("stamina", 0)), int(sk.get("service", 0)), OverlayModel.yen(int(c.get("daily_wage_yen", 0)))]


## One line per hour from FIRST_HOUR: a bar of the average line, and the people lost to it in that hour.
static func hours_text(line: Array, balked: Array, abandoned: Array) -> String:
	if line.size() < 24:
		return ""
	var rows: Array[String] = []
	for h in range(FIRST_HOUR, 24):
		var v := float(line[h])
		var lost := int(balked[h] if balked.size() == 24 else 0) + int(abandoned[h] if abandoned.size() == 24 else 0)
		var bar := "■".repeat(mini(int(round(v * 2.0)), 12))
		rows.append("%2d時 %s %.1f人%s" % [h, bar if bar != "" else "・", v, ("　帰った %d人" % lost) if lost > 0 else ""])
	return "\n".join(rows)
