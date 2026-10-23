class_name FloatCards
extends Control
## Floating cards over the store view (mockup: store-overlay cards). Two cards anchored to the
## top-left of the store viewport: today's gameplay event, and a low-stock shelf alert.
## Display only; fed by GameHud.apply_snapshot. The container ignores mouse input so the store
## stays clickable; only the cards themselves block it.

const FIXTURES_PATH := "res://data/fixtures/mvp_v1.json"
const LOW_RATIO := 0.25
const MAX_LOW_STOCK_ROWS := 3
const CARD_WIDTH := 240
const MARGIN := 12
const EVENT_HIDDEN_STATUS := ["none", "undrawn", "no_data"]

var _store: Control
var _stack: VBoxContainer
var _event_card: PanelContainer
var _event_name: Label
var _event_remaining: Label
var _stock_card: PanelContainer
var _stock_rows: Label
var _catalog: FixtureCatalog


func _ready() -> void:
	name = "FloatCards"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 8)
	_stack.custom_minimum_size.x = CARD_WIDTH
	add_child(_stack)

	_event_card = _make_card("今日のイベント")
	_event_name = _add_body(_event_card)
	_event_remaining = _add_body(_event_card)
	_event_remaining.theme_type_variation = &"CardTitle"

	_stock_card = _make_card("在庫が少ない棚")
	_stock_rows = _add_body(_stock_card)


func setup(store: Control) -> void:
	_store = store
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	_follow_store()


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
	var rows := low_stock_rows(s.get("fixtures", []), s.get("shelf_stock", {}), _catalog)
	_stock_card.visible = not rows.is_empty()
	_stock_rows.text = "\n".join(rows)


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


## Pure: up to `limit` lines for shelf slots whose stock ratio is at or below LOW_RATIO.
## `fixtures` is the snapshot's placed-fixture list, `shelf_stock` maps instance -> slot -> units.
static func low_stock_rows(fixtures: Array, shelf_stock: Dictionary, catalog: FixtureCatalog, limit: int = MAX_LOW_STOCK_ROWS) -> Array[String]:
	var out: Array[String] = []
	if catalog == null:
		return out
	for inst in fixtures:
		if out.size() >= limit:
			break
		var def: Dictionary = catalog.get_type(String(inst["type_id"]))
		if def.is_empty():
			continue
		var per_slot: Dictionary = shelf_stock.get(String(inst["instance_id"]), {})
		var slots: Array = def.get("shelf_slots", [])
		for i in slots.size():
			if out.size() >= limit:
				break
			var slot: Dictionary = slots[i]
			var cap := int(slot.get("capacity_units", 0))
			if cap <= 0:
				continue
			var qty := int(per_slot.get(String(slot["slot_id"]), 0))
			if float(qty) / float(cap) <= LOW_RATIO:
				out.append("%s %d段: 残 %d / %d" % [def.get("display_name", ""), i + 1, qty, cap])
	return out


func _make_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size.x = CARD_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := Label.new()
	head.text = title
	head.theme_type_variation = &"CardTitle"
	box.add_child(head)
	_stack.add_child(card)
	return card


func _add_body(card: PanelContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.get_child(0).add_child(label)
	return label


func _follow_store() -> void:
	if _store == null or not is_instance_valid(_store):
		return
	var offset := _store.get_global_rect().position - get_global_rect().position
	_stack.position = offset + Vector2(MARGIN, MARGIN)
