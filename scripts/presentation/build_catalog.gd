class_name BuildCatalog
extends RefCounted
## Build catalog window (mockup 建設 什器カタログ): category tabs, a card grid of the fixture types and the
## affordability / selection look. Presentation only: a click calls back into BuildController, which starts the
## placement exactly as before; the catalog never changes a price, a footprint or a command.

const ALL := &"all"
const SHELF := &"shelf"
const COLD := &"cold"
const COUNTER := &"counter"
const SERVICE := &"service"
const TABS := [[ALL, "すべて"], [SHELF, "棚"], [COLD, "冷蔵・冷凍"], [COUNTER, "カウンター"], [SERVICE, "設備"]]

## Product categories (fixture allowed_categories) that mark a cold case, and the ones that mark a counter appliance.
## A fixture that holds a cold product is 冷蔵・冷凍; one that holds only counter products (or none, the register) is
## カウンター; every other shelf is 棚. A fixture with no products that is not a register (ATM, copier, staff rooms) is 設備.
const COLD_PRODUCTS := ["drink", "dessert", "ice_cream", "daily_fresh"]
const COUNTER_PRODUCTS := ["oden", "coffee", "soft_serve", "frappe", "bakery", "pizza"]   # #131 / #130: made-to-order machines, ovens
const SERVICE_PRODUCTS := ["capsule_toy", "crane_prize"]   # #139: the capsule machines sit with the ATM and the copier

const CARD_SIZE := Vector2(108, 130)
const THUMB_SIZE := Vector2(100, 70)
const THUMB_PIXELS := Vector2i(192, 128)   # the cached source is 2x the drawn size, so it stays crisp
const COLUMNS := 3
const DIM := Color(1, 1, 1, 0.42)
const PRICE_UNAFFORDABLE := Color("ff6b6b")

static var _thumbs: Dictionary = {}

var _grid: GridContainer
var _cards: Dictionary = {}       # type_id -> Button
var _content: Dictionary = {}     # type_id -> Control holding the card's pictures and text (dimmed when unaffordable)
var _prices: Dictionary = {}      # type_id -> Label
var _costs: Dictionary = {}       # type_id -> int
var _categories: Dictionary = {}  # type_id -> StringName
var _tabs: Dictionary = {}        # category -> Button
var _category: StringName = ALL
var _cash: int = 0
var _selected: String = ""


## Builds the tabs above `anchor` (the scroll that holds the grid) and one card per fixture type, in data order.
func setup(grid: GridContainer, anchor: Node, catalog: FixtureCatalog, on_pick: Callable) -> void:
	_grid = grid
	grid.columns = COLUMNS
	var body := anchor.get_parent()
	var tab_row := HBoxContainer.new()
	tab_row.name = "CategoryTabs"
	tab_row.add_theme_constant_override("separation", 4)
	body.add_child(tab_row)
	body.move_child(tab_row, anchor.get_index())
	for entry in TABS:
		var tab := Button.new()
		tab.name = "Tab_" + str(entry[0])
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		tab.pressed.connect(set_category.bind(entry[0]))
		tab_row.add_child(tab)
		_tabs[entry[0]] = tab
	for type_id in catalog.types:
		var def := catalog.get_type(type_id)
		_categories[type_id] = category_of(def)
		_costs[type_id] = int(def["placement_cost_yen"])
		grid.add_child(_make_card(type_id, def, on_pick))
	set_category(ALL)


func set_category(category: StringName) -> void:
	_category = category
	for key in _tabs:
		var tab: Button = _tabs[key]
		tab.button_pressed = key == category
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			tab.add_theme_stylebox_override(state, UiTheme.catalog_tab_box(key == category))
	for type_id in _cards:
		var card: Button = _cards[type_id]
		card.visible = category == ALL or _categories[type_id] == category


func set_cash(cash: int) -> void:
	_cash = cash
	for type_id in _cards:
		_refresh_affordability(type_id)


func set_selected(type_id: String) -> void:
	_selected = type_id
	for id in _cards:
		_apply_card_face(id)


## Off outside SETUP: the cards stop taking clicks. Affordability does not disable a card (see _refresh_affordability).
func set_enabled(enabled: bool) -> void:
	for type_id in _cards:
		var card: Button = _cards[type_id]
		card.disabled = not enabled


func card(type_id: String) -> Button:
	return _cards.get(type_id)


func is_affordable(type_id: String) -> bool:
	return affordable(_costs[type_id], _cash)


func _refresh_affordability(type_id: String) -> void:
	var ok := is_affordable(type_id)
	var content: Control = _content[type_id]
	content.modulate = Color.WHITE if ok else DIM
	var price: Label = _prices[type_id]
	price.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY if ok else PRICE_UNAFFORDABLE)


