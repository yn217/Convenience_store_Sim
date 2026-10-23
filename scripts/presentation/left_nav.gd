class_name LeftNav
extends PanelContainer
## Slim left icon rail (UI redesign Phase 1): icon above a short label. 店舗 toggles build mode; 商品 / 経営 /
## データ / 設定 open the management window on that tab (MainLayout does the work). Emits item_pressed(id).
## スタッフ is not in the rail (MVP対象外).

signal item_pressed(id: String)

const WIDTH := 80
const ENTRY_HEIGHT := 64
const ICON_SIZE := 26
const LABEL_SIZE := 13
const BAR_WIDTH := 4
## Each entry: id (what MainLayout dispatches on), short label, icon name (UiIcons).
const ITEMS := [
	{"id": "store", "title": "店舗", "icon": "store"},
	{"id": "goods", "title": "商品", "icon": "box"},
	{"id": "management", "title": "経営", "icon": "megaphone"},
	{"id": "data", "title": "データ", "icon": "bar-chart"},
	{"id": "settings", "title": "設定", "icon": "gear"},
]

var active_id := ""
var _buttons: Array[Button] = []
var _titles: Array[Label] = []


func _ready() -> void:
	name = "LeftNav"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	for i in ITEMS.size():
		_add_entry(column, ITEMS[i])
	set_active("")


func _add_entry(column: VBoxContainer, item: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(WIDTH - 10, ENTRY_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.tooltip_text = item["title"]
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_top = 6
	inner.offset_bottom = -6
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	b.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(item["icon"], ICON_SIZE)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	var title := Label.new()
	title.text = item["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", LABEL_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title)
	var id: String = item["id"]
	b.pressed.connect(func(): item_pressed.emit(id))
	column.add_child(b)
	_buttons.append(b)
	_titles.append(title)


## Number of entries (for tests and layout checks).
func entry_count() -> int:
	return _buttons.size()


## The button for entry index, or null when out of range.
func entry_button(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null


## Label text of entry index.
func entry_title(index: int) -> String:
	return _titles[index].text


## Id of entry index (the item_pressed argument).
func entry_id(index: int) -> String:
	return ITEMS[index]["id"]


## Marks the entry with this id as active (brighter fill, warm bar on the left edge). "" clears the mark.
func set_active(id: String) -> void:
	active_id = id
	for i in _buttons.size():
		_apply_style(_buttons[i], ITEMS[i]["id"] == id)


func _apply_style(b: Button, selected: bool) -> void:
	var fill: Color = UiTheme.PANEL_ELEVATED if selected else UiTheme.PANEL
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := UiTheme._box(fill, 8)
		if selected:
			box.border_width_left = BAR_WIDTH
			box.border_color = UiTheme.WARM
		if state == "hover":
			box.border_color = UiTheme.WARM
		if state == "pressed":
			box.bg_color = UiTheme.BRAND_BLUE
		b.add_theme_stylebox_override(state, box)
