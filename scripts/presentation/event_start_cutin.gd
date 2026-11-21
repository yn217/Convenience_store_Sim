class_name EventStartCutin
extends CanvasLayer
## When today's event begins (its window opens while the player watches: the view goes from scheduled to active),
## its special picture with 小春六花 fills the screen over the blurred store (user's request 2026-11-21): a pink
## イベント開始！ ribbon with the event's name and her line in the speech box. The clock stops meanwhile; a click, or
## AUTO_SECONDS, closes it and the clock runs on at the earlier speed. An event already running when the game is loaded
## does not play it, nor does an event without a picture (assets/runtime/event_cutins/<event_id>.png). Presentation only.

const ART_DIR := "res://assets/runtime/event_cutins/"
const ART_SIZE := Vector2(1240, 698)   # the 1344x756 picture, 16:9
const AUTO_SECONDS := 6.0
const PINK := Color("ef6f96")
const LINES := {
	"evt_local_fair": "お祭りが始まりました！ 夕方はお客さんが増えますよ〜！",
	"evt_hot_day": "暑いですね〜！ 冷たい飲み物とアイス、切らさないようにしましょう！",
	"evt_cold_day": "さむっ……！ 今日はあったかい食べ物の出番ですね。",
	"evt_sudden_rain": "わっ、降ってきました！ 傘を入口に出しておきますね！",
	"evt_onigiri_festa": "おにぎり祭り、スタートです！ 午前中はおにぎりが主役ですよ！",
	"evt_sweets_spotlight": "甘いもの特集が始まりました！ デザート、いっぱい並べましょう♪",
	"evt_after_work": "お仕事帰りのお客さんが来ますよ〜！ レジ前の準備はばっちりです！",
}

var _app: Node
var _armed := {}    # "day:event_id" seen before it began
var _shown := {}    # "day:event_id" already played
var _paused := false
var _event_id := ""
var _root: Control
var _card: PanelContainer
var _art: TextureRect
var _ribbon: PanelContainer
var _name: Label
var _line_box: PanelContainer
var _line: Label
var _timer: SceneTreeTimer


func _init() -> void:
	layer = 39   # over the store, the HUD and the assistant; under the event choice (40)
	name = "EventStartCutin"
	_build()
	visible = false


func setup(app: Node) -> void:
	_app = app


func is_open() -> bool:
	return visible


func event_id() -> String:
	return _event_id


static func picture_path(id: String) -> String:
	return ART_DIR + id + ".png"


static func line_for(view: Dictionary) -> String:
	return String(LINES.get(String(view.get("event_id", "")), "%sが始まりました！ がんばりましょう！" % String(view.get("name_ja", "イベント"))))


## From EventController with every snapshot. `blocked`: another screen holds the player (the choice, the 開店！ band);
## the cut-in then waits for it.
func observe(view: Dictionary, blocked: bool = false) -> void:
	var id := String(view.get("event_id", ""))
	if id == "" or not ResourceLoader.exists(picture_path(id)):
		return
	var key := "%d:%s" % [int(view.get("day", 0)), id]
	match String(view.get("status", "")):
		"scheduled":
			_armed[key] = true
		"active":
			if _armed.has(key) and not _shown.has(key) and not blocked and not visible:
				_shown[key] = true
				_open(view)


func _open(view: Dictionary) -> void:
	_event_id = String(view["event_id"])
	_art.texture = load(picture_path(_event_id)) as Texture2D
	_name.text = String(view.get("name_ja", ""))
	_line.text = line_for(view)
	visible = true
	_guide_aside(true)
	if _app != null and _app.get("state") != null and int(_app.state.speed_setting) > 0:
		_paused = _app.set_speed(0).ok
	_animate()
	if is_inside_tree():
		_timer = get_tree().create_timer(AUTO_SECONDS)
		var shown_id := _event_id
		_timer.timeout.connect(func():
			if visible and _event_id == shown_id:
				close())


func close() -> void:
	if not visible:
		return
	visible = false
	_guide_aside(false)
	if _paused:
		_paused = false
		if _app != null and _app.get("state") != null:
			_app.set_speed(maxi(int(_app.state.last_nonzero_speed), 1))


func card_text() -> String:
	return "イベント開始！ %s\n%s" % [_name.text, _line.text]


func _guide_aside(on: bool) -> void:
	var guide := get_parent().get_node_or_null("ProgressionController") if get_parent() != null else null
	if guide != null and guide.has_method("set_suppressed"):
		guide.set_suppressed(on, "event_start")


