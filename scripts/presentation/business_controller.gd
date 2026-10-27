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
var _map_window: Window          # #150: the area map, opened from the 地図で選ぶ button
var _map_view: MapView
var _map_info: Label
var _map_pick: Button
var _map_size: OptionButton      # #146: the size of a new store
var _stores_box: VBoxContainer   # #146: the company's stores
var _stores_key := []
var _rivals: Label            # #129
var _rivals_on: CheckBox
var _map_button: Button
var _map_selected := ""
var _map_hour: HSlider
var _map_hour_label: Label
var _balance: Dictionary = {}
var _map_choice: OptionButton
var _map_title: Label
var _size: OptionButton
var _expand: Button
var _entrance: OptionButton   # #121
var _entrance_move: Button
var _entrance_key := []
var _size_info: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"
var _blocked: PanelContainer   # #20 SCR-14: the store cannot go on (payment blocked)
var _blocked_text: Label
var _blocked_load: Button


func setup(app: Node, balance: Dictionary) -> void:
	_app = app
	_tiers = balance.get("advertising_tiers", [])
	_build_blocked_panel()
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
	# #148: the store's location, chosen before the first opening (#150: on the area map, or by hand below).
	var loc_head := HBoxContainer.new()
	var loc_title := Label.new()
	loc_title.text = "立地（最初の営業開始まで選べます）"
	loc_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_head.add_child(loc_title)
	_map_button = Button.new()
	_map_button.name = "OpenMap"
	_map_button.text = "地図で選ぶ"
	_map_button.pressed.connect(open_map)
	loc_head.add_child(_map_button)
	_body.add_child(loc_head)
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
	# #146: the company's stores (open new ones on the area map, switch between them here).
	var stores_title := Label.new()
	stores_title.text = "店舗（新しい店は「地図・出店」から出せます）"
	_body.add_child(stores_title)
	_stores_box = VBoxContainer.new()
	_stores_box.name = "StoreList"
	_body.add_child(_stores_box)
	# #129: rival stores near the company's first store.
	var rival_head := HBoxContainer.new()
	var rival_title := Label.new()
	rival_title.text = "ライバル店・地域の動き"
	rival_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rival_head.add_child(rival_title)
	_rivals_on = CheckBox.new()
	_rivals_on.name = "RivalsOn"
	_rivals_on.text = "出店する"
	_rivals_on.toggled.connect(func(on): _send({"kind": &"SET_RIVALS", "enabled": on}))
	rival_head.add_child(_rivals_on)
	_body.add_child(rival_head)
	_rivals = Label.new()
	_rivals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_rivals)
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
	var door_row := HBoxContainer.new()   # #121: move the entrance while closed
	var door_caption := Label.new()
	door_caption.text = "入口"
	door_row.add_child(door_caption)
	_entrance = OptionButton.new()
	_entrance.name = "EntranceChoice"
	_entrance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_row.add_child(_entrance)
	_entrance_move = Button.new()
	_entrance_move.name = "MoveEntrance"
	_entrance_move.pressed.connect(func():
		var at = _entrance.get_selected_metadata()
		if at is Vector2i:
			move_entrance(at))
	door_row.add_child(_entrance_move)
	_body.add_child(door_row)
	_size_info = Label.new()
	_size_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_size_info)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)


## SCR-14 (#20): a panel over the store when the day's costs could not be paid — what happened, the unpaid
## amount, and the two ways on: load the last good save, or start a new game. Nothing is rolled back by itself.
func _build_blocked_panel() -> void:
	_blocked = PanelContainer.new()
	_blocked.name = "PaymentBlockedPanel"
	_blocked.theme_type_variation = &"Card"
	_blocked.visible = false
	_blocked.custom_minimum_size = Vector2(460, 0)
	_blocked.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_blocked.grow_horizontal = Control.GROW_DIRECTION_BOTH   # grows out from the centre of the screen
	_blocked.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_blocked.add_child(col)
	var title := Label.new()
	title.text = "営業の継続ができません"
	title.theme_type_variation = &"SectionTitle"
	col.add_child(title)
	_blocked_text = Label.new()
	_blocked_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_blocked_text)
	_blocked_load = Button.new()
	_blocked_load.name = "LoadLatest"
	_blocked_load.text = "直近の正常なセーブを読み込む"
	_blocked_load.theme_type_variation = &"PrimaryButton"
	_blocked_load.pressed.connect(load_latest)
	col.add_child(_blocked_load)
	var fresh := Button.new()
	fresh.name = "NewGame"
	fresh.text = "新しいゲームを開始"
	fresh.pressed.connect(new_game)
	col.add_child(fresh)
	get_parent().add_child.call_deferred(_blocked)


