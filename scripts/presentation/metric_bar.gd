class_name MetricBar
extends PanelContainer
## Bottom strip of four metric cards (mockup A): sales, gross profit, customers in store, customer
## satisfaction (客層満足度, a percent derived from reputation). Display only; fed by the same snapshot as the top HUD.

const CARDS := [
	{"id": "sales", "title": "本日の売上", "icon": "cart"},
	{"id": "profit", "title": "本日の粗利", "icon": "bar-chart"},
	{"id": "customers", "title": "店内客", "icon": "users"},
	{"id": "satisfaction", "title": "客層満足度", "tip": "評判から算出", "icon": "heart"},
]
const HEIGHT := 72
const ICON_SIZE := 28

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
		box.alignment = BoxContainer.ALIGNMENT_CENTER   # value sits in the middle of the card, not on its top edge
		var line := HBoxContainer.new()   # icon at the left edge of the card, text column after it
		line.add_theme_constant_override("separation", 10)
		card.add_child(line)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = UiIcons.texture(c["icon"], ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = UiTheme.WARM
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(box)
		var title := Label.new()
		title.text = c["title"]
		title.theme_type_variation = &"CardTitle"
		box.add_child(title)
		var value := Label.new()
		value.theme_type_variation = &"CardValue"
		value.text = "—"
		if c.has("tip"):
			value.tooltip_text = c["tip"]
		box.add_child(value)
		row.add_child(card)
		_values[c["id"]] = value


static func texts(s: Dictionary) -> Dictionary:
	var today: Dictionary = s.get("today", {"revenue_yen": 0, "gross_profit_yen": 0})
	return {
		"sales": GameHud.format_yen(int(today["revenue_yen"])),
		"profit": GameHud.format_yen(int(today["gross_profit_yen"])),
		"customers": "%d 人" % s.get("customers", []).size(),
		"satisfaction": "%d%%" % satisfaction_percent(int(s.get("reputation", 0))),
	}


## Reputation is already a 0..100 score (see ReputationModel), so the percent is the clamped value.
static func satisfaction_percent(rep: int) -> int:
	return clampi(rep, 0, 100)


func apply_snapshot(s: Dictionary) -> void:
	var t := texts(s)
	for id in _values:
		(_values[id] as Label).text = t[id]
