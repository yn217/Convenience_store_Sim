class_name FloatCards
extends Control
## The notification column's cards, bottom right above the summary strip (UI Phase 4): today's gameplay event and
## the 在庫アラート card. The alert card is collapsed to one line with a count badge; a click expands it to up to 3
## shelves, each with a 選ぶ button that emits jump_requested (MainLayout selects that fixture). Toasts and sales
## pop-ups are drawn by CueLayer in the same column, which reads column_top / column_right from the group
## "notification_column". Display only; fed by GameHud.apply_snapshot. The container ignores the mouse; only the
## visible cards stop it.

signal jump_requested(tile: Vector2i)

const FIXTURES_PATH := "res://data/fixtures/mvp_v1.json"
const LOW_RATIO := 0.25
const MAX_LOW_STOCK_ROWS := 3
const CARD_WIDTH := 260
const GAP := 12
const EVENT_HIDDEN_STATUS := ["none", "undrawn", "no_data"]

## Column geometry in px, set by MainLayout: where the toast column starts (under the HUD), the card stack's distance
## from the bottom edge (above the summary strip), and its distance from the right edge (wider while the inspector
## is open, so the column never sits on top of it).
var column_top := 76.0
var column_bottom := 88.0
var column_right := 12.0

var _stack: VBoxContainer
var _event_card: PanelContainer
var _event_name: Label
var _event_remaining: Label
var _stock_card: PanelContainer
var _stock_toggle: Button
var _stock_count: Label
var _stock_list: VBoxContainer
var _stock_more: Label
var _stock_rows: Array[Dictionary] = []   # {row, label, button} for each of MAX_LOW_STOCK_ROWS
var _stock_entries: Array[Dictionary] = []
var _stock_open := false
var _catalog: FixtureCatalog


func _ready() -> void:
	name = "FloatCards"
	add_to_group("notification_column")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 8)
	_stack.custom_minimum_size.x = CARD_WIDTH
	add_child(_stack)

	_event_card = PanelContainer.new()
	var event_box := _card_frame(_event_card, "今日のイベント")
	# (the event card is added first, so it sits above the alert card in the stack)
	_event_name = _add_body(event_box)
	_event_remaining = _add_body(event_box)
	_event_remaining.theme_type_variation = &"CardTitle"

	_build_stock_card()


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	# The stack grows upwards from the summary strip, so it stays put when rows expand or collapse.
	_stack.position = Vector2(size.x - column_right - CARD_WIDTH, size.y - column_bottom - _stack.get_combined_minimum_size().y)


func apply_snapshot(s: Dictionary) -> void:
	var event_view: Dictionary = s.get("gameplay_event", {"status": "no_data"})
	var ev := event_card(event_view, int(s.get("time_sec", 0)))
	_event_card.visible = ev["visible"]
	if ev["visible"]:
		_event_name.text = ev["name"]
		_event_remaining.text = ev["remaining"]
		_event_remaining.visible = not String(ev["remaining"]).is_empty()

	if _catalog == null:
		_catalog = FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES_PATH))
	_stock_entries = low_stock_entries(s.get("fixtures", []), s.get("shelf_stock", {}), _catalog)
	_stock_card.visible = not _stock_entries.is_empty()
	_refresh_stock()


## Pure: visibility, title and remaining-time text for the event card.
static func event_card(view: Dictionary, time_sec: int) -> Dictionary:
	var status := String(view.get("status", "no_data"))
	if status in EVENT_HIDDEN_STATUS or not view.has("name_ja"):
		return {"visible": false, "name": "", "remaining": ""}
	var name_text := "%s: %s" % [EventText.STATUS_JA.get(status, status), view["name_ja"]]
	var remaining := ""
	if status == "scheduled":
		remaining = "開始まで %s" % EventText.clock(maxi(int(view["start_sec"]) - time_sec, 0))
	elif status == "active":
		remaining = "終了まで %s" % EventText.clock(maxi(int(view["end_sec"]) - time_sec, 0))
	return {"visible": true, "name": name_text, "remaining": remaining}


