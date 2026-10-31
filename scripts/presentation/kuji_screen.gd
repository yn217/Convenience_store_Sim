class_name KujiScreen
extends Control
## 限定くじ管理 (issue #138): the user's mockup (2026-10-31) is the screen itself. Its art, with the left menu cut
## off and every changing value erased (tools/assets/build_kuji_screen.py), is drawn at its own pixel size and scaled
## to fit; the status chip, the dates, the prizes left, the set values and 小春六花's line are drawn live on top, and
## the two baked buttons get invisible buttons over them. Rikka's hand over the B row is drawn again above its bar.
## Presentation only: buying the set is START_LOTTERY through LotteryController; the rest comes from the snapshot.

signal buy_requested(set_id: String)

const SET_ID := "kuji_starry"   # the set the art shows (星空マスコットくじ)
const ART := "res://assets/ui/kuji/kuji_screen.png"
const HAND := "res://assets/ui/kuji/kuji_hand.png"
const ART_SIZE := Vector2(1482, 941)
const HAND_AT := Vector2(960, 440)
const INK := Color("1f2f57")   # the mockup's dark navy text
const STATUS := {
	"": ["未販売", Color("7d8796")], "selling": ["販売中", Color("2fa35a")],
	"sold_out": ["完売", Color("ee8a23")], "ended": ["終了", Color("7d8796")],
}
# Rects in art pixels: where the mockup had the values that are now drawn live.
const CHIP_RECT := Rect2(675, 113, 235, 41)
const PERIOD_RECT := Rect2(772, 163, 140, 37)
const PRIZE_X := 880.0
const PRIZE_ROWS_Y := [374.0, 464.0, 558.0, 653.0]   # A, B, C, D
const PRIZE_BAR_WIDTH := 172.0
const BAR_COLORS := [Color("f0be3c"), Color("3196e6"), Color("3cb450"), Color("3cb450")]
const VALUE_RECTS := [Rect2(112, 756, 142, 46), Rect2(342, 756, 112, 46), Rect2(542, 756, 112, 46), Rect2(726, 756, 222, 46)]
const VALUE_COLORS := [Color("1f2f57"), Color("1f2f57"), Color("1e8c3c"), Color("e63c78")]
const BUY_RECT := Rect2(407, 818, 290, 64)
const DISPLAY_RECT := Rect2(712, 818, 228, 64)
const BUBBLE_RECT := Rect2(1218, 664, 222, 184)
const CLOSE_RECT := Rect2(1346, 14, 122, 46)

var _canvas: Control
var _chip: PanelContainer
var _chip_text: Label
var _period: Label
var _prize_counts: Array[Label] = []
var _prize_bars: Array[ProgressBar] = []
var _values: Array[Label] = []
var _line: Label
var _buy: Button
var _buy_dim: Panel
var _display: Button
var _view: Dictionary = {}
var _note := ""   # the answer to the last 仕入れる, shown in her bubble until the next snapshot changes the run