## What the panel says (#20).
static func blocked_text(unpaid_yen: int, has_save: bool) -> String:
	return "日付が変わったときの費用の支払いで、現金が足りなくなりました（未払い %s）。
売上・在庫・予約を勝手に巻き戻すことはしません。%s" % [
		GameHud.format_yen(unpaid_yen), "" if has_save else "
（読み込めるセーブがありません）"]


## Loads the slot saved last.
func load_latest() -> CommandResult:
	var slot := SaveStore.latest_slot(_app.save_dir)
	if slot == "":
		return CommandResult.failure(&"INVALID_OPERATION", 0, &"no_save")
	return _app.run_command({"command_id": "ui_blocked_load_%d" % Time.get_ticks_usec(), "kind": &"LOAD_GAME", "slot_id": slot})


## Starts over with a new store (reloads the main scene).
func new_game() -> void:
	get_tree().reload_current_scene()


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	var state := String(snap.get("business_state", "SETUP"))
	if _blocked != null:   # #20 SCR-14
		_blocked.visible = state == "PAYMENT_BLOCKED"
		if _blocked.visible:
			var has_save := SaveStore.latest_slot(_app.save_dir) != ""
			_blocked_text.text = blocked_text(int(snap.get("unpaid_cost_yen", 0)), has_save)
			_blocked_load.disabled = not has_save
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
	if String(snap.get("plot_id", "")) != "":
		var plot := WorldMap.plot(String(snap["map_id"]), String(snap["plot_id"]))
		_location_info.text = "地図：%s %s ／ %s" % [WorldMap.display_name(String(snap["map_id"])), plot.get("name", ""), _location_info.text]
	_map_button.text = "地図で選ぶ" if not bool(snap.get("location_locked", true)) else "地図・出店"
	_rivals_on.set_pressed_no_signal(bool(snap.get("rivals_enabled", true)))
	_rivals.text = rivals_text(snap.get("rivals", []), float(snap.get("rival_factor", 1.0))) + conditions_text(snap.get("conditions", []))
	if _map_view != null:
		_map_view.rivals = (snap.get("rivals", []) as Array).filter(func(r): return r.get("status", "open") != "closed")
	var stores: Array = snap.get("stores", [])
	var skey := stores.map(func(st): return [st["store_id"], st["active"], st["business_state"], st["revenue_today"], (st["staff"] as Array).size()])
	if skey != _stores_key:
		_stores_key = skey
		for n in _stores_box.get_children():
			n.queue_free()
		for st in stores:
			var row := HBoxContainer.new()
			var l := Label.new()
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.text = store_line(st)
			row.add_child(l)
			if not bool(st["active"]):
				var b := Button.new()
				b.name = "Switch_" + (String(st["store_id"]) if st["store_id"] != "" else "s1")
				b.text = "切り替え"
				b.pressed.connect(switch_store.bind(String(st["store_id"])))
				row.add_child(b)
			_stores_box.add_child(row)
	if _map_view != null:
		_map_view.current = _current_plot_on(_map_view.map_id)
		_map_view.queue_redraw()
		_show_plot(_map_selected)
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
	_sync_entrance(snap, state)
	if int(snap.get("construction_days", 0)) > 0:   # #145
		_size_info.text += "\n増築工事：次に開店するとき、工事の %d 日間を休業してから開店します（その間も固定費・電気代・人件費がかかり、売上はありません）。" % int(snap["construction_days"])
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


## #121: moves the entrance to the two wall tiles starting at `at`.
func move_entrance(at: Vector2i) -> CommandResult:
	return _send({"kind": &"MOVE_ENTRANCE", "x": at.x, "y": at.y})


## The places the entrance can go (rebuilt when the store size or the entrance changes); the current one selected.
func _sync_entrance(snap: Dictionary, state: String) -> void:
	var w := int(snap.get("store_width", 0))
	var h := int(snap.get("store_height", 0))
	var now: Array = snap.get("entrance_tiles", [])
	var key := [w, h, now]
	if key != _entrance_key:
		_entrance_key = key
		_entrance.clear()
		for at in EntranceRules.candidates(w, h):
			_entrance.add_item(EntranceRules.label(w, h, at))
			_entrance.set_item_metadata(_entrance.item_count - 1, at)
			if not now.is_empty() and now[0] == at:
				_entrance.select(_entrance.item_count - 1)
	_entrance_move.text = "入口を移す %s" % GameHud.format_yen(int(snap.get("entrance_move_cost_yen", 0)))
	_entrance_move.disabled = state != "SETUP"


