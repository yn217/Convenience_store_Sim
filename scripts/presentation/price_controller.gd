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
const ROW_H := 54   # a row of the mockup's price list

var _app: Node
var _products: ProductCatalog
var _rows: Dictionary = {}
var _badges: Dictionary = {}    # sku_id -> the 人気 badge of the mockup list (today's best seller)
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
	var best: Array = snap.get("best_sellers_today", [])
	var top_id := String(best[0]["sku_id"]) if not best.is_empty() else ""
	for id in _badges:
		(_badges[id] as Control).visible = id == top_id
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


## The 2026-11-01 mockup look (MockupChrome): the price rows as the mockup draws them (product picture, name, the
## price field and 変更 button pictures, columns under the page's own headings), in a scrolling list over `area`
## (content px). The fields replace the table's; the commands are the same.
func mockup_list(page: Control, area: Rect2) -> void:
	var font := MockStyle.font("ExtraBold")
	var scroll := ScrollContainer.new()
	scroll.name = "MockupPriceList"
	scroll.position = area.position
	scroll.size = area.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.custom_minimum_size.x = area.size.x - 12
	scroll.add_child(list)
	var ids := _products.skus.keys()
	ids.sort()
	for sku_id in ids:
		var sku := _products.get_sku(sku_id)
		var row := Control.new()
		row.custom_minimum_size = Vector2(area.size.x - 12, ROW_H)
		list.add_child(row)
		var line := ColorRect.new()   # the thin rule under each row
		line.color = Color(0.82, 0.72, 0.62, 0.55)
		line.position = Vector2(4, ROW_H - 1)
		line.size = Vector2(area.size.x - 20, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var icon := TextureRect.new()
		icon.texture = ProductIcons.trimmed(sku, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(24, 2)
		icon.size = Vector2(76, ROW_H - 6)
		row.add_child(icon)
		row.add_child(_mock_label(sku["display_name"], Rect2(117, 0, 220, ROW_H), 21, MockupChrome.INK, HORIZONTAL_ALIGNMENT_LEFT, font))
		var badge := _popular_badge()
		badge.position = Vector2(310, (ROW_H - 28) / 2.0)
		badge.visible = false
		row.add_child(badge)
		_badges[sku_id] = badge
		var edit := LineEdit.new()
		var box := MockStyle.field_box(8)
		box.content_margin_right = 36   # the arrows on the right
		box.content_margin_left = 34    # the ¥ on the left
		edit.add_theme_stylebox_override("normal", box)
		var focus := box.duplicate() as StyleBoxFlat
		focus.border_color = Color("3a7fd6")
		edit.add_theme_stylebox_override("focus", focus)
		edit.add_theme_font_override("font", font)
		edit.add_theme_font_size_override("font_size", 22)
		edit.add_theme_color_override("font_color", MockupChrome.INK)
		edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
		edit.position = Vector2(455, (ROW_H - 40) / 2.0)
		edit.size = Vector2(126, 40)
		edit.text = str(sku["default_sell_price_yen"])
		edit.select_all_on_focus = true
		edit.text_submitted.connect(func(_t): submit(sku_id, edit))
		row.add_child(edit)
		row.add_child(_mock_label("¥", Rect2(edit.position.x + 12, edit.position.y + 3, 22, 40), 22, MockupChrome.INK, HORIZONTAL_ALIGNMENT_CENTER, font))
		var arrows := _mock_label("▲\n▼", Rect2(edit.position.x + 96, edit.position.y + 1, 26, 38), 14, Color("3a2a2a"), HORIZONTAL_ALIGNMENT_CENTER, font)
		arrows.add_theme_constant_override("line_spacing", -3)
		row.add_child(arrows)
		var sep := ColorRect.new()
		sep.color = Color("dcc8ba")
		sep.position = Vector2(edit.position.x + 94, edit.position.y + 6)
		sep.size = Vector2(1.5, 28)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sep)
		row.add_child(_mock_label(GameHud.format_yen(sku["purchase_cost_yen"]), Rect2(602, 0, 92, ROW_H), 20, MockupChrome.INK, HORIZONTAL_ALIGNMENT_CENTER, font))
		var margin := _mock_label("", Rect2(690, 0, 96, ROW_H), 22, MockupChrome.GREEN, HORIZONTAL_ALIGNMENT_CENTER, font)
		var rate := _mock_label("", Rect2(782, 0, 102, ROW_H), 20, MockupChrome.INK, HORIZONTAL_ALIGNMENT_CENTER, font)
		row.add_child(margin)
		row.add_child(rate)
		var apply := MockStyle.face_button(row, Rect2(895, (ROW_H - 42) / 2.0, 109, 42), "変更", Color("4f95e8"), Color("1d58b0"),
			Color("bcdcff"), Color.WHITE, 19, "pencil", 8.0)
		apply.pressed.connect(func(): submit(sku_id, edit))
		_rows[sku_id] = edit
		_margins[sku_id] = [margin, rate]
		_show_margin(sku_id, int(edit.text))


## The 人気 badge: a gold pill with a crown, on the row of today's best-selling product.
static func _popular_badge() -> Control:
	var s := UiShape.new()
	s.size = Vector2(78, 28)
	s.setup({"top": Color("ffe36a"), "bottom": Color("f2a91a"), "border": Color("c98a10"), "border_width": 1.5, "radius": 6.0, "gloss": 0.35})
	MockStyle.picture(s, MockStyle.glyph("crown", 64), Rect2(6, 4, 22, 20), Color.WHITE)
	MockStyle.label(s, "人気", Rect2(30, 0, 44, 28), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold", 2, Color("b37208"))
	return s


static func _mock_label(text: String, r: Rect2, size: int, color: Color, align: HorizontalAlignment, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


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
	if _margins[sku_id][0].has_theme_color_override("font_color"):   # the mockup rows colour by hand
		_margins[sku_id][0].add_theme_color_override("font_color", MockupChrome.GREEN if price >= int(_products.get_sku(sku_id)["purchase_cost_yen"]) else Color("c0392b"))


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
