class_name MockupChrome
extends Control
## The screen chrome of the 2026-11-01 mockup (docs/mockups/ui_target_*_2026-11-01.png), drawn over the live store the
## way the browser mockup does it: the parts cut out of the mockup (tools/assets/build_mockup_chrome.py, at the
## game's 1920x1080 base size) with the values drawn live on top. Two layers: the base (top bar, left menu, bottom bar)
## always, and the window layer (the 経営管理 frame and its tabs, 小春六花 and her bubble) while the window is open.
## Presentation only: every button emits a signal and MainLayout runs the same action the old controls ran.

signal nav_pressed(id: String)
signal tab_pressed(id: String)
signal speed_pressed(speed: int)
signal pause_pressed
signal close_pressed
signal corner_pressed(id: String)   # the bottom right buttons: notices / missions / encyclopedia / shop

const DIR := "res://assets/ui/mockup/"
const NAV := ["store", "goods", "order", "management", "data", "staff", "equipment", "achievements"]
const NAV_TIPS := {"store": "店舗（建設モード）", "goods": "商品", "order": "発注", "management": "経営", "data": "データ",
	"staff": "スタッフ", "equipment": "設備（建設モード）", "achievements": "実績・称号"}
const TABS := ["goods", "management", "store", "staff", "data", "settings"]
const SPEEDS := {"x1": 1, "x2": 2, "x4": 4}
## The window's content area (below the tabs), where MainLayout puts the management pages.
const CONTENT := Rect2(562, 392, 1030, 474)
## The bottom right buttons' hit areas.
const CORNERS := {"notices": Rect2(1497, 935, 96, 112), "missions": Rect2(1600, 935, 98, 112),
	"encyclopedia": Rect2(1706, 935, 92, 112), "shop": Rect2(1808, 935, 98, 112)}
const CLOSE := Rect2(1524, 233, 76, 76)
const INK := Color("3b2a22")          # dark text on the cream faces
const GOLD := Color("ffd23c")         # the yellow figures on the dark faces
const CREAM := Color("fff3e0")
const GREEN := Color("1c8a3a")
## What 小春 says beside the window, per tab (the mockup's lines for 商品 and データ).
const BUBBLE := {
	"goods": "商品の在庫や価格を\n調整できます！\n売れ筋を確認して\nさらに売上を伸ばしましょう！",
	"data": "売上の推移や売れ筋商品を\nデータでチェックしましょう！\n数字からお店の傾向をつかんで、\nより良いお店づくりに\n活かしていきましょう！",
	"management": "営業や販促、広告は\nここで決めます！\n今日のイベントも\nチェックしましょう！",
	"staff": "店員さんの採用や\n仕事の様子を確認できます！\n疲れている人には\n休んでもらいましょう！",
	"settings": "音や表示の設定、\nセーブ・ロードは\nこちらです！",
}

static var _layout: Dictionary = {}

var _base: Control
var _window_layer: Control
var _nav_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _bubble_text: Label
var _labels: Dictionary = {}
var _goal_fill: Panel
var _event_icon: TextureRect
var _nav_on := ""
var days_per_month := GameCalendar.DEFAULT_DAYS_PER_MONTH   # set by GameHud (from the balance)
var _tab_on := "goods"


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "layout.json"))
	return _layout


static func available() -> bool:
	return FileAccess.file_exists(DIR + "layout.json")


## A heavy rounded-looking system font for the live figures (the mockup's lettering is a bold gothic).
static func font(weight: int = 800) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Yu Gothic UI", "Yu Gothic", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func _ready() -> void:
	name = "MockupChrome"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = _layer("Base")
	_window_layer = _layer("WindowLayer")
	_window_layer.visible = false
	_build_base()
	_build_window()


