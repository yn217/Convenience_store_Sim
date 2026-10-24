class_name FixtureCard
extends Node
## Selected-fixture block of the inspector window (mockup 'インスペクタ'): thumbnail, name, status and category
## chips, size and price tiles, shelf stock with a bar, today's sales and gross profit, and 商品を補充. It sits right
## under the window title; the move / rotate / remove row and the collapsible 詳細 lines are scene nodes that the
## build controller wires. Pure view: it reads the snapshot and the store selection and never changes either.

const Hud := preload("res://scripts/presentation/game_hud.gd")
const NONE_TEXT := "未選択"
const NO_SHELF_TEXT := "棚なし"
const ROW_LABELS := ["在庫・陳列状況", "本日の売上", "本日の粗利"]
const RESTOCK_TAB := "商品"
const DETAILS_CLOSED := "詳細  ▸"
const DETAILS_OPEN := "詳細  ▾"
const CATEGORY_NAMES := {
	"bread": "パン", "dessert": "デザート", "drink": "飲料", "ice_cream": "アイス",
	"instant_noodle": "カップ麺", "oden": "おでん", "rice_ball": "おにぎり", "snack": "おかし",
}
const STATUS_NAMES := {"SETUP": "設置中", "OPEN": "営業中", "CLOSING": "閉店中"}

var _world: Node2D
var _snap: Dictionary = {}
var _block: VBoxContainer
var _thumb: TextureRect
var _name: Label
var _status: Label
var _category: Label
var _size: Label
var _price: Label
var _restock: Button
var _details_toggle: Button
var _details: Control     # scene nodes, cached in _ready: the section wrap later moves them into the window card
var _actions: Control
var _details_open := false
var _rows: Array = []   # per row: {box, caption, bar, value}
var _shelf_title: Label
var _shelf_list: VBoxContainer   # the products on this fixture's shelves: icon, name, price, 価格変更
var _shelf_key := ""             # what the list was built from; rebuilt only when it changes
var _set_goods: Button


@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	_world = get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	_details = get_node("../Layout/MainArea/FixtureInspector/Scroll/Body/Details")
	_actions = get_node("../Layout/MainArea/FixtureInspector/Scroll/Body/Actions")
	_block = VBoxContainer.new()
	_block.name = "FixtureBlock"
	_block.add_theme_constant_override("separation", 10)
	_body.add_child(_block)
	_body.move_child(_block, 1)   # directly under the window title ("インスペクタ" is child 0)
	_build_top()
	_build_tiles()
	_rows.append(_build_row(_block))
	var sales := HBoxContainer.new()
	sales.add_theme_constant_override("separation", 12)
	_block.add_child(sales)
	_rows.append(_build_row(sales))
	_rows.append(_build_row(sales))
	_shelf_title = Label.new()
	_shelf_title.text = "棚の商品"
	_shelf_title.theme_type_variation = &"CardTitle"
	_block.add_child(_shelf_title)
	_shelf_list = VBoxContainer.new()
	_shelf_list.name = "ShelfProducts"
	_shelf_list.add_theme_constant_override("separation", 6)
	_block.add_child(_shelf_list)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_block.add_child(actions)
	_restock = Button.new()
	_restock.text = "商品を補充"
	_restock.theme_type_variation = &"PrimaryButton"
	_restock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restock.pressed.connect(_open_restock)
	actions.add_child(_restock)
	_set_goods = Button.new()
	_set_goods.name = "PriceSetButton"
	_set_goods.text = "価格を設定"
	_set_goods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_goods.pressed.connect(_open_prices)
	actions.add_child(_set_goods)
	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.focus_mode = Control.FOCUS_NONE
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_toggle_details)
	_block.add_child(_details_toggle)
	if _world != null:
		_world.selection_changed.connect(func(_tile): _render())
	_render()


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	_render()


func _build_top() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_block.add_child(top)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"InfoTile"
	frame.custom_minimum_size = Vector2(80, 80)
	top.add_child(frame)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(64, 64)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_thumb)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	top.add_child(column)
	_name = Label.new()
	_name.theme_type_variation = &"InspectorName"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_name)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	column.add_child(chips)
	_status = _chip(chips, "StatusChip")
	_category = _chip(chips, "Chip")


func _chip(parent: Node, variation: StringName) -> Label:
	var box := PanelContainer.new()
	box.theme_type_variation = variation
	var label := Label.new()
	label.theme_type_variation = &"ChipLabel"
	box.add_child(label)
	parent.add_child(box)
	return label


func _build_tiles() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_block.add_child(row)
	_size = _tile(row, "サイズ")
	_price = _tile(row, "価格")


func _tile(parent: Node, caption_text: String) -> Label:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"InfoTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	tile.add_child(column)
	var caption := Label.new()
	caption.text = caption_text
	caption.theme_type_variation = &"CardTitle"
	column.add_child(caption)
	var value := Label.new()
	value.theme_type_variation = &"TileValue"
	column.add_child(value)
	parent.add_child(tile)
	return value