func _init() -> void:
	name = "KujiScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.size = ART_SIZE
	add_child(_canvas)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = load(ART) as Texture2D
	art.size = ART_SIZE
	_canvas.add_child(art)
	_chip = PanelContainer.new()
	_chip.position = CHIP_RECT.position
	_chip.size = CHIP_RECT.size
	_chip_text = _text(_chip, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_canvas.add_child(_chip)
	_period = _text(_canvas, 22, INK, HORIZONTAL_ALIGNMENT_LEFT, PERIOD_RECT)
	for i in PRIZE_ROWS_Y.size():
		var y: float = PRIZE_ROWS_Y[i]
		_prize_counts.append(_text(_canvas, 22, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(PRIZE_X, y, PRIZE_BAR_WIDTH, 28)))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.position = Vector2(PRIZE_X, y + 32)
		bar.size = Vector2(PRIZE_BAR_WIDTH, 13)
		bar.add_theme_stylebox_override("background", _round(Color("d8dde5"), 6))
		bar.add_theme_stylebox_override("fill", _round(BAR_COLORS[i], 6))
		_canvas.add_child(bar)
		_prize_bars.append(bar)
	var hand := TextureRect.new()
	hand.name = "Hand"
	hand.texture = load(HAND) as Texture2D
	hand.position = HAND_AT
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(hand)
	for i in VALUE_RECTS.size():
		_values.append(_text(_canvas, 27, VALUE_COLORS[i], HORIZONTAL_ALIGNMENT_LEFT, VALUE_RECTS[i]))
	_line = _text(_canvas, 20, INK, HORIZONTAL_ALIGNMENT_CENTER, BUBBLE_RECT)
	_line.name = "RikkaLine"
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy = _hotspot("BuyButton", BUY_RECT)
	_buy.tooltip_text = "セットを丸ごと仕入れて販売を始めます"
	_buy.pressed.connect(func(): buy_requested.emit(SET_ID))
	_buy_dim = Panel.new()
	_buy_dim.position = BUY_RECT.position
	_buy_dim.size = BUY_RECT.size
	_buy_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_dim.add_theme_stylebox_override("panel", _round(Color(0.32, 0.34, 0.4, 0.6), 12))
	_canvas.add_child(_buy_dim)
	_display = _hotspot("DisplayButton", DISPLAY_RECT)
	_display.tooltip_text = "画面を閉じて、店内の展示を見ます"
	_display.pressed.connect(close)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "閉じる ×"
	close_button.position = CLOSE_RECT.position
	close_button.size = CLOSE_RECT.size
	close_button.pressed.connect(close)
	_canvas.add_child(close_button)
	resized.connect(_fit)


func _ready() -> void:
	_fit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_note = ""
	visible = true
	_fit()
	_render()


func close() -> void:
	visible = false


## Scales the art to fit the window with a small margin, centred.
func _fit() -> void:
	if _canvas == null:
		return
	var k := minf(size.x * 0.96 / ART_SIZE.x, size.y * 0.96 / ART_SIZE.y)
	if k <= 0.0:
		return
	_canvas.scale = Vector2(k, k)
	_canvas.position = (size - ART_SIZE * k) * 0.5


## view: the set's entry of snapshot.lotteries; day: the game day; other_selling: another set is on sale.
func apply(view: Dictionary, day: int, other_selling: bool) -> void:
	var run_before: Dictionary = _view.get("run", {})
	_view = view.duplicate(true)
	_view["_day"] = day
	_view["_other_selling"] = other_selling
	var run_after: Dictionary = view.get("run", {})
	if run_before.get("lottery_id", "") != run_after.get("lottery_id", "") or run_before.get("status", "") != run_after.get("status", ""):
		_note = ""   # the run moved on (a sell-out, the end): her line follows it again
	_render()


func show_result(ok: bool, message: String) -> void:
	_note = message
	_render()


func _render() -> void:
	if _view.is_empty():
		return
	var run: Dictionary = _view.get("run", {})
	var status := String(run.get("status", ""))
	var st: Array = STATUS.get(status, STATUS[""])
	_chip_text.text = st[0]
	_chip.add_theme_stylebox_override("panel", _round(st[1], 10))
	_period.text = period_text(_view)
	var remaining: Dictionary = run.get("remaining", {})
	var prizes: Array = _view.get("prizes", [])
	for i in _prize_counts.size():
		if i >= prizes.size():
			continue
		var p: Dictionary = prizes[i]
		var total := int(p["count"])
		var left := int(remaining.get(p["tier"], total)) if not run.is_empty() else total
		_prize_counts[i].text = "%d / %d" % [left, total]
		_prize_bars[i].value = float(left) / maxf(float(total), 1.0)
	var tickets := int(_view.get("tickets", 0))
	_values[0].text = "%s円" % GameHud.format_yen(int(_view.get("set_cost_yen", 0))).trim_prefix("¥")
	_values[1].text = "%d枚" % tickets
	_values[2].text = "%d枚" % (tickets - int(run.get("sold", 0)) if not run.is_empty() else tickets)
	_values[3].text = forecast_text(_view, int(_view.get("_day", 0)))
	var busy := status == "selling" or bool(_view.get("_other_selling", false))
	_buy.disabled = busy
	_buy_dim.visible = busy
	_line.text = _note if _note != "" else rikka_line(_view, bool(_view.get("_other_selling", false)))


static func period_text(v: Dictionary) -> String:
	var run: Dictionary = v.get("run", {})
	if run.is_empty():
		return "%d日間" % int(v.get("days", 0))
	return "DAY %d〜%d" % [int(run.get("start_day", 0)), int(run.get("end_day", 0))]


## 売切れ予測: at today's pace (tickets sold per day so far), the day the last ticket goes.
static func forecast_text(v: Dictionary, day: int) -> String:
	var run: Dictionary = v.get("run", {})
	match String(run.get("status", "")):
		"sold_out":
			return "完売しました"
		"selling":
			var sold := int(run.get("sold", 0))
			if sold <= 0:
				return "まだ予測できません"
			var rate := float(sold) / float(maxi(day - int(run.get("start_day", day)) + 1, 1))
			var left := int(v.get("tickets", 0)) - sold
			var finish := day + int(ceil(float(left) / rate)) - 1
			if finish > int(run.get("end_day", day)):
				return "期間内は難しそう"
			return "DAY %d 頃" % finish
		"ended":
			return "期間終了"
	return "—"


## 小春六花's line in the bubble, from the set's state.
static func rikka_line(v: Dictionary, other_selling: bool) -> String:
	var run: Dictionary = v.get("run", {})
	var name := String(v.get("display_name", ""))
	match String(run.get("status", "")):
		"selling":
			var a_left := int(run.get("remaining", {}).get("A", 0))
			var left := int(v.get("tickets", 0)) - int(run.get("sold", 0))
			var a_text := "A賞はあと %d 個ですよ。" % a_left if a_left > 0 else "A賞はもう出ちゃいました！"
			return "%s\n開催中です！\n残り %d 枚、\n%s" % [name, left, a_text]
		"sold_out":
			return "完売しました！\nおつかれさまでした。\nラストワン賞も\n出ましたよ。"
		"ended":
			return "くじの期間が\n終わりました。\n売れ残りは\n損になっちゃいます…"
	if other_selling:
		return "いまは別のくじを\n販売中です。\n終わったら\n仕入れましょう！"
	return "%s、\n仕入れてみませんか？\nかわいい景品が\nたくさんですよ！" % name


func _text(parent: Control, font_size: int, color: Color, align: HorizontalAlignment, rect: Rect2 = Rect2()) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", color)   # a thin outline in the text colour reads as bold
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.size != Vector2.ZERO:
		l.position = rect.position
		l.size = rect.size
	parent.add_child(l)
	return l


func _hotspot(node_name: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.position = rect.position
	b.size = rect.size
	_canvas.add_child(b)
	return b


static func _round(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	return s