func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _picture(parent: Control, part: String, blocks: bool = true) -> TextureRect:
	var r := TextureRect.new()
	r.name = part
	r.texture = load(DIR + part + ".png")
	var p: Array = layout()[part]
	r.position = Vector2(p[0], p[1])
	r.size = Vector2(p[2], p[3])
	r.mouse_filter = Control.MOUSE_FILTER_STOP if blocks else Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _texture_button(parent: Control, off_part: String, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = off_part
	b.texture_normal = load(DIR + off_part + ".png")
	var p: Array = layout()[off_part]
	b.position = Vector2(p[0], p[1])
	b.size = Vector2(p[2], p[3])
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_click_mask = _mask_of(b.texture_normal)
	parent.add_child(b)
	return b


static func _mask_of(tex: Texture2D) -> BitMap:
	var m := BitMap.new()
	m.create_from_image_alpha(tex.get_image(), 0.4)
	return m


func _hit(parent: Control, rect: Rect2, tip: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	parent.add_child(b)
	return b


func _label(parent: Control, id: String, rect: Rect2, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER,
		outline := 0, outline_color := Color(0, 0, 0, 0.6)) -> Label:
	var l := Label.new()
	l.name = id
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	parent.add_child(l)
	_labels[id] = l
	return l


func _build_base() -> void:
	_picture(_base, "top_bar")
	_picture(_base, "bottom_bar")
	for id in NAV:
		var b := _texture_button(_base, "nav_%s_off" % id, NAV_TIPS[id])
		b.pressed.connect(func(): nav_pressed.emit(id))
		_nav_buttons[id] = b
	for id in ["pause", "x1", "x2", "x4"]:
		var b := _texture_button(_base, "speed_%s_off" % id, "一時停止 / 再開" if id == "pause" else "速度 ×%d" % SPEEDS[id])
		if id == "pause":
			b.pressed.connect(func(): pause_pressed.emit())
		else:
			b.pressed.connect(func(): speed_pressed.emit(SPEEDS[id]))
		_speed_buttons[id] = b
	# Top bar figures.
	_label(_base, "Day", Rect2(500, 20, 96, 34), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3, Color("a3214d"))
	_label(_base, "Date", Rect2(612, 20, 128, 34), 19, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	_label(_base, "Clock", Rect2(842, 18, 84, 36), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_label(_base, "Cash", Rect2(1050, 20, 116, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_label(_base, "Sales", Rect2(1296, 20, 104, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_label(_base, "Profit", Rect2(1519, 20, 84, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_label(_base, "Visitors", Rect2(1712, 20, 56, 34), 20, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	# Bottom bar: goal, the four figures, today's event.
	_label(_base, "Goal", Rect2(52, 972, 282, 36), 19, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_goal_fill = Panel.new()
	var green := StyleBoxFlat.new()
	green.bg_color = Color("74c41e")
	green.set_corner_radius_all(7)
	green.border_color = Color("4d8f0e")
	green.border_width_bottom = 2
	_goal_fill.add_theme_stylebox_override("panel", green)
	_goal_fill.position = Vector2(47, 1016)
	_goal_fill.size = Vector2(12, 14)
	_goal_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(_goal_fill)
	_label(_base, "GoalPercent", Rect2(292, 1009, 64, 32), 22, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_base, "MSales", Rect2(444, 988, 118, 38), 26, GOLD)
	_label(_base, "MProfit", Rect2(622, 988, 102, 38), 26, GOLD)
	_label(_base, "MCustomers", Rect2(792, 988, 78, 38), 26, GOLD)
	_label(_base, "MUnit", Rect2(948, 988, 80, 38), 26, GOLD)
	_label(_base, "EventTitle", Rect2(1100, 966, 250, 40), 27, INK)
	_label(_base, "EventLine", Rect2(1085, 1008, 270, 34), 18, INK)
	_event_icon = TextureRect.new()
	_event_icon.position = Vector2(1352, 952)
	_event_icon.size = Vector2(104, 92)
	_event_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_event_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_event_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(_event_icon)
	for id in CORNERS:
		var tip: String = {"notices": "お知らせ", "missions": "ミッション", "encyclopedia": "図鑑（準備中）", "shop": "ショップ（準備中）"}[id]
		_hit(_base, CORNERS[id], tip).pressed.connect(func(): corner_pressed.emit(id))


func _build_window() -> void:
	_picture(_window_layer, "rikka", false)
	_picture(_window_layer, "bubble")
	_bubble_text = _label(_window_layer, "BubbleText", Rect2(40, 742, 318, 148), 19, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_bubble_text.clip_text = false
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_picture(_window_layer, "window")
	for id in TABS:
		var b := _texture_button(_window_layer, "tab_%s_off" % id, "")
		b.pressed.connect(func(): tab_pressed.emit(id))
		_tab_buttons[id] = b
	_hit(_window_layer, CLOSE, "閉じる (Esc)").pressed.connect(func(): close_pressed.emit())


## Which menu entry is lit ("" for none).
func set_nav(id: String) -> void:
	_nav_on = id
	for n in _nav_buttons:
		_swap(_nav_buttons[n], "nav_%s_%s" % [n, "on" if n == id else "off"])


## Opens or closes the window layer; `tab` is the lit tab.
func set_window(open: bool, tab: String) -> void:
	_window_layer.visible = open
	_tab_on = tab
	for t in _tab_buttons:
		_swap(_tab_buttons[t], "tab_%s_%s" % [t, "on" if t == tab else "off"])
	_bubble_text.text = BUBBLE.get(tab, BUBBLE["goods"])


func is_window_open() -> bool:
	return _window_layer.visible


func _swap(b: TextureButton, part: String) -> void:
	b.texture_normal = load(DIR + part + ".png")
	var p: Array = layout()[part]
	b.position = Vector2(p[0], p[1])
	b.size = Vector2(p[2], p[3])
	b.texture_click_mask = _mask_of(b.texture_normal)


func label(id: String) -> Label:
	return _labels.get(id)


func apply_snapshot(s: Dictionary) -> void:
	var day := int(s["day"])
	var dpm := days_per_month
	_labels["Day"].text = "DAY %d" % day
	_labels["Date"].text = "%s（%s）" % [GameCalendar.month_week_text(day, dpm), GameCalendar.season_of(day, dpm)]
	_labels["Clock"].text = GameHud.format_clock(int(s["time_sec"]))
	_labels["Cash"].text = GameHud.format_yen(int(s["cash_yen"]))
	var t := MetricBar.texts(s)
	var n := MetricBar.numbers(s)
	_labels["Sales"].text = t["sales"]
	_labels["Profit"].text = t["profit"]
	_labels["Visitors"].text = "%d人" % n["customers"]
	_labels["MSales"].text = t["sales"]
	_labels["MProfit"].text = t["profit"]
	_labels["MCustomers"].text = "%d人" % n["customers"]
	_labels["MUnit"].text = t["unit_price"]
	var goal := MetricBar.next_goal(s.get("milestone_progress", []))
	var ratio := 1.0
	if goal.is_empty():
		_labels["Goal"].text = "すべての目標を達成しました"
	else:
		_labels["Goal"].text = ProgressionText.goal_text(String(goal["metric"]), int(goal["threshold"]))
		ratio = MetricBar.goal_progress(int(goal["value"]), int(goal["threshold"]))
	_labels["GoalPercent"].text = "%d%%" % roundi(ratio * 100.0)
	_goal_fill.size.x = maxf(14.0, 241.0 * ratio)
	_apply_event(s.get("gameplay_event", {"status": "no_data"}))
	var speed := int(s["speed_setting"])
	for id in _speed_buttons:
		var on: bool = (id == "pause" and speed == 0) or (int(SPEEDS.get(id, -1)) == speed)
		_swap(_speed_buttons[id], "speed_%s_%s" % [id, "on" if on else "off"])


func _apply_event(view: Dictionary) -> void:
	var status := String(view.get("status", "no_data"))
	if status in ["scheduled", "active", "ended", "missed"]:
		_labels["EventTitle"].text = String(view["name_ja"])
		var chips := EventText.effect_chips(view)
		_labels["EventLine"].text = "・".join(chips.map(func(c): return c["text"])) if not chips.is_empty() else String(view.get("description_ja", ""))
		var cats: Array = view.get("categories", {}).keys()
		_event_icon.texture = _category_icon(String(cats[0])) if not cats.is_empty() else null
	else:
		_labels["EventTitle"].text = "本日のイベント"
		_labels["EventLine"].text = "2日目から毎日抽選" if int(view.get("day", 0)) < 1 else "今日は特別なイベントなし"
		_event_icon.texture = null


func _category_icon(category: String) -> Texture2D:
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	for id in products.skus:
		var sku: Dictionary = products.get_sku(id)
		if String(sku["category"]) == category:
			return ProductIcons.texture(sku, 64)
	return null
