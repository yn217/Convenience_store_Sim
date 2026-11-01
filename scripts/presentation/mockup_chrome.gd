class_name MockupChrome
extends Control
## The screen chrome of the 2026-11-01 mockup (docs/mockups/ui_target_*_2026-11-01.png), built in code over the live
## store: the top bar, the left menu, the bottom bar, and while the 経営管理 window is open its frame and tabs with
## 小春六花 and her speech bubble beside it. Shapes are UiShape, text is the rounded font, icons are the filled glyphs
## and the UI pictures (MockStyle). Positions are the mockup's, measured at the 1920x1080 base size.
## Presentation only: every button emits a signal and MainLayout runs the same action the old controls ran.

const OpeningGuideScript := preload("res://scripts/presentation/opening_guide.gd")

signal nav_pressed(id: String)
signal tab_pressed(id: String)
signal speed_pressed(speed: int)
signal pause_pressed
signal close_pressed
signal corner_pressed(id: String)   # the bottom right buttons: notices / missions / encyclopedia / shop

## 発注 is not here: ordering lives on the 商品 tab (user, 2026-11-01). The entries are packed from the top.
const NAV := [["store", "店舗", "home"], ["goods", "商品", "box3d"], ["management", "経営", "chart-up"],
	["data", "データ", "bar-chart"], ["staff", "スタッフ", "users"], ["equipment", "設備", "tools"], ["achievements", "実績・称号", "trophy"]]
## The menu icons' colours (the mockup's gold / cream / white glyphs).
const NAV_TINT := {"store": Color("ffcf63"), "goods": Color("ffffff"), "order": Color("fff3dc"), "management": Color("ffcf63"),
	"data": Color("ffcf63"), "staff": Color("ffffff"), "equipment": Color("ffffff"), "achievements": Color("ffcf63")}
const NAV_TIPS := {"store": "店舗（建設モード）", "equipment": "設備（建設モード）", "achievements": "実績・称号（経営の目標）"}
## In the left menu's order (店舗 商品 経営 スタッフ データ 設定), in the mockup's six tab slots.
const TABS := [["store", "店舗", "store", 572, 176], ["goods", "商品", "box", 754, 163], ["management", "経営", "chart-up", 920, 159],
	["staff", "スタッフ", "users", 1083, 164], ["data", "データ", "bar-chart", 1253, 171], ["settings", "設定", "gear", 1427, 164]]
const SPEEDS := [["pause", 0, 1774, 34], ["x1", 1, 1810, 31], ["x2", 2, 1843, 31], ["x4", 4, 1876, 34]]
## The window's content area (below the tabs), where MainLayout puts the management pages.
const CONTENT := Rect2(562, 392, 1030, 474)
const RIKKA := "res://assets/ui/mockup/rikka.png"
const RIKKA_RECT := Rect2(195, 327, 448, 605)
const INK := MockStyle.INK
const GREEN := MockStyle.GREEN
## What 小春 says beside the window, per tab (the mockup's lines for 商品 and データ).
const BUBBLE := {
	"goods": "商品の在庫や価格を\n調整できます！\n売れ筋を確認して\nさらに売上を伸ばしましょう！",
	"data": "売上の推移や売れ筋商品を\nデータでチェックしましょう！\n数字からお店の傾向をつかんで、\nより良いお店づくりに\n活かしていきましょう！",
	"management": "営業や販促、広告は\nここで決めます！\n今日のイベントも\nチェックしましょう！",
	"staff": "店員さんの採用や\n仕事の様子を確認できます！\n疲れている人には\n休んでもらいましょう！",
	"settings": "音や表示の設定、\nセーブ・ロードは\nこちらです！",
}

var _base: Control
var _window_layer: Control
var _nav: Dictionary = {}      # id -> {button, plate, glyph, label}
var _tabs: Dictionary = {}     # id -> {button, plate}
var _speeds: Dictionary = {}   # id -> {button, plate, label}
var _bubble_text: Label
var _labels: Dictionary = {}
var _goal_fill: UiShape
var _event_icon: TextureRect
var days_per_month := GameCalendar.DEFAULT_DAYS_PER_MONTH   # set by GameHud (from the balance)
var guide: Node   # 開店までの手順 (top right while setting up; hidden while the window is open)
var _last_snap: Dictionary = {}