## What the size allows, and how extending works.
static func size_text(snap: Dictionary) -> String:
	if not bool(snap.get("location_locked", true)):
		return "最初の営業開始までは無料で選べます。大きい店ほど棚を多く置け、大きい控え室（店員の上限）も置けます。"
	return "増築は閉店中（準備中）にできます。奥と横に床が広がり、入口の壁と什器の並びはそのまま残ります。工事のあいだ（中は2日・大は3日）は休業です。"


## Opens the area map (#150): sites to pick before the first opening, the facilities around them and a forecast.
func open_map() -> void:
	if _map_window == null:
		_map_window = Window.new()
		_map_window.name = "AreaMap"
		_map_window.title = "地域マップ"
		_map_window.size = Vector2i(1240, 720)   # a 16:9 picture map needs the width
		_map_window.close_requested.connect(func(): _map_window.hide())
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map_view = MapView.new()
		_map_view.name = "MapView"
		_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_view.plot_clicked.connect(_show_plot)
		row.add_child(_map_view)
		var side := VBoxContainer.new()
		side.custom_minimum_size = Vector2(280, 0)
		_map_choice = OptionButton.new()
		_map_choice.name = "MapChoice"
		for id in WorldMap.MAPS:
			_map_choice.add_item(WorldMap.display_name(id))
			_map_choice.set_item_metadata(_map_choice.item_count - 1, id)
		_map_choice.item_selected.connect(func(i): show_map(String(_map_choice.get_item_metadata(i))))
		side.add_child(_map_choice)
		_map_title = Label.new()
		_map_title.add_theme_font_size_override("font_size", 18)
		side.add_child(_map_title)
		_map_info = Label.new()
		_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_map_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_info.text = "黄色の丸が出店できる区画です。クリックすると、立地と周りの施設・予想来店数が出ます。"
		side.add_child(_map_info)
		# Forecast layer: the visitors each site may expect in the chosen hour (#150 phase 2).
		_map_hour_label = Label.new()
		side.add_child(_map_hour_label)
		_map_hour = HSlider.new()
		_map_hour.name = "ForecastHour"
		_map_hour.min_value = -1
		_map_hour.max_value = 23
		_map_hour.step = 1
		_map_hour.value = -1
		_map_hour.value_changed.connect(func(v): set_forecast_hour(int(v)))
		side.add_child(_map_hour)
		var fit := Button.new()
		fit.name = "MapFit"
		fit.text = "全体表示（ホイールで拡大・ドラッグで移動）"
		fit.pressed.connect(func(): _map_view.reset_view())
		side.add_child(fit)
		_map_size = OptionButton.new()
		_map_size.name = "NewStoreSize"
		for sz in StoreSize.all(_snap_balance()):
			_map_size.add_item("%s（%d×%d）出店 %s" % [sz["display_name"], int(sz["width"]), int(sz["height"]), GameHud.format_yen(int(sz.get("open_cost_yen", 0)))])
			_map_size.set_item_metadata(_map_size.item_count - 1, String(sz["size_id"]))
		_map_size.select(0)
		side.add_child(_map_size)
		_map_pick = Button.new()
		_map_pick.name = "PickSite"
		_map_pick.text = "ここに出店する"
		_map_pick.disabled = true
		_map_pick.pressed.connect(func(): pick_site(_map_selected))
		side.add_child(_map_pick)
		row.add_child(side)
		_map_window.add_child(row)
		add_child(_map_window)
		show_map(String(_snap.get("map_id", "")) if String(_snap.get("map_id", "")) != "" else WorldMap.DEFAULT_MAP)
	_map_view.current = _current_plot_on(_map_view.map_id)
	_map_window.popup_centered()


## Shows another area map in the window (#154: Kakogawa beside 青葉市).
func show_map(map_id: String) -> void:
	_map_view.set_map(map_id)
	_map_view.current = _current_plot_on(map_id)
	for i in _map_choice.item_count:
		if String(_map_choice.get_item_metadata(i)) == map_id:
			_map_choice.select(i)
	_map_title.text = WorldMap.display_name(map_id)
	_map_selected = ""
	_map_pick.disabled = true
	_map_info.text = "黄色の丸が出店できる区画です。クリックすると、立地と周りの施設・予想来店数が出ます。"
	_map_hour.set_value_no_signal(-1)
	set_forecast_hour(-1)


