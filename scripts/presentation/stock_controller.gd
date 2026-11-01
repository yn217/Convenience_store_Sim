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
var _order_row: HBoxContainer

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
		_order_sku.add_icon_item(ProductIcons.texture(sku, 32), "%s ¥%d" % [sku["display_name"], sku["purchase_cost_yen"]])
		_order_sku.set_item_metadata(_order_sku.item_count - 1, sku_id)
	_order_qty = _qty_edit()
	_order_qty.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var order_btn := Button.new()
	order_btn.text = "発注"
	order_btn.theme_type_variation = &"PrimaryButton"
	order_btn.icon = UiIcons.texture("cart", 22)
	order_btn.custom_minimum_size = Vector2(140, 44)
	order_btn.pressed.connect(submit_order)
	order_row.add_theme_constant_override("separation", 10)
	order_row.add_child(_order_sku)
	order_row.add_child(_stepper(_order_qty))
	order_row.add_child(order_btn)
	_body.add_child(order_row)
	_order_row = order_row
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


## The 2026-11-01 mockup look (MockupChrome): the order controls at the mockup's spots on the 商品 page, over frames
## drawn in code (the dropdown, the - 1 + stepper, the orange 発注 button). `page` is the page's Control, in content px.
func mockup_layout(page: Control) -> void:
	var font := MockStyle.font("ExtraBold")
	_place(page, _backroom, Rect2(382, 8, 300, 42))
	MockStyle.style_label(_backroom, 19, MockStyle.INK)
	MockStyle.shape(page, Rect2(40, 68, 548, 58), {"top": Color("fffdf9"), "bottom": Color("f9ece2"), "border": Color("c9ab98"), "border_width": 2.0,
		"radius": 10.0, "shadow": Color(0.4, 0.25, 0.15, 0.18), "shadow_offset": Vector2(0, 2)})
	MockStyle.label(page, "▼", Rect2(548, 68, 34, 58), 18, Color("4a3a3a"), HORIZONTAL_ALIGNMENT_CENTER)
	_place(page, _order_sku, Rect2(46, 70, 500, 54))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_order_sku.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_order_sku.add_theme_icon_override("arrow", ImageTexture.new())   # the ▼ is drawn beside it
	_order_sku.add_theme_font_override("font", font)
	_order_sku.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		_order_sku.add_theme_color_override(c, MockStyle.INK)
	_order_sku.add_theme_constant_override("h_separation", 18)
	_order_sku.add_theme_constant_override("icon_max_width", 64)
	for i in _order_sku.item_count:
		_order_sku.set_item_icon(i, ProductIcons.texture(_products.get_sku(_order_sku.get_item_metadata(i)), 64))
	MockStyle.shape(page, Rect2(620, 72, 158, 46), {"top": Color("fffdf9"), "bottom": Color("f6ebe3"), "border": Color("c9ab98"), "border_width": 2.0,
		"radius": 8.0, "shadow": Color(0.4, 0.25, 0.15, 0.18), "shadow_offset": Vector2(0, 2)})
	for x in [664, 732]:
		var bar := ColorRect.new()
		bar.color = Color("dcc8ba")
		bar.position = Vector2(x, 78)
		bar.size = Vector2(2, 34)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(bar)
	var stepper := _order_qty.get_parent()
	_place(page, _order_qty, Rect2(666, 74, 66, 42))
	for st in ["normal", "focus", "read_only"]:
		_order_qty.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_order_qty.add_theme_font_override("font", font)
	_order_qty.add_theme_font_size_override("font_size", 24)
	_order_qty.add_theme_color_override("font_color", MockStyle.INK)
	var steps := stepper.get_children()
	for i in steps.size():
		var b := steps[i] as Button
		_place(page, b, Rect2(622, 72, 42, 46) if i == 0 else Rect2(734, 72, 42, 46))
		_flat(b)
		b.text = "−" if i == 0 else "＋"
		MockStyle.style_label(b, 26, Color("2a2020"), "Black")
		for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color("2a2020"))
	var order_btn := _order_row.get_child(_order_row.get_child_count() - 1) as Button
	_place(page, order_btn, Rect2(802, 64, 196, 62))
	order_btn.text = ""
	order_btn.icon = null
	order_btn.tooltip_text = "発注"
	_flat(order_btn)
	MockStyle.shape(order_btn, Rect2(Vector2.ZERO, order_btn.size), {"top": Color("ffb21e"), "bottom": Color("e1500a"), "border": Color("ffc35a"),
		"border_width": 2.5, "radius": 12.0, "gloss": 0.35, "shadow": Color(0.5, 0.2, 0.0, 0.35), "shadow_offset": Vector2(0, 3)})
	MockStyle.picture(order_btn, MockStyle.glyph("cart", 96), Rect2(30, 13, 40, 36))
	MockStyle.label(order_btn, "発注", Rect2(84, 0, 100, 62), 31, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "Black", 3, Color("a8400a"))
	_place(page, _status, Rect2(46, 126, 900, 20))
	_status.add_theme_font_size_override("font_size", 14)


static func _place(page: Control, c: Control, r: Rect2) -> void:
	c.reparent(page, false)
	c.custom_minimum_size = Vector2.ZERO
	c.size_flags_horizontal = Control.SIZE_FILL
	c.position = r.position
	c.size = r.size


static func _flat(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## A quantity field between - and + buttons (1..9999; a typed value is still checked by parse_qty_text).
func _stepper(edit: LineEdit) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for d in [-1, 1]:
		var b := Button.new()
		b.text = "−" if d < 0 else "+"
		b.theme_type_variation = &"StepButton"
		b.custom_minimum_size = Vector2(38, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			var q := parse_qty_text(edit.text)
			edit.text = str(clampi((q if q > 0 else 1) + d, 1, 9999)))
		box.add_child(b)
	box.add_child(edit)
	box.move_child(edit, 1)
	return box


func _qty_edit() -> LineEdit:
	var e := LineEdit.new()
	e.text = "1"
	e.custom_minimum_size = Vector2(56, 0)
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


## The 発注 row (the order section), for MainLayout to scroll into view.
func order_section() -> Control:
	return _order_row


## The restock box of the selected fixture (hidden until a shelf is selected), for MainLayout to scroll into view.
func restock_section() -> Control:
	return _restock_box


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
			_restock_sku.add_icon_item(ProductIcons.texture(_products.get_sku(id), 32), _products.get_sku(id)["display_name"])
			_restock_sku.set_item_metadata(_restock_sku.item_count - 1, id)
	# A slot may take several categories (#147: onigiri or bento): start on the first SKU with backroom stock.
	var stock: Dictionary = _snap.get("backroom_stock", {})
	for i in _restock_sku.item_count:
		if int(stock.get(_restock_sku.get_item_metadata(i), 0)) > 0:
			_restock_sku.select(i)
			break


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