## One figure with its caption and a thin bar: the shelf stock (full width) or one of the sales figures (half width).
func _build_row(parent: Node) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var caption := Label.new()
	caption.theme_type_variation = &"CardTitle"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.theme_type_variation = &"TileValue"
	head.add_child(caption)
	head.add_child(value)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size.y = UiTheme.BAR_HEIGHT
	box.add_child(bar)
	parent.add_child(box)
	return {"box": box, "caption": caption, "bar": bar, "value": value}


func _render() -> void:
	var fid: String = _world.selected_fixture_id() if _world != null else ""
	var inst := _find_instance(fid)
	var catalog: FixtureCatalog = _world.fixture_catalog if _world != null else null
	var def: Dictionary = catalog.get_type(inst["type_id"]) if (not inst.is_empty() and catalog != null) else {}
	var has_fixture := not def.is_empty()
	_block.visible = has_fixture
	_set_actions_visible(has_fixture)
	_set_details_visible(has_fixture and _details_open)
	if not has_fixture:
		_name.text = NONE_TEXT
		for row in _rows:
			row["box"].visible = false
		return
	_name.text = def["display_name"]
	var has_shelf := capacity(def) > 0
	_shelf_title.visible = has_shelf
	_shelf_list.visible = has_shelf
	_set_goods.visible = has_shelf
	if has_shelf:
		_refresh_shelf(fid, catalog_products())
	_thumb.texture = FixtureThumbnails.texture(inst["type_id"])
	_set_chip(_status, status_text(str(_snap.get("business_state", "SETUP"))))
	_set_chip(_category, category_text(def))
	_size.text = "%d×%d" % [int(def["footprint"]["w"]), int(def["footprint"]["h"])]
	_price.text = Hud.format_yen(int(def.get("placement_cost_yen", 0)))
	_restock.visible = capacity(def) > 0
	var money: Dictionary = _snap.get("fixture_money", {}).get(fid, {})
	var sales := {"revenue_yen": int(money.get("revenue_yen", 0)), "gross_profit_yen": int(money.get("gross_profit_yen", 0))}
	var totals: Dictionary = _snap.get("today", {})
	var rows := FixtureCard.rows(def, _snap.get("shelf_stock", {}).get(fid, {}), sales, totals)
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		row["box"].visible = true
		row["caption"].text = rows[i]["label"]
		row["value"].text = rows[i]["value_text"]
		row["bar"].value = rows[i]["ratio"]
		row["bar"].visible = rows[i]["value_text"] != NO_SHELF_TEXT or i != 0   # no shelves, no stock bar


func _set_chip(label: Label, text: String) -> void:
	label.text = text
	label.get_parent().visible = text != ""


func _set_actions_visible(show: bool) -> void:
	_actions.visible = show


func _set_details_visible(show: bool) -> void:
	_details.visible = show
	_details_toggle.text = DETAILS_OPEN if _details_open else DETAILS_CLOSED


func _toggle_details() -> void:
	_details_open = not _details_open
	_render()


## 価格を設定: opens the 商品 tab's price section scrolled to the first SKU on this fixture's shelves.
func _open_prices() -> void:
	var fid: String = _world.selected_fixture_id() if _world != null else ""
	var skus: Array = _snap.get("shelf_skus", {}).get(fid, {}).values()
	var main := get_parent()
	if main != null and main.has_method("open_prices_for"):
		main.open_prices_for(skus)


## 商品を補充: opens the 商品 tab at the restock section of the selected fixture.
func _open_restock() -> void:
	var main := get_parent()
	if main != null and main.has_method("open_restock_section"):
		main.open_restock_section()
	elif main != null and main.has_method("open_screen_tab"):
		main.open_screen_tab(RESTOCK_TAB)


## The product catalog the world uses for SKU names and icons (set by the app), or null before it is wired.
func catalog_products() -> ProductCatalog:
	return _world.product_catalog if _world != null else null


## Rebuilds the 棚の商品 list when the fixture's shelf contents or prices change.
func _refresh_shelf(fid: String, products: ProductCatalog) -> void:
	var rows := shelf_product_rows(_snap.get("shelf_skus", {}).get(fid, {}), _snap.get("product_price_overrides", {}), products)
	var key := str(rows)
	if key == _shelf_key:
		return
	_shelf_key = key
	for c in _shelf_list.get_children():
		_shelf_list.remove_child(c)
		c.queue_free()
	if rows.is_empty():
		var none := Label.new()
		none.text = "棚に商品はありません"
		none.theme_type_variation = &"CardTitle"
		_shelf_list.add_child(none)
	for r in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ProductIcons.texture(products.get_sku(r["sku_id"]), 32) if products != null and products.skus.has(r["sku_id"]) else null
		line.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = r["name"] if int(r["slots"]) == 1 else "%s ×%d段" % [r["name"], int(r["slots"])]
		name_label.clip_text = true
		text.add_child(name_label)
		var price_label := Label.new()
		price_label.text = Hud.format_yen(int(r["price"]))
		price_label.theme_type_variation = &"TileValue"
		text.add_child(price_label)
		line.add_child(text)
		var change := Button.new()
		change.name = "PriceChange"
		change.text = "価格変更"
		change.focus_mode = Control.FOCUS_NONE
		var sku_id: String = r["sku_id"]
		change.pressed.connect(_open_price.bind(sku_id))
		line.add_child(change)
		_shelf_list.add_child(line)