## The store's site if it is on `map_id`, else "".
func _current_plot_on(map_id: String) -> String:
	return String(_snap.get("plot_id", "")) if String(_snap.get("map_id", "")) == map_id else ""


## The side panel for a clicked site.
func _show_plot(plot_id: String) -> void:
	if _map_view == null or plot_id == "":
		return
	_map_selected = plot_id
	_map_view.set_selected(plot_id)
	var locked := bool(_snap.get("location_locked", true))
	var map_id := _map_view.map_id
	_map_info.text = plot_text(map_id, plot_id)
	# Before the first opening a site sets this store's place; afterwards it opens a new store there (#146).
	var taken := (_snap.get("stores", []) as Array).any(func(st): return st["map_id"] == map_id and st["plot_id"] == plot_id)
	_map_pick.text = "ここに新しい店を出す" if locked else "ここに出店する"
	_map_size.visible = locked
	_map_pick.disabled = WorldMap.site(map_id, plot_id).is_empty() or taken or _current_plot_on(map_id) == plot_id
	if taken:
		_map_info.text += "\n（この区画には自社の店があります）"
	if plot_id == _current_plot_on(map_id) and locked:
		if _balance.is_empty():
			_balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
		_map_info.text += "\n\n" + actual_vs_forecast_text(WorldMap.forecast_by_hour(_balance, map_id, plot_id), _snap.get("visitors_by_hour", []), _snap.get("visitors_by_hour_yesterday", []))


## The forecast layer for `hour` (-1 = off).
func set_forecast_hour(hour: int) -> void:
	if _balance.is_empty():
		_balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	_map_view.set_forecast_hour(hour, _balance)
	_map_hour_label.text = "予想来店の表示：なし（つまみで時間帯を選ぶ）" if hour < 0 else "予想来店の表示：%d時台（円が大きいほど多い・目安）" % hour


func pick_site(plot_id: String) -> CommandResult:
	var map_id := _map_view.map_id if _map_view != null else WorldMap.DEFAULT_MAP
	if bool(_snap.get("location_locked", true)):   # the first store is open: a new store (#146)
		return _send({"kind": &"OPEN_STORE", "map_id": map_id, "plot_id": plot_id, "size_id": String(_map_size.get_item_metadata(_map_size.selected))})
	return _send({"kind": &"SET_SITE", "map_id": map_id, "plot_id": plot_id})


func _snap_balance() -> Dictionary:
	if _balance.is_empty():
		_balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	return _balance