## The picture zooms in from slightly large, the ribbon slides in from the left, her line rises last.
func _animate() -> void:
	if UiFx.reduced or not is_inside_tree():
		return
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(1.06, 1.06)
	_card.modulate.a = 0.0
	_ribbon.modulate.a = 0.0
	_line_box.modulate.a = 0.0
	var rib_x := _ribbon.position.x
	_ribbon.position.x = rib_x - 80
	var line_y := _line_box.position.y
	_line_box.position.y = line_y + 30
	var tw := create_tween()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_ribbon, "position:x", rib_x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ribbon, "modulate:a", 1.0, 0.2)
	tw.tween_property(_line_box, "position:y", line_y, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_line_box, "modulate:a", 1.0, 0.2)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.build()
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.name = "EventStartBackdrop"
	backdrop.material = UiFx.blur_material()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	# The picture in a white rounded frame with a soft shadow, a little above the centre.
	_card = PanelContainer.new()
	_card.name = "EventStartCard"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.WHITE
	frame.set_corner_radius_all(18)
	frame.set_content_margin_all(8)
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 6)
	_card.add_theme_stylebox_override("panel", frame)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -ART_SIZE.x * 0.5 - 8
	_card.offset_right = ART_SIZE.x * 0.5 + 8
	_card.offset_top = -ART_SIZE.y * 0.5 - 40
	_card.offset_bottom = ART_SIZE.y * 0.5 - 24
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	_art = TextureRect.new()
	_art.name = "EventStartArt"
	_art.custom_minimum_size = ART_SIZE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_art)
	# イベント開始！ and the event's name, over the picture's top-left corner.
	_ribbon = PanelContainer.new()
	_ribbon.name = "EventStartRibbon"
	var rb := StyleBoxFlat.new()
	rb.bg_color = PINK
	rb.set_corner_radius_all(16)
	rb.border_color = Color.WHITE
	rb.set_border_width_all(4)
	rb.content_margin_left = 28
	rb.content_margin_right = 32
	rb.content_margin_top = 8
	rb.content_margin_bottom = 10
	rb.shadow_color = Color(0, 0, 0, 0.25)
	rb.shadow_size = 8
	_ribbon.add_theme_stylebox_override("panel", rb)
	_ribbon.set_anchors_preset(Control.PRESET_CENTER)
	_ribbon.position = Vector2(-ART_SIZE.x * 0.5 - 30, -ART_SIZE.y * 0.5 - 76)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ribbon)
	var rib_col := VBoxContainer.new()
	rib_col.add_theme_constant_override("separation", -4)
	_ribbon.add_child(rib_col)
	var head := Label.new()
	head.text = "イベント開始！"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("fff3a8"))
	rib_col.add_child(head)
	_name = Label.new()
	_name.name = "EventStartName"
	_name.add_theme_font_size_override("font_size", 44)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_color_override("font_outline_color", Color("b8406a"))
	_name.add_theme_constant_override("outline_size", 8)
	rib_col.add_child(_name)
	# Her line: the assistant's cream speech box over the picture's lower edge.
	_line_box = PanelContainer.new()
	_line_box.name = "EventStartLine"
	_line_box.add_theme_stylebox_override("panel", ProgressionController.bubble_style())
	_line_box.set_anchors_preset(Control.PRESET_CENTER)
	_line_box.position = Vector2(-ART_SIZE.x * 0.5 + 60, ART_SIZE.y * 0.5 - 120)
	_line_box.custom_minimum_size = Vector2(ART_SIZE.x - 120, 0)
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_line_box)
	var line_col := VBoxContainer.new()
	line_col.add_theme_constant_override("separation", 6)
	_line_box.add_child(line_col)
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_theme_stylebox_override("panel", ProgressionController._name_tab_style())
	var who := Label.new()
	who.text = "%s（店長アシスタント）" % ProgressionController.ASSISTANT_NAME
	who.add_theme_color_override("font_color", Color.WHITE)
	who.add_theme_font_size_override("font_size", 16)
	tab.add_child(who)
	line_col.add_child(tab)
	_line = Label.new()
	_line.name = "EventStartLineText"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 24)
	_line.custom_minimum_size = Vector2(ART_SIZE.x - 170, 0)   # the wrap width, else the box grows tall
	_line.add_theme_color_override("font_color", ProgressionController.BUBBLE_TEXT)
	line_col.add_child(_line)
	var hint := Label.new()
	hint.text = "クリックで閉じる"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("outline_size", 4)
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(ART_SIZE.x * 0.5 - 140, -ART_SIZE.y * 0.5 - 70)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)