## Pure: every shelf slot whose stock ratio is at or below LOW_RATIO, in fixture order. Each entry has the
## fixture's tile (x, y), its display `label` and the slot's qty / capacity. `fixtures` is the snapshot's placed
## fixture list, `shelf_stock` maps instance -> slot -> units.
static func low_stock_entries(fixtures: Array, shelf_stock: Dictionary, catalog: FixtureCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if catalog == null:
		return out
	for inst in fixtures:
		var def: Dictionary = catalog.get_type(String(inst["type_id"]))
		if def.is_empty():
			continue
		var per_slot: Dictionary = shelf_stock.get(String(inst["instance_id"]), {})
		var slots: Array = def.get("shelf_slots", [])
		for i in slots.size():
			var slot: Dictionary = slots[i]
			var cap := int(slot.get("capacity_units", 0))
			if cap <= 0:
				continue
			var qty := int(per_slot.get(String(slot["slot_id"]), 0))
			if float(qty) / float(cap) <= LOW_RATIO:
				out.append({
					"instance_id": String(inst["instance_id"]), "x": int(inst["x"]), "y": int(inst["y"]),
					"label": "%s %d段: 残 %d / %d" % [def.get("display_name", ""), i + 1, qty, cap],
				})
	return out


func _build_stock_card() -> void:
	_stock_card = PanelContainer.new()
	var box := _card_frame(_stock_card, "")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	_stock_toggle = Button.new()
	_stock_toggle.flat = true
	_stock_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stock_toggle.focus_mode = Control.FOCUS_NONE
	_stock_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stock_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_toggle.tooltip_text = "開いて残りわずかの棚を見る"
	_stock_toggle.pressed.connect(_toggle_stock)
	head.add_child(_stock_toggle)
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"AlertBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_count = Label.new()
	_stock_count.theme_type_variation = &"AlertCount"
	badge.add_child(_stock_count)
	head.add_child(badge)

	_stock_list = VBoxContainer.new()
	_stock_list.add_theme_constant_override("separation", 4)
	box.add_child(_stock_list)
	for i in MAX_LOW_STOCK_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var jump := Button.new()
		jump.text = "選ぶ"
		jump.focus_mode = Control.FOCUS_NONE
		jump.custom_minimum_size = Vector2(56, 0)
		jump.tooltip_text = "この棚を選択する"
		jump.pressed.connect(_on_jump.bind(i))
		row.add_child(jump)
		_stock_list.add_child(row)
		_stock_rows.append({"row": row, "label": label, "button": jump})
	_stock_more = Label.new()
	_stock_more.theme_type_variation = &"CardTitle"
	box.add_child(_stock_more)


## A framed notification card (added to the column in order) with an optional title; returns its content column.
func _card_frame(card: PanelContainer, title: String) -> VBoxContainer:
	card.theme_type_variation = &"Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size.x = CARD_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	if title != "":
		var head := Label.new()
		head.text = title
		head.theme_type_variation = &"CardTitle"
		box.add_child(head)
	_stack.add_child(card)
	return box


func _add_body(box: VBoxContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return label


func _toggle_stock() -> void:
	_stock_open = not _stock_open
	_refresh_stock()


## Collapsed: the title with the count badge. Expanded: up to MAX_LOW_STOCK_ROWS shelves and "ほか N 件".
func _refresh_stock() -> void:
	var total := _stock_entries.size()
	_stock_count.text = str(total)
	_stock_toggle.text = "在庫アラート  %s" % ("▾" if _stock_open else "▸")
	_stock_list.visible = _stock_open
	_stock_more.visible = _stock_open and total > MAX_LOW_STOCK_ROWS
	_stock_more.text = "ほか %d 件" % (total - MAX_LOW_STOCK_ROWS)
	for i in MAX_LOW_STOCK_ROWS:
		var r: Dictionary = _stock_rows[i]
		var shown := i < total
		(r["row"] as Control).visible = shown
		if shown:
			(r["label"] as Label).text = _stock_entries[i]["label"]


func _on_jump(index: int) -> void:
	if index < _stock_entries.size():
		var e: Dictionary = _stock_entries[index]
		jump_requested.emit(Vector2i(int(e["x"]), int(e["y"])))
