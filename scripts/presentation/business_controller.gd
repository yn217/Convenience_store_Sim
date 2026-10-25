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
var _ad_change: Button
var _ad_summary: Label
var _ad_info: Label
var _status: Label
var _checklist: Label
var _location: OptionButton
var _location_info: Label
var _facility_boxes: Dictionary = {}   # facility id -> CheckBox (#149)
var _facility_info: Label
var _size: OptionButton
var _expand: Button
var _size_info: Label

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
	var ad_head := HBoxContainer.new()
	var ad_title := Label.new()
	ad_title.text = "明日の広告・予定"
	ad_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad_head.add_child(ad_title)
	_ad_change = Button.new()
	_ad_change.text = "変更"
	_ad_change.add_theme_font_size_override("font_size", 13)
	_ad_change.pressed.connect(open_ad_picker)
	ad_head.add_child(_ad_change)
	_body.add_child(ad_head)
	_ad_summary = Label.new()
	_ad_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_ad_summary)
	_ad = OptionButton.new()
	_ad.clip_text = true
	_ad.fit_to_longest_item = false
	_ad.custom_minimum_size = Vector2(60, 0)
	for tier in _tiers:
		_ad.add_item(tier_item_text(tier))
		_ad.set_item_metadata(_ad.item_count - 1, int(tier["yen_per_day"]))
	_ad.item_selected.connect(func(i): set_next_day_ad(_ad.get_item_metadata(i)))
	_body.add_child(_ad)
	_ad_info = Label.new()
	_ad_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_ad_info)
	# #148: the store's location, chosen before the first opening.
	var loc_title := Label.new()
	loc_title.text = "立地（最初の営業開始まで選べます）"
	_body.add_child(loc_title)
	_location = OptionButton.new()
	_location.name = "LocationPicker"
	_location.add_item(StoreLocation.display_name(""))
	_location.set_item_metadata(0, "")
	for l in StoreLocation.all():
		_location.add_item(String(l["display_name"]))
		_location.set_item_metadata(_location.item_count - 1, String(l["location_id"]))
	_location.item_selected.connect(func(i): set_location(String(_location.get_item_metadata(i))))
	_body.add_child(_location)
	_location_info = Label.new()
	_location_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_location_info)
	# #149: nearby facilities (up to NearbyFacility.max_count), chosen before the first opening like the location.
	var fac_title := Label.new()
	fac_title.text = "周辺施設（%dつまで・最初の営業開始まで選べます）" % NearbyFacility.max_count()
	_body.add_child(fac_title)
	var fac_grid := GridContainer.new()
	fac_grid.name = "FacilityPicker"
	fac_grid.columns = 3
	for f in NearbyFacility.all():
		var box := CheckBox.new()
		box.name = "Facility_" + String(f["facility_id"])
		box.text = String(f["display_name"])
		box.tooltip_text = String(f["description"])
		box.toggled.connect(func(_on): _send_facilities())
		fac_grid.add_child(box)
		_facility_boxes[f["facility_id"]] = box
	_body.add_child(fac_grid)
	_facility_info = Label.new()
	_facility_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_facility_info)
	# #145: the store's size (before the first opening) and extending it later (while closed).
	var size_title := Label.new()
	size_title.text = "店舗の大きさ"
	_body.add_child(size_title)
	var size_row := HBoxContainer.new()
	_size = OptionButton.new()
	_size.name = "StoreSizePicker"
	_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in balance.get("store_sizes", []):
		_size.add_item("%s（%d×%d）" % [s["display_name"], int(s["width"]), int(s["height"])])
		_size.set_item_metadata(_size.item_count - 1, String(s["size_id"]))
	_size.item_selected.connect(func(i): set_store_size(String(_size.get_item_metadata(i))))
	size_row.add_child(_size)
	_expand = Button.new()
	_expand.name = "ExpandStore"
	_expand.pressed.connect(expand_store)
	size_row.add_child(_expand)
	_body.add_child(size_row)
	_size_info = Label.new()
	_size_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_size_info)
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
	var planned := int(snap.get("next_day_ad_yen", 0))
	_ad_summary.text = plan_summary_text(_tiers, planned)
	var today := int(snap.get("applied_ad_tier_yen", 0))
	_ad_info.text = "今日の広告: %s ／ 明日の予約: %s（翌日の開始時に請求）" % [_yen_or_none(today), _yen_or_none(int(snap.get("next_day_ad_yen", 0)))]
	var loc := String(snap.get("location_id", ""))
	for i in _location.item_count:
		if String(_location.get_item_metadata(i)) == loc:
			_location.select(i)
	_location.disabled = bool(snap.get("location_locked", true))
	_location_info.text = location_text(loc)
	var chosen: Array = snap.get("facilities", [])
	var locked := bool(snap.get("location_locked", true))
	for fid in _facility_boxes:
		var box: CheckBox = _facility_boxes[fid]
		box.set_pressed_no_signal(chosen.has(fid))
		box.disabled = locked or (not chosen.has(fid) and chosen.size() >= int(snap.get("max_facilities", 2)))
	_facility_info.text = facility_text(chosen, snap.get("facility_visits", {}))
	var size_id := String(snap.get("store_size_id", ""))
	for i in _size.item_count:
		if String(_size.get_item_metadata(i)) == size_id:
			_size.select(i)
	_size.disabled = bool(snap.get("location_locked", true))
	var nxt: Dictionary = snap.get("next_store_size", {})
	_expand.text = "増築なし（最大）" if nxt.is_empty() else "増築：%s %s" % [nxt["display_name"], GameHud.format_yen(int(nxt["expand_cost_yen"]))]
	_expand.disabled = nxt.is_empty() or not _size.disabled or state != "SETUP"
	_size_info.text = size_text(snap)
	var unpaid := int(snap.get("unpaid_cost_yen", 0))
	if state == "PAYMENT_BLOCKED":
		_status.text = "費用を支払えず営業を停止しました（未払い %s）。セーブからやり直してください。" % GameHud.format_yen(unpaid)


