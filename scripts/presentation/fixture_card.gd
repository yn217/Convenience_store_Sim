class_name FixtureCard
extends Node
## "選択中の什器" section of the inspector (mockup A): the selected fixture's name, price and footprint,
## then stock, today's sales share and today's gross-profit share as thin bars. Pure view: it reads the
## snapshot and the store selection and never changes either.

const Hud := preload("res://scripts/presentation/game_hud.gd")
const NONE_TEXT := "未選択"
const ROW_LABELS := ["在庫数", "本日の売上", "本日の粗利"]

var _world: Node2D
var _snap: Dictionary = {}
var _name: Label
var _price: Label
var _rows: Array = []   # per row: {box, caption, bar, value}


@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	_world = get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	var title := Label.new()
	title.text = "選択中の什器"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_name)
	_price = Label.new()
	_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_price)
	for label_text in ROW_LABELS:
		var box := VBoxContainer.new()
		var head := HBoxContainer.new()
		var caption := Label.new()
		caption.theme_type_variation = &"CardTitle"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		head.add_child(caption)
		head.add_child(value)
		box.add_child(head)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size.y = UiTheme.BAR_HEIGHT
		box.add_child(bar)
		_body.add_child(box)
		_rows.append({"box": box, "caption": caption, "bar": bar, "value": value})
	if _world != null:
		_world.selection_changed.connect(func(_tile): _render())
	_render()


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	_render()


func _render() -> void:
	var fid: String = _world.selected_fixture_id() if _world != null else ""
	var inst := _find_instance(fid)
	var catalog: FixtureCatalog = _world.fixture_catalog if _world != null else null
	var def: Dictionary = catalog.get_type(inst["type_id"]) if (not inst.is_empty() and catalog != null) else {}
	if def.is_empty():
		_name.text = NONE_TEXT
		_price.text = ""
		for row in _rows:
			row["box"].visible = false
		return
	_name.text = def["display_name"]
	_price.text = price_line(def)
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


## Total units the fixture's shelves can hold (its slots; a fixture without slots uses capacity_units).
static func capacity(def: Dictionary) -> int:
	var total := 0
	for slot in def.get("shelf_slots", []):
		total += int(slot["capacity_units"])
	return total if total > 0 else int(def.get("capacity_units", 0))


## The three rows of the card. `stock` is {slot_id: qty} of this fixture; `sales` holds this fixture's
## revenue and gross profit today; `totals` the store's (snapshot "today"). The sales and profit bars show
## this fixture's share of the store's today.
static func rows(def: Dictionary, stock: Dictionary, sales: Dictionary, totals: Dictionary) -> Array:
	var cap := capacity(def)
	var units := 0
	for qty in stock.values():
		units += int(qty)
	var stock_text := "棚なし" if cap <= 0 else "%d / %d" % [units, cap]
	var revenue := int(sales.get("revenue_yen", 0))
	var gross := int(sales.get("gross_profit_yen", 0))
	return [
		{"label": ROW_LABELS[0], "ratio": ShelfDisplay.fill_ratio(units, cap), "value_text": stock_text},
		{"label": ROW_LABELS[1], "ratio": share(revenue, int(totals.get("revenue_yen", 0))), "value_text": Hud.format_yen(revenue)},
		{"label": ROW_LABELS[2], "ratio": share(gross, int(totals.get("gross_profit_yen", 0))), "value_text": Hud.format_yen(gross)},
	]


## part / whole clamped to 0..1; 0 when the store has nothing yet today.
static func share(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return clampf(float(part) / float(whole), 0.0, 1.0)
