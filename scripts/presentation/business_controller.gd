class_name BusinessController
extends Node
## Open / close the store and pick tomorrow's advertising tier (SCR-17) in the inspector.
## Presentation only: it sends START_BUSINESS / REQUEST_CLOSE / SET_NEXT_DAY_AD through AppRoot
## and shows the Domain's answer. Today's budget and tomorrow's are shown apart.

var _app: Node
var _tiers: Array = []
var _snap: Dictionary = {}
var _seq: int = 0

var _start: Button
var _close: Button
var _ad: OptionButton
var _ad_info: Label
var _status: Label
var _checklist: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node, balance: Dictionary) -> void:
	_app = app
	_tiers = balance.get("advertising_tiers", [])
	var title := Label.new()
	title.text = "営業"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var row := HBoxContainer.new()
	_start = Button.new()
	_start.text = "営業開始"
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.pressed.connect(start_business)
	_close = Button.new()
	_close.text = "閉店する"
	_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close.pressed.connect(request_close)
	row.add_child(_start)
	row.add_child(_close)
	_body.add_child(row)
	_checklist = Label.new()
	_checklist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_checklist)
	_ad = OptionButton.new()
	_ad.clip_text = true
	_ad.fit_to_longest_item = false
	_ad.custom_minimum_size = Vector2(60, 0)
	for tier in _tiers:
		_ad.add_item("明日の広告: %s ×%.2f" % [GameHud.format_yen(int(tier["yen_per_day"])) if int(tier["yen_per_day"]) > 0 else "なし", float(tier["arrival_multiplier"])])
		_ad.set_item_metadata(_ad.item_count - 1, int(tier["yen_per_day"]))
	_ad.item_selected.connect(func(i): set_next_day_ad(_ad.get_item_metadata(i)))
	_body.add_child(_ad)
	_ad_info = Label.new()
	_ad_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_ad_info)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	var state := String(snap.get("business_state", "SETUP"))
	var opening: Dictionary = snap.get("opening", {})
	_start.disabled = state != "SETUP" or (not opening.is_empty() and not opening["ready"])
	_checklist.text = checklist_text(opening) if state == "SETUP" else ""
	_close.disabled = state != "OPEN"
	for i in _ad.item_count:
		if _ad.get_item_metadata(i) == int(snap.get("next_day_ad_yen", 0)):
			_ad.select(i)
	var today := int(snap.get("applied_ad_tier_yen", 0))
	_ad_info.text = "今日の広告: %s ／ 明日の予約: %s（翌日の開始時に請求）" % [_yen_or_none(today), _yen_or_none(int(snap.get("next_day_ad_yen", 0)))]
	var unpaid := int(snap.get("unpaid_cost_yen", 0))
	if state == "PAYMENT_BLOCKED":
		_status.text = "費用を支払えず営業を停止しました（未払い %s）。セーブからやり直してください。" % GameHud.format_yen(unpaid)


## SCR-09: every opening condition with a mark, so a disabled button always says why.
static func checklist_text(opening: Dictionary) -> String:
	if opening.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append(("✓ レジあり" if opening["register_ok"] else "✗ レジが必要です（待機列を作れる場所に置いてください）"))
	lines.append(("✓ 客が行ける棚に商品あり" if opening["stock_ok"] else "✗ 客が行ける棚に商品を並べてください"))
	var due := int(opening["charges_due_yen"])
	if due <= 0:
		lines.append("✓ 今日の費用は支払い済みです")
	elif opening["cash_ok"]:
		lines.append("✓ 今日の費用 %s を支払えます" % GameHud.format_yen(due))
	else:
		lines.append("✗ 今日の費用 %s に所持金が足りません" % GameHud.format_yen(due))
	return "\n".join(lines)


func _yen_or_none(yen: int) -> String:
	return "なし" if yen <= 0 else GameHud.format_yen(yen)


func start_business() -> CommandResult:
	return _send({"kind": &"START_BUSINESS"})


func request_close() -> CommandResult:
	return _send({"kind": &"REQUEST_CLOSE"})


func set_next_day_ad(tier_yen: int) -> CommandResult:
	return _send({"kind": &"SET_NEXT_DAY_AD", "tier_yen": tier_yen})


func _send(cmd: Dictionary) -> CommandResult:
	_seq += 1
	cmd["command_id"] = "ui_business_%d" % _seq
	var r: CommandResult = _app.run_command(cmd)
	_status.text = "" if r.ok else _message(r)
	if not r.ok and _snap.has("next_day_ad_yen"):
		apply_snapshot(_snap)   # put the selector back on the real value
	return r


func _message(r: CommandResult) -> String:
	if r.code == &"MISSING_REGISTER":
		return CommandMessages.text(r.code, &"missing_register")
	if r.code == &"MISSING_STOCK":
		return CommandMessages.text(r.code, &"missing_stock")
	return CommandMessages.text(r.code, r.message_key)
