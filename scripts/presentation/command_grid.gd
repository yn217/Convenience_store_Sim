class_name CommandGrid
extends PanelContainer
## Bottom-left command panel (mockup A): a tab strip and a 2x3 grid of wide buttons. Each button scrolls the
## matching inspector (side panel) section into view. The build palette is always visible, so that button
## just takes focus. The tab strip is decorative for now: only the first tab works, the others are 準備中.

const TABS := ["よく使うコマンド", "商品補充", "店舗運営", "その他"]
const TAB_NOT_READY := "準備中"
const ACTIONS := [
	{"label": "什器を設置", "section": "", "palette": true},
	{"label": "商品を仕入れる", "section": "在庫"},
	{"label": "棚割りを編集", "section": "在庫"},
	{"label": "スタッフ配置", "section": "", "tip": "MVP対象外"},
	{"label": "広告を実施", "section": "営業"},
	{"label": "価格を変更", "section": "販売価格"},
]
const BUTTON_SIZE := Vector2(160, 26)

var _buttons: Dictionary = {}   # label -> Button


func _ready() -> void:
	name = "CommandGrid"
	var box := get_theme_stylebox("panel").duplicate() as StyleBoxFlat   # tighter vertical padding keeps the row short
	if box != null:
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size.y = BUTTON_SIZE.y
		tab.button_pressed = i == 0
		if i == 0:
			tab.pressed.connect(func(): tab.set_pressed_no_signal(true))   # the first tab stays selected
		else:
			tab.disabled = true
			tab.tooltip_text = TAB_NOT_READY
		tabs.add_child(tab)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for a in ACTIONS:
		var b := Button.new()
		b.text = a["label"]
		b.custom_minimum_size = BUTTON_SIZE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		if a.has("tip"):
			b.disabled = true
			b.tooltip_text = a["tip"]
		b.pressed.connect(_on_pressed.bind(a["label"]))
		grid.add_child(b)
		_buttons[a["label"]] = b


func button(label: String) -> Button:
	return _buttons.get(label)


func _on_pressed(label: String) -> void:
	for a in ACTIONS:
		if a["label"] != label:
			continue
		if a.get("palette", false):
			_focus_palette()
		elif a["section"] != "":
			scroll_to_section(a["section"])
		return


func _focus_palette() -> void:
	var layout := _layout()
	var palette := layout.get_node_or_null("MainArea/BuildPalette") as Control if layout != null else null
	if palette == null or not palette.is_visible_in_tree():
		return
	var type_list := palette.get_node_or_null("Body/TypeList")
	if type_list == null:
		return
	for child in type_list.get_children():
		if child is BaseButton and child.is_visible_in_tree():
			child.grab_focus()
			return


## Scrolls the inspector so the card whose heading is `title` is visible. Does nothing if no such heading exists.
func scroll_to_section(title: String) -> void:
	var layout := _layout()
	var inspector := layout.get_node_or_null("MainArea/FixtureInspector/Scroll") as ScrollContainer if layout != null else null
	if inspector == null:
		return
	var body := inspector.get_node_or_null("Body") as Node
	if body == null:
		return
	var label := _find_label(body, title)
	if label == null:
		return
	var card: Node = label
	while card.get_parent() != body:   # the heading's card: the direct child of the inspector body
		card = card.get_parent()
	inspector.ensure_control_visible(card as Control)


func _find_label(node: Node, text: String) -> Label:
	for child in node.get_children():
		if child is Label and (child as Label).text == text:
			return child
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


## The Layout VBoxContainer that holds the screen's side panels. The grid sits in a row below it, so walk up.
func _layout() -> Node:
	var n := get_parent()
	while n != null and n.name != "Layout":
		n = n.get_parent()
	return n
