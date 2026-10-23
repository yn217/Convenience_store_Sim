class_name StockController
extends Node
## Order (SCR-07) and shelf restock (SCR-08) panel in the inspector. Presentation only: it sends
## ORDER_STOCK / RESTOCK through AppRoot, previews nothing it cannot explain, and shows the
## rejection message when the command fails. Restock is offered for the selected fixture.

var _app: Node
var _products: ProductCatalog
var _fixtures: FixtureCatalog
var _snap: Dictionary = {}
var _seq: int = 0

var _order_sku: OptionButton
var _order_qty: LineEdit
var _backroom: Label
var _restock_box: VBoxContainer
var _restock_slot: OptionButton
var _restock_sku: OptionButton
var _restock_qty: LineEdit
var _restock_info: Label
var _status: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node, products: ProductCatalog, fixtures: FixtureCatalog) -> void:
	_app = app
	_products = products
	_fixtures = fixtures
	var title := Label.new()
	title.text = "在庫"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_backroom = Label.new()
	_backroom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_backroom)
	var order_row := HBoxContainer.new()
	_order_sku = OptionButton.new()
	_order_sku.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_sku.clip_text = true
	_order_sku.fit_to_longest_item = false
	_order_sku.custom_minimum_size = Vector2(60, 0)
	var ids := products.skus.keys()
	ids.sort()
	for sku_id in ids:
		var sku := products.get_sku(sku_id)
		_order_sku.add_item("%s ¥%d" % [sku["display_name"], sku["purchase_cost_yen"]])
		_order_sku.set_item_metadata(_order_sku.item_count - 1, sku_id)
	_order_qty = _qty_edit()
	var order_btn := Button.new()
	order_btn.text = "発注"
	order_btn.pressed.connect(submit_order)
	order_row.add_child(_order_sku)
	order_row.add_child(_order_qty)
	order_row.add_child(order_btn)
	_body.add_child(order_row)
	_restock_box = VBoxContainer.new()
	_restock_info = Label.new()
	_restock_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_restock_slot = OptionButton.new()
	_restock_slot.clip_text = true
	_restock_slot.fit_to_longest_item = false
	_restock_slot.custom_minimum_size = Vector2(60, 0)
	_restock_slot.item_selected.connect(func(_i): _fill_sku_choices())
	_restock_sku = OptionButton.new()
	_restock_sku.clip_text = true
	_restock_sku.fit_to_longest_item = false
	_restock_sku.custom_minimum_size = Vector2(60, 0)
	var restock_row := HBoxContainer.new()
	_restock_qty = _qty_edit()
	var restock_btn := Button.new()
	restock_btn.text = "補充"
	restock_btn.pressed.connect(submit_restock)
	restock_row.add_child(_restock_qty)
	restock_row.add_child(restock_btn)
	for c in [_restock_info, _restock_slot, _restock_sku, restock_row]:
		_restock_box.add_child(c)
	_restock_box.visible = false
	_body.add_child(_restock_box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)
	var world = _app.get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	if world != null:
		world.selection_changed.connect(func(_t): _refresh.call_deferred())


func _qty_edit() -> LineEdit:
	var e := LineEdit.new()
	e.text = "1"
	e.custom_minimum_size = Vector2(48, 0)
	e.select_all_on_focus = true
	return e


## Typed text -> quantity, or -1 when it is not a plain integer in 1..9999.
static func parse_qty_text(text: String) -> int:
	var t := text.strip_edges().replace(",", "")
	if t.is_empty() or t.length() > 4 or not t.is_valid_int() or t.begins_with("+") or t.begins_with("-"):
		return -1
	var n := t.to_int()
	return n if n >= 1 else -1


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	_refresh()


func _selected_fixture() -> Dictionary:
	var builder := _app.get_node_or_null("../BuildController")
	if builder == null or builder.selected_fixture_id == "":
		return {}
	for inst in _snap.get("fixtures", []):
		if inst["instance_id"] == builder.selected_fixture_id:
			return inst
	return {}


func _refresh() -> void:
	var stock: Dictionary = _snap.get("backroom_stock", {})
	if stock.is_empty():
		_backroom.text = "バックヤード: 在庫なし"
	else:
		var parts: Array[String] = []
		var ids := stock.keys()
		ids.sort()
		for id in ids:
			parts.append("%s ×%d" % [_products.get_sku(id)["display_name"], stock[id]])
		_backroom.text = "バックヤード: " + "、".join(parts)
	var inst := _selected_fixture()
	var def := _fixtures.get_type(inst["type_id"]) if not inst.is_empty() else {}
	_restock_box.visible = not def.is_empty() and not def["shelf_slots"].is_empty()
	if not _restock_box.visible:
		return
	var keep := _restock_slot.selected
	_restock_slot.clear()
	var held: Dictionary = _snap.get("shelf_stock", {}).get(inst["instance_id"], {})
	var skus: Dictionary = _snap.get("shelf_skus", {}).get(inst["instance_id"], {})
	for slot in def["shelf_slots"]:
		var sid: String = slot["slot_id"]
		var what: String = _products.get_sku(skus[sid])["display_name"] if skus.has(sid) else "空き"
		_restock_slot.add_item("%s: %s %d/%d" % [sid, what, int(held.get(sid, 0)), slot["capacity_units"]])
		_restock_slot.set_item_metadata(_restock_slot.item_count - 1, sid)
	_restock_slot.select(clampi(keep, 0, _restock_slot.item_count - 1))
	_restock_info.text = "%s に補充（準備中のみ）" % def["display_name"]
	_fill_sku_choices()


## SKUs the selected slot may hold: allowed category, and the SKU already there if the slot is in use.
func _fill_sku_choices() -> void:
	_restock_sku.clear()
	var inst := _selected_fixture()
	if inst.is_empty() or _restock_slot.item_count == 0:
		return
	var slot_id: String = _restock_slot.get_item_metadata(_restock_slot.selected)
	var ids := _products.skus.keys()
	ids.sort()
	for id in ids:
		if _fixtures.slot_accepts(inst["type_id"], slot_id, _products.get_sku(id)):
			_restock_sku.add_item(_products.get_sku(id)["display_name"])
			_restock_sku.set_item_metadata(_restock_sku.item_count - 1, id)


func submit_order() -> CommandResult:
	var qty := parse_qty_text(_order_qty.text)
	if qty < 1:
		return _reject(&"qty_invalid")
	var sku_id: String = _order_sku.get_item_metadata(_order_sku.selected)
	return _send({"kind": &"ORDER_STOCK", "sku_id": sku_id, "qty": qty})


func submit_restock() -> CommandResult:
	var inst := _selected_fixture()
	if inst.is_empty() or _restock_sku.item_count == 0:
		return _reject(&"unknown_instance")
	var qty := parse_qty_text(_restock_qty.text)
	if qty < 1:
		return _reject(&"qty_invalid")
	return _send({
		"kind": &"RESTOCK", "instance_id": inst["instance_id"],
		"slot_id": _restock_slot.get_item_metadata(_restock_slot.selected),
		"sku_id": _restock_sku.get_item_metadata(_restock_sku.selected), "qty": qty,
	})


func _reject(key: StringName) -> CommandResult:
	_status.text = CommandMessages.text(&"INVALID_OPERATION", key)
	return CommandResult.failure(&"INVALID_OPERATION", 0, key)


func _send(cmd: Dictionary) -> CommandResult:
	_seq += 1
	cmd["command_id"] = "ui_stock_%d" % _seq
	var r: CommandResult = _app.run_command(cmd)
	_status.text = "" if r.ok else CommandMessages.text(r.code, r.message_key)
	return r