## SWITCH_STORE (#146): another store on screen.
func switch_store(store_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_switch_%d" % _seq, "kind": &"SWITCH_STORE", "store_id": store_id})
	_status.text = "" if r.ok else CommandMessages.text(r.code, r.message_key)
	return r


## The rivals and what they take from the store on screen today (#129).
static func rivals_text(rivals: Array, factor: float) -> String:
	if rivals.is_empty():
		return "近くにライバル店はありません（地図で店の場所を選んだ店に、数日たつと近くに出店してきます）。"
	var lines: Array[String] = []
	for r in rivals:
		match String(r.get("status", "open")):
			"closed":
				lines.append("%s　DAY %d 閉店（区画が空きました）" % [r["name"], int(r["closed_day"])])
			"renovating":
				lines.append("%s　改装中（DAY %d に再開）" % [r["name"], int(r["reopen_day"])])
			_:
				lines.append("%s（DAY %d 開店）　この店の客 −%d%%%s" % [r["name"], int(r["opened_day"]), int(round(float(r["share"]) * 100.0)), "　特売中" if bool(r["on_sale"]) else ""])
	lines.append("ライバルの影響：来店 ×%.2f（品揃え・値付け・広告・販促で取り返せます）" % factor)
	return "\n".join(lines)


## The local conditions in force (#129 phase 2), after the rivals.
static func conditions_text(conds: Array) -> String:
	if conds.is_empty():
		return ""
	var lines: Array[String] = ["", "地域の動き："]
	for c in conds:
		lines.append("・%s（%s）来店 ×%.2f　%s" % [c["name_ja"], c["note"], float(c["visitors"]), "ずっと" if int(c["days_left"]) < 0 else "あと%d日" % int(c["days_left"])])
	return "\n".join(lines)


## One line per store of the company: name, place, size, state and today's money.
static func store_line(st: Dictionary) -> String:
	var state := {"SETUP": "準備中", "OPEN": "営業中", "CLOSING": "閉店作業中", "PAYMENT_BLOCKED": "支払い停止"}
	return "%s%s　%s・%s　%s　店員%d人　今日 売上 %s／営業損益 %s" % ["▶ " if bool(st["active"]) else "", st["name"], st["location"], st["size_id"],
		state.get(st["business_state"], st["business_state"]), (st["staff"] as Array).size(), GameHud.format_yen(int(st["revenue_today"])), GameHud.format_yen(int(st["profit_today"]))]


## What a site offers: location, nearby facilities with their distance, and the visitors forecast.
static func plot_text(map_id: String, plot_id: String) -> String:
	var p := WorldMap.plot(map_id, plot_id)
	if p.is_empty():
		return ""
	var lines: Array[String] = ["%s（%s）" % [p["name"], p["id"]]]
	if String(p.get("note", "")) != "":
		lines.append(String(p["note"]))
	match WorldMap.plot_status(p):
		"rival":
			lines.append("ライバル店があります（競合は今後の更新で動きます）。")
			return "\n".join(lines)
		"locked":
			lines.append("今後の更新で出店できるようになる区画です。")
			return "\n".join(lines)
	var s := WorldMap.site(map_id, plot_id)
	if s.is_empty():
		return "\n".join(lines)
	if s["location_id"] == "":
		lines.append("立地：標準（%s。客層は周りの施設から）" % WorldMap.KIND_NAMES.get(WorldMap.plot_kind(p), WorldMap.plot_kind(p)))
	else:
		lines.append("立地：%s" % StoreLocation.display_name(s["location_id"]))
	if (s["near"] as Array).is_empty():
		lines.append("近くの施設：なし")
	for f in s["near"]:
		lines.append("近くの施設：%s（%s・距離 %d）" % [f["name"], NearbyFacility.display_name(f["facility_id"]), int(f["distance"])])
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	lines.append("予想来店数：1日 約%d人（広告・イベントなしの目安）" % WorldMap.forecast_visitors(balance, map_id, plot_id))
	lines.append("多い時間帯：%s" % peak_hours_text(WorldMap.forecast_by_hour(balance, map_id, plot_id)))
	return "\n".join(lines)


## Time bands for the actual-vs-forecast table (#150): name and hours [from, to).
const BANDS := [["朝 6-10時", 6, 10], ["昼 10-14時", 10, 14], ["午後 14-17時", 14, 17], ["夕 17-21時", 17, 21], ["夜 21-6時", 21, 30]]


## The store's own site: forecast and actual visitors (来店希望) per time band, today and yesterday. A forecast is
## a forecast: ads, events, promotions and empty shelves move the actual numbers.
static func actual_vs_forecast_text(forecast: Array, today: Array, yesterday: Array) -> String:
	var sum := func(a: Array, lo: int, hi: int) -> float:
		var n := 0.0
		if a.size() != 24:
			return -1.0
		for h in range(lo, hi):
			n += float(a[h % 24])
		return n
	var rows: Array[String] = ["予測と実績（来店希望・人）　予測／今日／昨日"]
	for b in BANDS:
		var f: float = sum.call(forecast, b[1], b[2])
		var t: float = sum.call(today, b[1], b[2])
		var y: float = sum.call(yesterday, b[1], b[2])
		rows.append("%s　%d／%s／%s" % [b[0], int(round(f)), "－" if t < 0.0 else str(int(t)), "－" if y < 0.0 else str(int(y))])
	rows.append("※予測は広告・イベント・販促・品切れを含まない目安です。")
	return "\n".join(rows)


## The three busiest forecast hours, in time order: "7時 約12人・8時 約12人・18時 約9人".
static func peak_hours_text(by_hour: Array) -> String:
	var hours: Array = range(24)
	hours.sort_custom(func(a, b): return float(by_hour[a]) > float(by_hour[b]) or (float(by_hour[a]) == float(by_hour[b]) and a < b))
	var top: Array = hours.slice(0, 3)
	top.sort()
	return "・".join(top.map(func(h): return "%d時 約%d人" % [h, int(round(float(by_hour[h])))]))


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