## 価格変更 on one shelf product: the 商品 tab with that SKU's price field selected.
func _open_price(sku_id: String) -> void:
	var main := get_parent()
	if main != null and main.has_method("open_price_for"):
		main.open_price_for(sku_id)


## The products on a fixture's shelves: one row per SKU, in first-slot order, {sku_id, name, price, slots} where slots
## counts the shelf slots holding it. The price is the override when the player set one, else the SKU's default sell
## price. Pure apart from the catalog lookup.
static func shelf_product_rows(slots: Dictionary, overrides: Dictionary, products: ProductCatalog) -> Array:
	var out: Array = []
	var by_sku := {}
	var slot_ids := slots.keys()
	slot_ids.sort()
	for slot_id in slot_ids:
		var sku_id: String = slots[slot_id]
		if by_sku.has(sku_id):
			by_sku[sku_id]["slots"] += 1
			continue
		var sku: Dictionary = products.get_sku(sku_id) if products != null else {}
		var default_price := int(sku.get("default_sell_price_yen", 0))
		var row := {
			"sku_id": sku_id,
			"name": String(sku.get("display_name", sku_id)),
			"price": int(overrides.get(sku_id, default_price)),
			"slots": 1,
		}
		by_sku[sku_id] = row
		out.append(row)
	return out


func _find_instance(fid: String) -> Dictionary:
	if fid == "":
		return {}
	for inst in _snap.get("fixtures", []):
		if inst["instance_id"] == fid:
			return inst
	return {}


## "¥120,000 ・ 1×2": price, then footprint as width x height.
static func price_line(def: Dictionary) -> String:
	return "%s ・ %d×%d" % [Hud.format_yen(int(def.get("placement_cost_yen", 0))), int(def["footprint"]["w"]), int(def["footprint"]["h"])]


## Status chip text from the real business state: 設置中 (SETUP), 営業中 (OPEN), 閉店中 (CLOSING); "" if unknown.
static func status_text(business_state: String) -> String:
	return STATUS_NAMES.get(business_state, "")


## Japanese names of the categories a fixture allows, in catalog order.
static func category_names(def: Dictionary) -> Array:
	var out: Array = []
	for c in def.get("allowed_categories", []):
		out.append(CATEGORY_NAMES.get(c, str(c)))
	return out


## Category chip text: the names joined with ・ ("" for a fixture that allows no category, such as a register).
static func category_text(def: Dictionary) -> String:
	var parts := category_names(def)
	var text := ""
	for i in parts.size():
		text += ("・" if i > 0 else "") + str(parts[i])
	return text


## Total units the fixture's shelves can hold (its slots; a fixture without slots uses capacity_units).
static func capacity(def: Dictionary) -> int:
	var total := 0
	for slot in def.get("shelf_slots", []):
		total += int(slot["capacity_units"])
	return total if total > 0 else int(def.get("capacity_units", 0))


## Stock figure: "units / capacity", or 棚なし for a fixture without room for stock.
static func stock_text(cap: int, units: int) -> String:
	return NO_SHELF_TEXT if cap <= 0 else "%d / %d" % [units, cap]


## The three rows of the block. `stock` is {slot_id: qty} of this fixture; `sales` holds this fixture's
## revenue and gross profit today; `totals` the store's (snapshot "today"). The sales and profit bars show
## this fixture's share of the store's today.
static func rows(def: Dictionary, stock: Dictionary, sales: Dictionary, totals: Dictionary) -> Array:
	var cap := capacity(def)
	var units := 0
	for qty in stock.values():
		units += int(qty)
	var revenue := int(sales.get("revenue_yen", 0))
	var gross := int(sales.get("gross_profit_yen", 0))
	return [
		{"label": ROW_LABELS[0], "ratio": ShelfDisplay.fill_ratio(units, cap), "value_text": stock_text(cap, units)},
		{"label": ROW_LABELS[1], "ratio": share(revenue, int(totals.get("revenue_yen", 0))), "value_text": Hud.format_yen(revenue)},
		{"label": ROW_LABELS[2], "ratio": share(gross, int(totals.get("gross_profit_yen", 0))), "value_text": Hud.format_yen(gross)},
	]


## part / whole clamped to 0..1; 0 when the store has nothing yet today.
static func share(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return clampf(float(part) / float(whole), 0.0, 1.0)
