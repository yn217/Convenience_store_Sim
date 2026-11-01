class_name PriceController
extends Node
## Sell-price editor (#10): one row per SKU in the inspector. Presentation only; it sends
## SET_PRICE through AppRoot and never edits GameState. Typed input is parsed here so that
## obviously malformed text (negative, decimal, letters) never becomes a command.

const MAX_DIGITS := 6
## Price table column widths (the name column takes the rest).
const ICON := 40
const NAME_W := 180
const PRICE_W := 96
const COST_W := 72
const MARGIN_W := 72
const RATE_W := 72
const BUTTON_W := 84

var _app: Node
var _products: ProductCatalog
var _rows: Dictionary = {}
var _margins: Dictionary = {}   # sku_id -> [粗利 label, 粗利率 label], derived from the shown price (display only)
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
	list.add_theme_constant_override("separation", 4)
	var head := _table_row()
	for col in [["", ICON + NAME_W], ["販売価格", PRICE_W], ["原価", COST_W], ["粗利", MARGIN_W], ["粗利率", RATE_W], ["", BUTTON_W]]:
		head.add_child(_cell(col[0], col[1], &"ColumnHeader"))
	head.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(head)
	var ids := products.skus.keys()
	ids.sort()
	for sku_id in ids:
		var sku := products.get_sku(sku_id)
		var row := _table_row()
		var icon := TextureRect.new()
		icon.texture = ProductIcons.texture(sku, 36)
		icon.custom_minimum_size = Vector2(ICON, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_label := _cell(sku["display_name"], NAME_W, &"")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(PRICE_W, 0)
		edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		edit.text = str(sku["default_sell_price_yen"])
		edit.select_all_on_focus = true
		row.add_child(edit)
		row.add_child(_cell(GameHud.format_yen(sku["purchase_cost_yen"]), COST_W, &""))
		var margin := _cell("", MARGIN_W, &"GoodLabel")
		var rate := _cell("", RATE_W, &"")
		row.add_child(margin)
		row.add_child(rate)
		var apply := Button.new()
		apply.text = "変更"
		apply.custom_minimum_size = Vector2(BUTTON_W, 0)
		apply.pressed.connect(submit.bind(sku_id, edit))
		edit.text_submitted.connect(func(_t): submit(sku_id, edit))
		row.add_child(apply)
		list.add_child(row)
		_rows[sku_id] = edit
		_margins[sku_id] = [margin, rate]
		_show_margin(sku_id, int(sku["default_sell_price_yen"]))
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
			_show_margin(sku_id, price)


## 粗利 = price - cost and 粗利率 = 粗利 / price of the shown price (display only; the sale uses the game's price).
static func margin_text(price: int, cost: int) -> Array:
	if price < 1:
		return ["—", "—"]
	return [GameHud.format_yen(price - cost), "%.1f%%" % (100.0 * float(price - cost) / float(price))]


func _show_margin(sku_id: String, price: int) -> void:
	var t := margin_text(price, int(_products.get_sku(sku_id)["purchase_cost_yen"]))
	_margins[sku_id][0].text = t[0]
	_margins[sku_id][1].text = t[1]
	_margins[sku_id][0].theme_type_variation = &"GoodLabel" if price >= int(_products.get_sku(sku_id)["purchase_cost_yen"]) else &"AccentLabel"


static func _table_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


static func _cell(text: String, width: int, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if variation != &"":
		l.theme_type_variation = variation
	return l


## The price field of one SKU (null for an unknown SKU), for MainLayout to scroll to.
func price_field(sku_id: String) -> LineEdit:
	return _rows.get(sku_id)


## 価格変更 from the inspector: the field of this SKU takes focus with its text selected. Unknown SKUs do nothing.
func focus_sku(sku_id: String) -> void:
	var edit := price_field(sku_id)
	if edit != null:
		edit.grab_focus()
		edit.select_all()


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
	if r.ok:
		_show_margin(sku_id, price)
	else:
		_reset(sku_id, edit)
	return r


func _reset(sku_id: String, edit: LineEdit) -> void:
	var snap: Dictionary = _app.state.snapshot()
	edit.text = str(int(snap["product_price_overrides"].get(sku_id, _products.get_sku(sku_id)["default_sell_price_yen"])))
