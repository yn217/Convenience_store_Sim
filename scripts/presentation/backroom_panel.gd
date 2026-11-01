class_name BackroomPanel
extends Control
## バックヤード在庫一覧 (the user's 2026-11-01 sketch): a cream panel beside the 経営管理 window, its title on a dark plaque
## with a × button, a search field (product name) and the backroom stock as rows of picture, name and ×count, most
## first. Presentation only: fed with the snapshot's backroom_stock by StockController.

const RECT := Rect2(1622, 300, 292, 520)   # on the 1920x1080 screen, right of the window frame (it covers none of the window)
const ROW_H := 54

var _products: ProductCatalog
var _stock: Dictionary = {}
var _search: LineEdit
var _list: VBoxContainer
var _empty: Label


func setup(products: ProductCatalog) -> void:
	_products = products
	name = "BackroomPanel"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	MockStyle.shape(self, Rect2(0, 26, RECT.size.x, RECT.size.y - 26), {"top": Color("6e4c3c"), "bottom": Color("4a3026"), "border": Color("e2b273"),
		"border_width": 3.0, "radius": 22.0, "inner": Color("f6cf8f"), "inner_inset": 5.0, "shadow": Color(0, 0, 0, 0.4), "shadow_offset": Vector2(0, 5)})
	MockStyle.shape(self, Rect2(10, 70, RECT.size.x - 20, RECT.size.y - 82), {"top": Color("fff8ef"), "bottom": Color("f3e1d1"), "border": Color("e9cfb9"),
		"border_width": 2.0, "radius": 16.0})
	MockStyle.shape(self, Rect2(6, 2, RECT.size.x - 64, 62), {"top": Color("4c3632"), "bottom": Color("2d1f1c"), "border": Color("e2b273"), "border_width": 2.5,
		"radius": 18.0, "inner": Color(1, 0.85, 0.55, 0.25)})
	MockStyle.picture(self, MockStyle.art("box"), Rect2(14, 14, 36, 36))
	MockStyle.label(self, "バックヤード在庫一覧", Rect2(52, 4, RECT.size.x - 116, 58), 17, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold", 2, Color(0, 0, 0, 0.35))
	var close := MockStyle.button(self, Rect2(RECT.size.x - 54, 8, 52, 52), "閉じる")
	MockStyle.shape(close, Rect2(1, 1, 50, 50), {"kind": UiShape.Kind.CIRCLE, "top": Color("7a4232"), "bottom": Color("3e1f15"), "border": Color("f3e2c4"),
		"border_width": 2.5, "gloss": 0.2})
	MockStyle.label(close, "✕", Rect2(0, 0, 52, 52), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "Black")
	close.pressed.connect(func(): visible = false)
	_search = LineEdit.new()
	_search.placeholder_text = "商品名で検索…"
	var box := MockStyle.field_box(20)
	box.content_margin_left = 46
	_search.add_theme_stylebox_override("normal", box)
	_search.add_theme_stylebox_override("focus", box)
	MockStyle.style_label(_search, 18, MockStyle.INK, "Bold")
	_search.add_theme_color_override("font_placeholder_color", Color("a08a7c"))
	_search.position = Vector2(22, 82)
	_search.size = Vector2(RECT.size.x - 44, 42)
	_search.text_changed.connect(func(_t): _render())
	add_child(_search)
	MockStyle.picture(self, MockStyle.glyph("search", 64), Rect2(36, 91, 24, 24), Color("6a5a52"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22, 138)
	scroll.size = Vector2(RECT.size.x - 40, RECT.size.y - 156)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.custom_minimum_size.x = RECT.size.x - 56
	scroll.add_child(_list)
	_empty = MockStyle.label(self, "在庫はありません", Rect2(22, 150, RECT.size.x - 44, 40), 18, MockStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, "Bold")


func set_stock(stock: Dictionary) -> void:
	_stock = stock
	if visible:
		_render()


func toggle() -> void:
	visible = not visible
	if visible:
		_render()


## The stock rows shown: [sku_id, count], most first, filtered by the search text (part of the name).
static func rows(stock: Dictionary, products: ProductCatalog, query: String) -> Array:
	var out: Array = []
	for id in stock:
		if int(stock[id]) <= 0:
			continue
		if query != "" and String(products.get_sku(id)["display_name"]).find(query) < 0:
			continue
		out.append([id, int(stock[id])])
	out.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
	return out


func _render() -> void:
	for c in _list.get_children():
		c.queue_free()
	var r := rows(_stock, _products, _search.text.strip_edges())
	_empty.visible = r.is_empty()
	for e in r:
		var sku := _products.get_sku(e[0])
		var row := Control.new()
		row.custom_minimum_size = Vector2(RECT.size.x - 56, ROW_H)
		_list.add_child(row)
		var line := ColorRect.new()
		line.color = Color(0.82, 0.72, 0.62, 0.55)
		line.position = Vector2(4, ROW_H - 1)
		line.size = Vector2(RECT.size.x - 64, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		MockStyle.picture(row, ProductIcons.trimmed(sku, 38), Rect2(2, 6, 48, ROW_H - 12))
		MockStyle.label(row, sku["display_name"], Rect2(52, 0, RECT.size.x - 140, ROW_H), 15, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		MockStyle.shape(row, Rect2(RECT.size.x - 86, 12, 48, 30), {"top": Color("f7efe6"), "bottom": Color("e9dccf"), "radius": 15.0})
		MockStyle.label(row, "x%d" % e[1], Rect2(RECT.size.x - 86, 12, 48, 30), 16, MockStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, "ExtraBold")
