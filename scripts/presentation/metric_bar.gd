class_name MetricBar
extends PanelContainer
## Bottom strip of four metric cards (mockup A): sales, gross profit, customers in store, reputation.
## Display only; fed by the same snapshot as the top HUD.

const CARDS := [
	{"id": "sales", "title": "本日の売上"},
	{"id": "profit", "title": "本日の粗利"},
	{"id": "customers", "title": "店内客"},
	{"id": "reputation", "title": "評判"},
]
const HEIGHT := 72

var _values: Dictionary = {}


func _ready() -> void:
	name = "MetricBar"
	custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for c in CARDS:
		var card := PanelContainer.new()
		card.theme_type_variation = &"Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		card.add_child(box)
		var title := Label.new()
		title.text = c["title"]
		title.theme_type_variation = &"CardTitle"
		box.add_child(title)
		var value := Label.new()
		value.theme_type_variation = &"CardValue"
		value.text = "—"
		box.add_child(value)
		row.add_child(card)
		_values[c["id"]] = value


static func texts(s: Dictionary) -> Dictionary:
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	return {
		"sales": GameHud.format_yen(int(today["revenue_yen"])),
		"profit": GameHud.format_yen(int(today["gross_profit_yen"])),
		"customers": "%d 人" % s.get("customers", []).size(),
		"reputation": "%d" % int(s.get("reputation", 0)),
	}


func apply_snapshot(s: Dictionary) -> void:
	var t := texts(s)
	for id in _values:
		(_values[id] as Label).text = t[id]