static func available() -> bool:
	return true


## The rounded font (kept for the pages that call MockupChrome.font()).
static func font(_weight: int = 800) -> Font:
	return MockStyle.font("ExtraBold")


func _ready() -> void:
	name = "MockupChrome"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = _layer("Base")
	_window_layer = _layer("WindowLayer")
	_window_layer.visible = false
	_build_top()
	_build_menu()
	_build_bottom()
	guide = OpeningGuideScript.new()
	_base.add_child(guide)
	_build_window()


func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _named(id: String, l: Label) -> Label:
	l.name = id
	_labels[id] = l
	return l


func _blocker(parent: Control, n: String, r: Rect2) -> Control:
	var c := Control.new()
	c.name = n
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c


# --- top bar -----------------------------------------------------------------------------------------------------

func _pill(parent: Control, r: Rect2, pink := false) -> UiShape:
	if pink:
		return MockStyle.shape(parent, r, {"top": Color("ff7aa3"), "bottom": Color("d8386c"), "border": Color("ffd3e0"), "border_width": 2.0,
			"radius": r.size.y * 0.5, "gloss": 0.3})
	return MockStyle.shape(parent, r, {"top": Color("44343e"), "bottom": Color("2a2029"), "border": Color("6f5865"), "border_width": 1.5,
		"radius": r.size.y * 0.5, "gloss": 0.08})