## One dropdown row, e.g. "明日の広告: なし ×1.00" or "明日の広告: ¥2,000 ×1.18".
static func tier_item_text(tier: Dictionary) -> String:
	var yen := int(tier["yen_per_day"])
	return "明日の広告: %s ×%.2f" % [GameHud.format_yen(yen) if yen > 0 else "なし", float(tier["arrival_multiplier"])]


## Summary of tomorrow's planned tier (SCR-17): plan, advertising cost and the traffic forecast.
## A tier that is not in the list counts as no advertising (×1.00).
static func plan_summary_text(tiers: Array, tier_yen: int) -> String:
	var tier: Dictionary = {}
	for t in tiers:
		if int(t["yen_per_day"]) == tier_yen:
			tier = t
	var multiplier := float(tier.get("arrival_multiplier", 1.0))
	var plan := "なし" if tier_yen <= 0 else GameHud.format_yen(tier_yen) + "/日"
	return "プラン: %s\n広告費: %s\n効果予測: 来店 ×%.2f" % [plan, GameHud.format_yen(maxi(tier_yen, 0)), multiplier]


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


## The 変更 button: opens the tomorrow-tier dropdown; the choice itself still goes through set_next_day_ad.
func open_ad_picker() -> void:
	_ad.grab_focus()
	_ad.show_popup()


func set_store_size(size_id: String) -> CommandResult:
	return _send({"kind": &"SET_STORE_SIZE", "size_id": size_id})


func expand_store() -> CommandResult:
	return _send({"kind": &"EXPAND_STORE"})


## What the size allows, and how extending works.
static func size_text(snap: Dictionary) -> String:
	if not bool(snap.get("location_locked", true)):
		return "最初の営業開始までは無料で選べます。大きい店ほど棚を多く置け、大きい控え室（店員の上限）も置けます。"
	return "増築は閉店中（準備中）にできます。奥と横に床が広がり、入口の壁と什器の並びはそのまま残ります。"


func set_facilities(ids: Array) -> CommandResult:
	return _send({"kind": &"SET_FACILITIES", "facility_ids": ids})


func _send_facilities() -> void:
	var ids: Array = []
	for f in NearbyFacility.all():
		if (_facility_boxes[f["facility_id"]] as CheckBox).button_pressed:
			ids.append(f["facility_id"])
	set_facilities(ids)


## The chosen facilities: who they bring, and how many came today.
static func facility_text(chosen: Array, visits: Dictionary) -> String:
	if chosen.is_empty():
		return "周辺施設なし。施設を選ぶと、その施設の客（学生・宿泊客・交代勤務の人など）が決まった時間に来ます。"
	var lines: Array[String] = []
	for fid in chosen:
		var f := NearbyFacility.find(fid)
		lines.append("%s：%s（1日約%d人・今日 %d人）" % [f["display_name"], f["description"], int(f["visitors_per_day"]), int(visits.get(fid, 0))])
	return "\n".join(lines)


func set_location(location_id: String) -> CommandResult:
	return _send({"kind": &"SET_LOCATION", "location_id": location_id})


## The chosen location's description (or the standard store's).
static func location_text(location_id: String) -> String:
	var l := StoreLocation.find(location_id)
	if l.is_empty():
		return "標準：時間帯・客層の偏りがない店。立地を選ぶと、来店の多い時間と売れる商品が変わります。"
	return "%s：%s（来店 ×%.1f・予算 ×%.1f）" % [l["display_name"], l["description"], float(l["visitors_multiplier"]), float(l["budget_multiplier"])]


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
