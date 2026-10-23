class_name LeftNav
extends PanelContainer
## Left navigation rail (mockup A): 店舗 / 商品 / スタッフ / 営業 / データ / 設定. Each entry is a wide button
## with a title and a grey subtitle. Pressing an entry selects it (brighter fill, warm bar on the left edge)
## and scrolls the right inspector to its section by finding the first visible Label whose text starts with
## a keyword. Below UiTheme.COMPACT_WIDTH the rail shrinks to a narrow strip with subtitles hidden (set_compact).

const WIDTH := 200
const COMPACT_WIDTH_PX := 72
const TITLE_SIZE := 18
const COMPACT_TITLE_SIZE := 14
const SUBTITLE_SIZE := 12
const ENTRY_HEIGHT := 64
const BAR_WIDTH := 4
## Each entry: title, subtitle, and the section-title prefixes to try in order (first match wins).
## スタッフ has no section yet (MVP対象外), so it is disabled.
const ICON_SIZE := 24
const ICON_TEXT_LEFT := 40   # icon starts at the button's content margin (8 px), label after it
const ITEMS := [
	{"title": "店舗", "subtitle": "レイアウト・設備", "keys": ["選択", "未選択"], "icon": "store"},
	{"title": "商品", "subtitle": "発注・在庫・棚割", "keys": ["在庫", "販売価格"], "icon": "box"},
	{"title": "スタッフ", "subtitle": "シフト・教育", "keys": [], "disabled": true, "tooltip": "MVP対象外", "icon": "person"},
	{"title": "営業", "subtitle": "広告・イベント", "keys": ["営業"], "icon": "megaphone"},
	{"title": "データ", "subtitle": "売上・顧客分析", "keys": ["日次レポート", "実績"], "icon": "bar-chart"},
	{"title": "設定", "subtitle": "店舗設定・その他", "keys": ["セーブ", "演出・音"], "icon": "gear"},
]

var selected_index := 0
var _buttons: Array[Button] = []
var _titles: Array[Label] = []
var _subtitles: Array[Label] = []
var _icons: Array[Texture2D] = []


func _ready() -> void:
	name = "LeftNav"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	for i in ITEMS.size():
		_add_entry(column, i, ITEMS[i])
	_select(selected_index)


func _add_entry(column: VBoxContainer, index: int, item: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(WIDTH - 12, ENTRY_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = ICON_TEXT_LEFT
	inner.offset_right = -8
	inner.offset_top = 6
	inner.offset_bottom = -6
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 0)
	b.add_child(inner)
	var title := Label.new()
	title.text = item["title"]
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title)
	var subtitle := Label.new()
	subtitle.text = item["subtitle"]
	subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	subtitle.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(subtitle)
	var icon := UiIcons.texture(item["icon"], ICON_SIZE)
	b.icon = icon
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	if item.get("disabled", false):
		b.disabled = true
		b.tooltip_text = item["tooltip"]
	else:
		var keys: Array = item["keys"]
		b.pressed.connect(func():
			_select(index)
			_focus_section(keys))
	column.add_child(b)
	_buttons.append(b)
	_titles.append(title)
	_subtitles.append(subtitle)
	_icons.append(icon)


## Number of entries (for tests and layout checks).
func entry_count() -> int:
	return _buttons.size()


## The button for entry index, or null when out of range.
func entry_button(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null


## Title text of entry index.
func entry_title(index: int) -> String:
	return _titles[index].text


## Subtitle text of entry index.
func entry_subtitle(index: int) -> String:
	return _subtitles[index].text


## Marks entry index as the current one. Called on every press, so the selection follows the last entry pressed.
func _select(index: int) -> void:
	selected_index = index
	for i in _buttons.size():
		_apply_style(_buttons[i], i == index)


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


## Narrow strip for compact windows: subtitles hidden, titles smaller so they fit.
func set_compact(compact: bool) -> void:
	custom_minimum_size.x = COMPACT_WIDTH_PX if compact else WIDTH
	for i in _buttons.size():   # the strip is too narrow for icon and label together: titles only
		var b := _buttons[i]
		b.custom_minimum_size.x = COMPACT_WIDTH_PX - 12 if compact else WIDTH - 12
		b.icon = null if compact else _icons[i]
		(b.get_child(0) as Control).offset_left = 14 if compact else ICON_TEXT_LEFT
	for title in _titles:
		title.add_theme_font_size_override("font_size", COMPACT_TITLE_SIZE if compact else TITLE_SIZE)
	for subtitle in _subtitles:
		subtitle.visible = not compact


func is_compact() -> bool:
	return custom_minimum_size.x == COMPACT_WIDTH_PX


## Scrolls the inspector so the first matching section title is visible.
func _focus_section(keys: Array) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var inspector := parent_node.find_child("FixtureInspector", true, false)
	if inspector == null:
		return
	var scroll := inspector.find_child("Scroll", true, false) as ScrollContainer
	if scroll == null:
		return
	for key in keys:
		for node in inspector.find_children("*", "Label", true, false):
			var label := node as Label
			if label != null and label.is_visible_in_tree() and label.text.begins_with(key):
				scroll.ensure_control_visible.call_deferred(label)
				return
