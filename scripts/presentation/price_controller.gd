class_name PriceController
extends Node
## Sell-price editor (#10): one row per SKU in the inspector. Presentation only; it sends
## SET_PRICE through AppRoot and never edits GameState. Typed input is parsed here so that
## obviously malformed text (negative, decimal, letters) never becomes a command.

const MAX_DIGITS := 6

var _app: Node
var _products: ProductCatalog
var _rows: Dictionary = {}
var _status: Label
var _seq: int = 0

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


## Typed text -> price in yen, or -1 when it is not a plain positive integer.
static func parse_price_text(text: String) -> int:
	var t := text.strip_edges().replace(",", "").replace("¥", "")
	if t.is_empty() or t.length() > MAX_DIGITS or not t.is_valid_int() or t.begins_with("+") or t.begins_with("-"):
		return -1
	return maxi(t.to_int(), -1)


func setup(app: Node, products: ProductCatalog) -> void:
	_app = app
	_products = products
	var title := Label.new()
	title.text = "販売価格"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var ids := products.skus.keys()
	ids.sort()
	for sku_id in ids:
		var sku := products.get_sku(sku_id)
		var name_label := Label.new()
		name_label.text = "%s  原価 %s" % [sku["display_name"], GameHud.format_yen(sku["purchase_cost_yen"])]
		name_label.clip_text = true
		list.add_child(name_label)
		var row := HBoxContainer.new()
		var edit := LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text = str(sku["default_sell_price_yen"])
		edit.select_all_on_focus = true
		var apply := Button.new()
		apply.text = "変更"
		apply.pressed.connect(submit.bind(sku_id, edit))
		edit.text_submitted.connect(func(_t): submit(sku_id, edit))
		row.add_child(edit)
		row.add_child(apply)
		list.add_child(row)
		_rows[sku_id] = edit
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)


func apply_snapshot(snap: Dictionary) -> void:
	var overrides: Dictionary = snap.get("product_price_overrides", {})
	for sku_id in _rows:
		var edit: LineEdit = _rows[sku_id]
		if edit.has_focus():
			continue
		var price: int = int(overrides.get(sku_id, _products.get_sku(sku_id)["default_sell_price_yen"]))
		var shown := str(price)
		if edit.text != shown:   # assigning to a LineEdit is not free even when nothing changes
			edit.text = shown


func submit(sku_id: String, edit: LineEdit) -> CommandResult:
	var price := parse_price_text(edit.text)
	if price < 1:
		_status.text = CommandMessages.text(&"INVALID_OPERATION", &"price_invalid")
		_reset(sku_id, edit)
		return CommandResult.failure(&"INVALID_OPERATION", 0, &"price_invalid")
	_seq += 1
	var r: CommandResult = _app.run_command({
		"command_id": "ui_price_%d" % _seq, "kind": &"SET_PRICE", "sku_id": sku_id, "price_yen": price,
	})
	_status.text = "" if r.ok else CommandMessages.text(r.code, r.message_key)
	if not r.ok:
		_reset(sku_id, edit)
	return r


func _reset(sku_id: String, edit: LineEdit) -> void:
	var snap: Dictionary = _app.state.snapshot()
	edit.text = str(int(snap["product_price_overrides"].get(sku_id, _products.get_sku(sku_id)["default_sell_price_yen"])))