## Card face per pointer state: hovered (and pressed) cards are lifted with a light rim; the selected card keeps the glow.
func _apply_card_face(type_id: String) -> void:
	var b: Button = _cards[type_id]
	var sel := type_id == _selected
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiTheme.catalog_card_box(state.begins_with("hover") or state == "pressed", sel))


func _make_card(type_id: String, def: Dictionary, on_pick: Callable) -> Button:
	var b := Button.new()
	b.name = type_id
	_cards[type_id] = b
	b.custom_minimum_size = CARD_SIZE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.tooltip_text = "%s  %s  %d×%d" % [def["display_name"], GameHud.format_yen(def["placement_cost_yen"]), def["footprint"]["w"], def["footprint"]["h"]]
	b.pressed.connect(on_pick.bind(type_id))
	UiFx.attach(b)
	_apply_card_face(type_id)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	b.add_child(column)

	var picture := TextureRect.new()
	picture.texture = thumbnail(type_id)
	picture.custom_minimum_size = THUMB_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	column.add_child(content)
	_content[type_id] = content
	content.add_child(_label(def["display_name"], UiTheme.TEXT_PRIMARY, "Name", 12))
	var price := _label(GameHud.format_yen(def["placement_cost_yen"]), UiTheme.TEXT_PRIMARY, "Price")
	content.add_child(price)
	_prices[type_id] = price
	content.add_child(_label("%d×%d" % [def["footprint"]["w"], def["footprint"]["h"]], UiTheme.TEXT_SECONDARY, "Footprint"))
	_refresh_affordability(type_id)
	return b


func _label(text: String, color: Color, node_name: String, font_size: int = UiTheme.FONT_SMALL) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# ------------------------------------------------------------------ pure rules (unit-tested)

## Category of a fixture definition, from its allowed product categories (see COLD_PRODUCTS / COUNTER_PRODUCTS).
static func category_of(def: Dictionary) -> StringName:
	var cats: Array = def.get("allowed_categories", [])
	if cats.is_empty() and not def.has("register_queue_max_tiles"):
		return SERVICE
	if not cats.is_empty() and cats.all(func(c): return SERVICE_PRODUCTS.has(c)):
		return SERVICE
	if cats.any(func(c): return COLD_PRODUCTS.has(c)):
		return COLD
	if cats.all(func(c): return COUNTER_PRODUCTS.has(c)):
		return COUNTER
	return SHELF


## Type ids of each tab, in catalog order. ALL holds every type.
static func group(catalog: FixtureCatalog) -> Dictionary:
	var out := {ALL: [], SHELF: [], COLD: [], COUNTER: [], SERVICE: []}
	for type_id in catalog.types:
		var category := category_of(catalog.get_type(type_id))
		out[ALL].append(type_id)
		out[category].append(type_id)
	return out


static func affordable(cost_yen: int, cash_yen: int) -> bool:
	return cash_yen >= cost_yen


## The fixture body sprite (rotation 0) cropped to its visible pixels and fitted into THUMB_PIXELS. Built once per
## type. A type without a sprite gets null, so its card shows the text only.
static func thumbnail(type_id: String) -> Texture2D:
	if _thumbs.has(type_id):
		return _thumbs[type_id]
	var tex := _build_thumbnail(type_id)
	_thumbs[type_id] = tex
	return tex


static func _placeholder_thumbnail() -> Texture2D:
	var out := Image.create_empty(THUMB_PIXELS.x, THUMB_PIXELS.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var box := Rect2i(THUMB_PIXELS.x / 4, THUMB_PIXELS.y / 4, THUMB_PIXELS.x / 2, THUMB_PIXELS.y / 2)
	out.fill_rect(box, Color("8a9bb0"))
	out.fill_rect(box.grow(-4), Color("c9d3df"))
	return ImageTexture.create_from_image(out)


static func _build_thumbnail(type_id: String) -> Texture2D:
	var entry := FixtureSprites.new().rotation_entry(type_id, 0)
	if entry.is_empty():
		return _placeholder_thumbnail()   # a type without art yet (the staff rooms, #143): a plain box
	var body := entry["layers"].get("body") as Texture2D
	if body == null:
		return null
	var src := body.get_image()
	if src == null or src.is_empty():
		return null
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var crop := src.get_region(used)
	var fit := minf(float(THUMB_PIXELS.x) / used.size.x, float(THUMB_PIXELS.y) / used.size.y)
	var w := maxi(1, roundi(used.size.x * fit))
	var h := maxi(1, roundi(used.size.y * fit))
	crop.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create_empty(THUMB_PIXELS.x, THUMB_PIXELS.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(crop, Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((THUMB_PIXELS.x - w) / 2, (THUMB_PIXELS.y - h) / 2))
	return ImageTexture.create_from_image(out)
