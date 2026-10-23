class_name LeftNav
extends PanelContainer
## Left navigation strip (mockup style): 店舗 / 商品 / 営業 / データ / 設定. Each button scrolls the
## right inspector to its section by finding the first Label whose text starts with a keyword. No
## visibility toggling, so every section stays where the controllers placed it.

const WIDTH := 72
const BODY := "FixtureInspector/Scroll/Body"   # relative to the MainArea (this node's parent)
## Each entry: button label, and the section-title prefixes to try in order (first match wins).
const ITEMS := [
	{"label": "店舗", "keys": ["選択", "未選択"]},
	{"label": "商品", "keys": ["在庫", "販売価格"]},
	{"label": "営業", "keys": ["営業"]},
	{"label": "データ", "keys": ["日次レポート", "実績"]},
	{"label": "設定", "keys": ["セーブ", "演出・音"]},
]


func _ready() -> void:
	name = "LeftNav"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	for item in ITEMS:
		var b := Button.new()
		b.text = item["label"]
		b.custom_minimum_size = Vector2(WIDTH - 12, 48)
		b.focus_mode = Control.FOCUS_NONE
		var keys: Array = item["keys"]
		b.pressed.connect(func(): _focus_section(keys))
		column.add_child(b)


## Scrolls the inspector so the first matching section title is visible.
func _focus_section(keys: Array) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var body := parent_node.get_node_or_null(BODY)
	if body == null:
		return
	var scroll := body.get_parent() as ScrollContainer
	if scroll == null:
		return
	for key in keys:
		for node in body.find_children("*", "Label", true, false):
			var label := node as Label
			if label != null and label.is_visible_in_tree() and label.text.begins_with(key):
				scroll.ensure_control_visible.call_deferred(label)
				return
