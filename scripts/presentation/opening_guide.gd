class_name OpeningGuide
extends Control
## 開店までの手順: a card at the top right while the store is being set up (business state SETUP), in the 2026-11-01
## mockup look. The first-day tutorial's steps from レジ to 営業開始 (ProgressionService, tutorial_step_index), each
## with a mark (done / now / later) and a button that goes where the step is done; the last one is 開店する itself,
## with the opening checklist's first missing condition under it while it cannot open. Presentation only: the buttons
## emit go_requested / open_requested and MainLayout acts.

signal go_requested(where: String)   # "build" (店舗) / "goods" (商品 tab) / "shelf" (restock: pick a shelf)
signal open_requested

const RECT := Rect2(1520, 78, 392, 432)
## [tutorial step (1-based), text, where its button goes, button text]
const STEPS := [[2, "レジを置く", "build", "店舗へ"], [3, "棚を置く", "build", "店舗へ"], [4, "商品を10個以上発注", "goods", "発注へ"],
	[5, "棚に商品を補充", "shelf", "棚を選ぶ"], [6, "お店を開店する", "", ""]]
const ROW_Y := 70
const ROW_H := 52

var _rows: Array[Dictionary] = []
var _open: Button
var _open_plate: UiShape
var _why: Label


func _ready() -> void:
	name = "OpeningGuide"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	MockStyle.shape(self, Rect2(0, 18, RECT.size.x, RECT.size.y - 18), {"top": Color("6e4c3c"), "bottom": Color("4a3026"), "border": Color("e2b273"),
		"border_width": 3.0, "radius": 20.0, "inner": Color("f6cf8f"), "inner_inset": 5.0, "shadow": Color(0, 0, 0, 0.4), "shadow_offset": Vector2(0, 5)})
	MockStyle.shape(self, Rect2(10, 56, RECT.size.x - 20, RECT.size.y - 66), {"top": Color("fff8ef"), "bottom": Color("f3e1d1"), "border": Color("e9cfb9"),
		"border_width": 2.0, "radius": 14.0})
	MockStyle.ribbon(self, Rect2(-6, 4, 270, 46), "開店までの手順", MockStyle.RIBBON_BLUE, "store", 22)
	for i in STEPS.size():
		var st: Array = STEPS[i]
		var y := ROW_Y + i * ROW_H
		var mark := MockStyle.shape(self, Rect2(22, y + 10, 32, 32), {"kind": UiShape.Kind.CIRCLE, "border_width": 2.0, "gloss": 0.3})
		var num := MockStyle.label(mark, str(i + 1), Rect2(0, 0, 32, 32), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "Black")
		var text := MockStyle.label(self, st[1], Rect2(64, y, 200, ROW_H), 19, MockStyle.INK, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold")
		var go: Button = null
		if st[2] != "":
			go = MockStyle.face_button(self, Rect2(RECT.size.x - 122, y + 8, 100, 36), st[3], Color("4f95e8"), Color("1d58b0"), Color("bcdcff"),
				Color.WHITE, 16, "", 8.0)
			var where: String = st[2]
			go.pressed.connect(func(): go_requested.emit(where))
		_rows.append({"mark": mark, "num": num, "text": text, "go": go})
	_open = MockStyle.button(self, Rect2(22, ROW_Y + STEPS.size() * ROW_H + 4, RECT.size.x - 44, 52), "開店する")
	_open.name = "OpenStore"
	_open_plate = MockStyle.shape(_open, Rect2(0, 0, RECT.size.x - 44, 52), {"radius": 12.0, "border_width": 2.5, "gloss": 0.35,
		"shadow": Color(0.5, 0.2, 0.0, 0.35), "shadow_offset": Vector2(0, 3)})
	MockStyle.picture(_open, MockStyle.glyph("store", 96), Rect2(90, 10, 34, 32))
	MockStyle.label(_open, "開店する", Rect2(132, 0, 200, 52), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, "ExtraBold", 3, Color(0, 0, 0, 0.3))
	_open.pressed.connect(func(): open_requested.emit())
	_why = MockStyle.label(self, "", Rect2(22, RECT.size.y - 40, RECT.size.x - 44, 26), 15, MockStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, "Bold")


## Shown only before the first opening of the day (SETUP); `done_steps` = tutorial_step_index (steps finished).
func apply_snapshot(s: Dictionary) -> void:
	var setup: bool = String(s.get("business_state", "")) == "SETUP"
	var done_steps := int(s.get("progression", {}).get("tutorial_step_index", 0))
	var opening: Dictionary = s.get("opening", {})
	var ready := not opening.is_empty() and bool(opening.get("ready", false))
	visible = setup
	if not setup:
		return
	var current := -1
	for i in STEPS.size():
		var step: int = STEPS[i][0]
		var done := done_steps >= step or (step == 5 and bool(opening.get("stock_ok", false)))
		if not done and current < 0:
			current = i
		var r: Dictionary = _rows[i]
		var state := "done" if done else ("now" if current == i else "later")
		(r["mark"] as UiShape).setup({"top": Color("6fd16a") if done else (Color("ffb21e") if state == "now" else Color("cfc4bb")),
			"bottom": Color("2f9a3a") if done else (Color("e1500a") if state == "now" else Color("a99c92")),
			"border": Color("e9ffe4") if done else (Color("ffe1a8") if state == "now" else Color("f2ebe5"))})
		(r["num"] as Label).text = "✓" if done else str(i + 1)
		(r["text"] as Label).add_theme_color_override("font_color", MockStyle.MUTED if done else (MockStyle.INK if state == "now" else Color("a89484")))
		if r["go"] != null:
			(r["go"] as Button).visible = state == "now"
	_open.disabled = not ready
	_open_plate.setup({"top": Color("ffb21e") if ready else Color("d8cbb4"), "bottom": Color("e1500a") if ready else Color("b9a88c"),
		"border": Color("ffc35a") if ready else Color("c8b9a4")})
	_why.text = "" if ready else why_not(opening)


## The first missing opening condition, in words ("" when it can open).
static func why_not(opening: Dictionary) -> String:
	if opening.is_empty():
		return ""
	if not bool(opening.get("register_ok", true)):
		return "まずレジを置きましょう"
	if not bool(opening.get("stock_ok", true)):
		return "客が行ける棚に商品を並べましょう"
	if not bool(opening.get("cash_ok", true)):
		return "今日の費用に所持金が足りません"
	return ""