func _build_top() -> void:
	var bar := _blocker(_base, "top_bar", Rect2(0, 0, 1920, 64))
	MockStyle.shape(bar, Rect2(0, -4, 1920, 66), {"top": Color(0.2, 0.15, 0.18, 0.93), "bottom": Color(0.14, 0.1, 0.12, 0.93), "radius": 0.0})
	var rim := ColorRect.new()
	rim.color = Color("c99a55")
	rim.position = Vector2(0, 61)
	rim.size = Vector2(1920, 2)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(rim)
	MockStyle.shape(bar, Rect2(-30, -10, 498, 82), {"kind": UiShape.Kind.PLATE, "tip": 34.0, "radius": 8.0, "top": Color("2f222a"),
		"bottom": Color("1d1419"), "border": Color("d6a45c"), "border_width": 2.0, "shadow": Color(0, 0, 0, 0.35)})
	MockStyle.picture(bar, MockStyle.glyph("store", 128), Rect2(18, 8, 59, 53), Color("f4c87a"))
	MockStyle.label(bar, "コンビニ経営シミュレーション", Rect2(90, 2, 372, 40), 26, Color("fff4e2"), HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
	MockStyle.label(bar, "Convenience Store Management Sim.", Rect2(91, 35, 360, 24), 19, Color("e9dcc8"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_pill(bar, Rect2(458, 12, 144, 46), true)
	MockStyle.picture(bar, MockStyle.glyph("calendar", 64), Rect2(468, 19, 30, 30))
	_named("Day", MockStyle.label(bar, "DAY 0", Rect2(504, 13, 96, 42), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "Black", 3, Color("a3214d")))
	_named("Date", MockStyle.label(bar, "", Rect2(618, 14, 124, 42), 18, Color("fff3e0"), HORIZONTAL_ALIGNMENT_LEFT, "Bold"))
	MockStyle.picture(bar, MockStyle.art("sakura"), Rect2(740, 11, 48, 45))
	_pill(bar, Rect2(798, 12, 138, 46))
	MockStyle.picture(bar, MockStyle.glyph("moon", 64), Rect2(810, 20, 29, 29), Color("ffe27a"))
	_named("Clock", MockStyle.label(bar, "", Rect2(849, 11, 88, 46), 27, Color.WHITE))
	_pill(bar, Rect2(944, 12, 226, 46))
	MockStyle.picture(bar, MockStyle.art("coins"), Rect2(954, 15, 36, 40))
	MockStyle.label(bar, "所持金", Rect2(997, 14, 56, 42), 16, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_named("Cash", MockStyle.label(bar, "", Rect2(1055, 13, 114, 44), 20, MockStyle.GOLD))
	_pill(bar, Rect2(1176, 12, 226, 46))
	MockStyle.picture(bar, MockStyle.glyph("bar-chart", 64), Rect2(1180, 19, 40, 37), Color("4fc6ff"))
	MockStyle.label(bar, "本日の売上", Rect2(1227, 14, 80, 42), 15, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_named("Sales", MockStyle.label(bar, "", Rect2(1305, 13, 96, 44), 21, MockStyle.GOLD))
	_pill(bar, Rect2(1408, 12, 196, 46))
	MockStyle.picture(bar, MockStyle.glyph("arrow-up", 64), Rect2(1415, 20, 28, 37), Color("5fdde6"))
	MockStyle.label(bar, "本日の粗利", Rect2(1450, 14, 72, 42), 14, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_named("Profit", MockStyle.label(bar, "", Rect2(1526, 13, 78, 44), 21, MockStyle.GOLD))
	_pill(bar, Rect2(1610, 12, 158, 46))
	MockStyle.picture(bar, MockStyle.glyph("person", 64), Rect2(1619, 19, 33, 32), Color("a9dcff"))
	MockStyle.label(bar, "来店客数", Rect2(1656, 14, 58, 42), 14, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_named("Visitors", MockStyle.label(bar, "", Rect2(1716, 13, 52, 44), 21, Color("fff1dc")))
	MockStyle.shape(bar, Rect2(1770, 7, 146, 52), {"top": Color("2a2029"), "bottom": Color("1d161c"), "border": Color("5a4651"),
		"border_width": 1.5, "radius": 10.0})
	for sp in SPEEDS:
		var r := Rect2(sp[2], 11, sp[3], 44)
		var b := MockStyle.button(bar, r, "一時停止 / 再開" if sp[0] == "pause" else "速度 ×%d" % sp[1])
		b.name = "speed_" + sp[0]
		var plate := MockStyle.shape(b, Rect2(Vector2.ZERO, r.size), {"radius": 5.0, "border_width": 1.5, "gloss": 0.35})
		var l: Label = null
		if sp[0] == "pause":
			MockStyle.picture(b, MockStyle.glyph("pause", 64), Rect2(9, 13, 16, 18), INK).name = "Glyph"
			b.pressed.connect(func(): pause_pressed.emit())
		else:
			l = MockStyle.label(b, "×%d" % sp[1], Rect2(0, 0, r.size.x, r.size.y), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, "Black")
			var s: int = sp[1]
			b.pressed.connect(func(): speed_pressed.emit(s))
		_speeds[sp[0]] = {"button": b, "plate": plate, "label": l}
	_set_speed(4)


func _set_speed(speed: int) -> void:
	for sp in SPEEDS:
		var on: bool = sp[1] == speed
		var v: Dictionary = _speeds[sp[0]]
		(v["plate"] as UiShape).setup({"top": Color("5ab4ff") if on else Color("fbf8f8"), "bottom": Color("1c6fd8") if on else Color("d9d1d3"),
			"border": Color("cfe8ff") if on else Color("8a7f86")})
		if v["label"] != null:
			(v["label"] as Label).add_theme_color_override("font_color", Color.WHITE if on else INK)
		else:
			((v["button"] as Button).get_node("Glyph") as CanvasItem).modulate = Color.WHITE if on else INK


# --- left menu ---------------------------------------------------------------------------------------------------

func _build_menu() -> void:
	for i in NAV.size():
		var id: String = NAV[i][0]
		var r := Rect2(14, 132 + i * 68, 212, 60)
		var b := MockStyle.button(_base, r, NAV_TIPS.get(id, NAV[i][1]))
		b.name = "nav_" + id
		var plate := MockStyle.shape(b, Rect2(Vector2.ZERO, r.size), {"kind": UiShape.Kind.PLATE, "tip": 12.0, "radius": 10.0,
			"border_width": 2.0, "gloss": 0.16, "shadow": Color(0, 0, 0, 0.35), "shadow_offset": Vector2(0, 3)})
		var g := MockStyle.picture(b, MockStyle.glyph(NAV[i][2], 128), Rect2(18, 8, 50, 44))
		var text: String = NAV[i][1]
		var long := text.length() >= 5   # 実績・称号: a half-width dot and a little further left, so it ends clear of the point
		var l := MockStyle.label(b, text.replace("・", "･") if long else text, Rect2(88 if long else 95, 0, 120, 60),
			27 if text.length() <= 3 else (24 if text.length() == 4 else 21), Color("fff3e0"), HORIZONTAL_ALIGNMENT_LEFT, "Bold",
			2, Color(0, 0, 0, 0.35))
		b.pressed.connect(func(): nav_pressed.emit(id))
		_nav[id] = {"button": b, "plate": plate, "glyph": g, "label": l}
	set_nav("")


## Which menu entry is lit ("" for none). 店舗 keeps its gold look when it is not the lit one (the mockup's home entry).
func set_nav(id: String) -> void:
	for n in _nav:
		var v: Dictionary = _nav[n]
		var plate: UiShape = v["plate"]
		if n == id:
			plate.setup({"top": Color("4fb0ff"), "bottom": Color("1557c4"), "border": Color("c9ecff"), "glow": Color(0.35, 0.75, 1.0, 0.9), "glow_size": 9.0,
				"inner": Color(1, 1, 1, 0.35)})
			(v["glyph"] as TextureRect).modulate = Color.WHITE
		elif n == "store":
			plate.setup({"top": Color("7e4b22"), "bottom": Color("442510"), "border": Color("ffd27f"), "glow": Color(1.0, 0.72, 0.25, 0.7), "glow_size": 7.0,
				"inner": Color(1, 0.85, 0.5, 0.35)})
			(v["glyph"] as TextureRect).modulate = NAV_TINT[n]
		else:
			plate.setup({"top": Color("4b3631"), "bottom": Color("281b1a"), "border": Color("b88f5f"), "glow": Color(0, 0, 0, 0), "glow_size": 0.0,
				"inner": Color(1, 0.85, 0.6, 0.12)})
			(v["glyph"] as TextureRect).modulate = NAV_TINT[n]


# --- bottom bar --------------------------------------------------------------------------------------------------

func _dark_card(parent: Control, r: Rect2) -> UiShape:
	return MockStyle.shape(parent, r, {"top": Color("43322f"), "bottom": Color("2a1f1e"), "border": Color("9b7656"), "border_width": 2.0,
		"radius": 14.0, "inner": Color(1, 0.85, 0.6, 0.12), "shadow": Color(0, 0, 0, 0.3)})


func _build_bottom() -> void:
	var bar := _blocker(_base, "bottom_bar", Rect2(0, 922, 1920, 158))
	MockStyle.shape(bar, Rect2(4, 4, 1912, 152), {"top": Color(0.3, 0.21, 0.2, 0.95), "bottom": Color(0.17, 0.12, 0.12, 0.95),
		"border": Color("c9a06a"), "border_width": 2.0, "radius": 16.0, "inner": Color(1, 0.85, 0.55, 0.18)})
	# 本日の目標
	_dark_card(bar, Rect2(18, 10, 346, 122))
	MockStyle.picture(bar, MockStyle.art("flag"), Rect2(46, 4, 44, 42))
	MockStyle.label(bar, "本日の目標", Rect2(98, 10, 220, 34), 21, Color("ffe3a8"), HORIZONTAL_ALIGNMENT_LEFT, "Black")
	MockStyle.shape(bar, Rect2(30, 44, 324, 80), {"top": Color("fffcf6"), "bottom": Color("f6ead8"), "border": Color("e3cba5"), "border_width": 2.0,
		"radius": 10.0})
	_named("Goal", MockStyle.label(bar, "", Rect2(58, 51, 296, 40), 20, INK, HORIZONTAL_ALIGNMENT_LEFT, "Bold"))
	MockStyle.shape(bar, Rect2(44, 92, 246, 18), {"top": Color("3d3534"), "bottom": Color("5a504e"), "radius": 9.0})
	_goal_fill = MockStyle.shape(bar, Rect2(44, 92, 18, 18), {"top": Color("a6e04a"), "bottom": Color("4fa30f"), "radius": 9.0, "gloss": 0.4})
	_named("GoalPercent", MockStyle.label(bar, "", Rect2(290, 84, 62, 34), 22, INK, HORIZONTAL_ALIGNMENT_RIGHT, "Black"))
	# the four figures
	# [label id, caption, card x, card w, glyph, tint, picture, icon rect (screen px), caption x, value x]
	var cards := [["MSales", "本日の売上", 382, 176, "bar-chart", Color("a2e23c"), "", Rect2(395, 977, 45, 41), 431, 436],
		["MProfit", "本日の粗利", 566, 160, "", Color.WHITE, "coins", Rect2(577, 978, 39, 39), 606, 614],
		["MCustomers", "来店客数", 732, 146, "users", Color("a9dcff"), "", Rect2(745, 976, 39, 40), 778, 790],
		["MUnit", "客単価", 884, 156, "cart", Color("fff6e8"), "", Rect2(899, 977, 39, 40), 938, 940]]
	for c in cards:
		_dark_card(bar, Rect2(c[2], 22, c[3], 100))
		var ir: Rect2 = c[7]
		ir.position.y -= 922
		MockStyle.label(bar, c[1], Rect2(c[8], 38, c[2] + c[3] - c[8] - 4, 30), 20, Color("fff1dc"), HORIZONTAL_ALIGNMENT_CENTER, "Bold")
		if c[6] != "":
			MockStyle.picture(bar, MockStyle.art(c[6]), ir)
		else:
			MockStyle.picture(bar, MockStyle.glyph(c[4], 96), ir, c[5])
		_named(c[0], MockStyle.label(bar, "", Rect2(c[9], 60, c[2] + c[3] - c[9] - 6, 46), 30, MockStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, "ExtraBold"))
	# today's event
	MockStyle.shape(bar, Rect2(1058, 8, 414, 128), {"top": Color("fff3f8"), "bottom": Color("ffd2e3"), "border": Color("ffffff"), "border_width": 3.0,
		"radius": 16.0, "inner": Color("ff9fc1"), "inner_inset": 2.0, "shadow": Color(0, 0, 0, 0.25)})
	MockStyle.picture(bar, MockStyle.art("sakura"), Rect2(1070, 82, 40, 40), Color(1, 1, 1, 0.75))
	MockStyle.picture(bar, MockStyle.art("sakura"), Rect2(1352, 14, 34, 34), Color(1, 1, 1, 0.8))
	MockStyle.picture(bar, MockStyle.art("sakura"), Rect2(1420, 26, 26, 26), Color(1, 1, 1, 0.8))
	var tag := MockStyle.shape(bar, Rect2(1062, 12, 132, 34), {"kind": UiShape.Kind.RIBBON, "top": Color("f0558a"), "bottom": Color("c92f63"), "radius": 8.0,
		"gloss": 0.25})
	MockStyle.picture(tag, MockStyle.glyph("star", 64), Rect2(10, 8, 18, 18))
	MockStyle.label(tag, "開催中！", Rect2(32, 0, 90, 34), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "Black")
	_named("EventTitle", MockStyle.label(bar, "", Rect2(1100, 44, 250, 44), 27, INK, HORIZONTAL_ALIGNMENT_CENTER, "Black"))
	_named("EventLine", MockStyle.label(bar, "", Rect2(1082, 88, 276, 34), 18, INK, HORIZONTAL_ALIGNMENT_CENTER))
	_event_icon = MockStyle.picture(bar, null, Rect2(1352, 30, 108, 96))
	# お知らせ / ミッション / 図鑑 / ショップ
	_dark_card(bar, Rect2(1490, 8, 420, 128))
	var corners := [["notices", "お知らせ", "bell"], ["missions", "ミッション", "mission"], ["encyclopedia", "図鑑", "book"], ["shop", "ショップ", "basket"]]
	for i in corners.size():
		var r := Rect2(1500 + i * 102, 16, 96, 112)
		var tip: String = {"encyclopedia": "図鑑（準備中）", "shop": "ショップ（準備中）"}.get(corners[i][0], corners[i][1])
		var b := MockStyle.button(bar, r, tip)
		b.name = "corner_" + corners[i][0]
		MockStyle.shape(b, Rect2(4, 0, 88, 108), {"top": Color("3b2c2a"), "bottom": Color("251b1a"), "radius": 18.0, "border": Color("6e5546"),
			"border_width": 1.5, "gloss": 0.06})
		MockStyle.picture(b, MockStyle.art(corners[i][2]), Rect2(16, 6, 64, 62))
		MockStyle.label(b, corners[i][1], Rect2(0, 76, 96, 30), 17, Color("fff4e2"), HORIZONTAL_ALIGNMENT_CENTER, "ExtraBold", 2, Color(0, 0, 0, 0.5))
		var cid: String = corners[i][0]
		b.pressed.connect(func(): corner_pressed.emit(cid))


# --- window --------------------------------------------------------------------------------------------------------

func _build_window() -> void:
	var rikka := TextureRect.new()
	rikka.name = "Rikka"
	rikka.texture = load(RIKKA) if ResourceLoader.exists(RIKKA) else null
	rikka.position = RIKKA_RECT.position
	rikka.size = RIKKA_RECT.size
	rikka.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rikka.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rikka.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# her bubble: a cream cloud with a tail toward her, and her name tag
	var bubble := _blocker(_window_layer, "Bubble", Rect2(10, 700, 370, 206))
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(330, 70), Vector2(372, 60), Vector2(338, 104)])
	tail.color = Color("fff6ea")
	bubble.add_child(tail)
	MockStyle.shape(bubble, Rect2(2, 34, 350, 168), {"top": Color("fffcf7"), "bottom": Color("fff0e0"), "border": Color("e2b798"), "border_width": 3.0,
		"radius": 50.0, "shadow": Color(0.3, 0.15, 0.1, 0.25), "shadow_offset": Vector2(0, 4)})
	var tag := MockStyle.shape(bubble, Rect2(24, 2, 128, 36), {"top": Color("ff8fb4"), "bottom": Color("e5507f"), "border": Color("ffffff"),
		"border_width": 2.0, "radius": 18.0, "gloss": 0.3})
	MockStyle.picture(tag, MockStyle.art("sakura"), Rect2(10, 5, 26, 26))
	MockStyle.label(tag, "小春", Rect2(42, 0, 80, 36), 21, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "Black")
	_bubble_text = MockStyle.label(bubble, "", Rect2(24, 46, 320, 148), 19, INK, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_bubble_text.name = "BubbleText"
	_bubble_text.clip_text = false
	# the frame: brown outer frame with a gold inner line, the header plaque, the cream inside
	var frame := _blocker(_window_layer, "window", Rect2(526, 204, 1100, 682))
	MockStyle.shape(frame, Rect2(4, 58, 1090, 620), {"top": Color("6e4c3c"), "bottom": Color("4a3026"), "border": Color("e2b273"), "border_width": 3.0,
		"radius": 30.0, "inner": Color("f6cf8f"), "inner_inset": 6.0, "shadow": Color(0, 0, 0, 0.4), "shadow_offset": Vector2(0, 6)})
	MockStyle.shape(frame, Rect2(54, 14, 450, 90), {"top": Color("4c3632"), "bottom": Color("2d1f1c"), "border": Color("e2b273"), "border_width": 2.5,
		"radius": 26.0, "inner": Color(1, 0.85, 0.55, 0.25)})
	MockStyle.shape(frame, Rect2(20, 92, 1058, 572), {"top": Color("fff8ef"), "bottom": Color("f3e1d1"), "border": Color("e9cfb9"), "border_width": 2.0,
		"radius": 22.0})
	MockStyle.picture(frame, MockStyle.art("mission"), Rect2(64, 2, 90, 94))
	MockStyle.label(frame, "経営管理", Rect2(158, 17, 220, 66), 43, Color("fff1dc"), HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold", 3, Color(0, 0, 0, 0.35))
	MockStyle.label(frame, "Store Management", Rect2(356, 50, 150, 24), 13, Color("ead9c4"), HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	MockStyle.picture(frame, MockStyle.art("logo_store"), Rect2(770, 2, 190, 92))
	_window_layer.add_child(rikka)   # in front of the frame: her hand points into the window
	var close := MockStyle.button(frame, Rect2(998, 30, 74, 74), "閉じる (Esc)")
	close.name = "CloseScreen"
	MockStyle.shape(close, Rect2(2, 2, 70, 70), {"kind": UiShape.Kind.CIRCLE, "top": Color("7a4232"), "bottom": Color("3e1f15"), "border": Color("f3e2c4"),
		"border_width": 3.0, "gloss": 0.2, "shadow": Color(0, 0, 0, 0.4)})
	MockStyle.label(close, "✕", Rect2(0, 0, 74, 74), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "Black")
	close.pressed.connect(func(): close_pressed.emit())
	for t in TABS:
		var r := Rect2(t[3] - 526, 112, t[4], 58)
		var b := MockStyle.button(frame, r, t[1])
		b.name = "tab_" + t[0]
		var plate := MockStyle.shape(b, Rect2(Vector2.ZERO, r.size), {"radius": 10.0, "border_width": 2.0, "gloss": 0.35, "shadow": Color(0.3, 0.15, 0.1, 0.25),
			"shadow_offset": Vector2(0, 3)})
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.size = r.size
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var g := TextureRect.new()
		g.texture = MockStyle.glyph(t[2], 96)
		g.custom_minimum_size = Vector2(38, 38)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.modulate = Color("3a2a26")
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(g)
		var l := Label.new()
		l.text = t[1]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MockStyle.style_label(l, 27, Color("2e2420"), "ExtraBold")
		row.add_child(l)
		var tid: String = t[0]
		b.pressed.connect(func(): tab_pressed.emit(tid))
		_tabs[tid] = {"button": b, "plate": plate}
	set_window(false, "goods")


## Opens or closes the window layer; `tab` is the lit tab.
func set_window(open: bool, tab: String) -> void:
	_window_layer.visible = open
	if guide != null and not _last_snap.is_empty():
		guide.apply_snapshot(_last_snap)
		guide.visible = guide.visible and not open
	for t in _tabs:
		var on: bool = t == tab
		(_tabs[t]["plate"] as UiShape).setup({"top": Color("ffe85a") if on else Color("fffdfa"), "bottom": Color("ffae12") if on else Color("eee0d8"),
			"border": Color("e98b1d") if on else Color("b8988a")})
	_bubble_text.text = BUBBLE.get(tab, BUBBLE["goods"])


func is_window_open() -> bool:
	return _window_layer.visible


func label(id: String) -> Label:
	return _labels.get(id)


func apply_snapshot(s: Dictionary) -> void:
	_last_snap = s
	guide.apply_snapshot(s)
	guide.visible = guide.visible and not _window_layer.visible
	var day := int(s["day"])
	_labels["Day"].text = "DAY %d" % day
	_labels["Date"].text = "%s（%s）" % [GameCalendar.month_week_text(day, days_per_month), GameCalendar.season_of(day, days_per_month)]
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
	_goal_fill.size.x = maxf(18.0, 246.0 * ratio)
	_apply_event(s.get("gameplay_event", {"status": "no_data"}))
	_set_speed(int(s["speed_setting"]))


func _apply_event(view: Dictionary) -> void:
	var status := String(view.get("status", "no_data"))
	if status in ["scheduled", "active", "ended", "missed"]:
		_labels["EventTitle"].text = String(view["name_ja"])
		var chips := EventText.effect_chips(view)
		_labels["EventLine"].text = "・".join(chips.map(func(c): return c["text"])) if not chips.is_empty() else String(view.get("description_ja", ""))
		var cats: Array = view.get("categories", {}).keys()
		_event_icon.texture = _category_icon(String(cats[0])) if not cats.is_empty() else MockStyle.art("store_building")
	else:
		_labels["EventTitle"].text = "本日のイベント"
		_labels["EventLine"].text = "2日目から毎日抽選" if int(view.get("day", 0)) < 1 else "今日は特別なイベントなし"
		_event_icon.texture = MockStyle.art("store_building")


func _category_icon(category: String) -> Texture2D:
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	for id in products.skus:
		var sku: Dictionary = products.get_sku(id)
		if String(sku["category"]) == category:
			return ProductIcons.texture(sku, 64)
	return null
