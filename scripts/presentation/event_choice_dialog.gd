class_name EventChoiceDialog
extends CanvasLayer
## Today's event asks the player to choose (user's decision 2026-11-13: a paid choice costs money): the event's picture,
## what is happening and when, and one button per choice with its cost and effects. The clock stops while it is
## open and runs on at the earlier speed after the pick; Rikka then says the choice's line. It only sends
## CHOOSE_EVENT_OPTION through AppRoot; EventService decides. Not choosing is not possible here, but the free choice
## is always one of the buttons (and it is what holds if the dialog never opens, e.g. the event already ended).
## Since 2026-11-21 it looks like the event's start cut-in (EventStartCutin): the store blurred behind, a cream window,
## a pink ribbon with the event's name, the picture in a white frame and her question in her speech box.

const ART_DIR := "res://assets/runtime/event_choices/"
const ART_SIZE := Vector2(640, 360)
const PANEL_WIDTH := 720
const PAID_REACTION := "res://assets/runtime/rikka_reactions/reaction_34.png"   # wink and a peace sign
const FREE_REACTION := "res://assets/runtime/rikka_reactions/reaction_21.png"   # thumbs up
const ASK_LINE := "店長、どうしましょうか？"
const PINK := Color("ef6f96")

var _app: Node
var _offered := {}            # "day:event_id" already offered in this session
var _view: Dictionary = {}
var _paused_by_dialog := false
var _seq := 0
var _root: Control
var _title: Label
var _art: TextureRect
var _desc: Label
var _ask: Label
var _buttons: VBoxContainer
var _message: Label


func _init() -> void:
	layer = 40   # above the store, the HUD and the assistant; below nothing the player needs while choosing
	name = "EventChoiceDialog"
	_build()
	visible = false


func setup(app: Node) -> void:
	_app = app


func is_open() -> bool:
	return visible


func current_view() -> Dictionary:
	return _view


## From EventController with every snapshot: opens once per day for an event with choices that is still to come or
## running and not chosen yet.
func offer(view: Dictionary) -> void:
	if visible:
		return
	var choices: Array = view.get("choices", [])
	if choices.is_empty() or String(view.get("choice_id", "")) != "" or not String(view.get("status", "")) in ["scheduled", "active"]:
		return
	var key := "%d:%s" % [int(view.get("day", 0)), String(view.get("event_id", ""))]
	if _offered.has(key):
		return
	_offered[key] = true
	_open(view)


func _open(view: Dictionary) -> void:
	_view = view
	var event_id := String(view["event_id"])
	_title.text = String(view["name_ja"])
	var art_path := ART_DIR + event_id + ".png"
	_art.texture = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	_art.visible = _art.texture != null
	_art.get_parent().visible = _art.visible   # its white frame
	_desc.text = "%s\n開催 %s〜%s" % [String(view["description_ja"]), EventText.clock(int(view["start_sec"])), EventText.clock(int(view["end_sec"]))]
	_ask.text = ASK_LINE
	_message.text = ""
	_message.visible = false
	for b in _buttons.get_children():
		b.queue_free()
	var cash := int(_app.state.cash_yen) if _app != null and _app.get("state") != null else 0
	for c in view["choices"]:
		var b := Button.new()
		b.name = "Choice_%s" % c["choice_id"]
		b.text = choice_text(c, _free_traffic(view["choices"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(PANEL_WIDTH - 48, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if int(c["cost_yen"]) > 0:
			b.theme_type_variation = &"PrimaryButton"
		b.disabled = int(c["cost_yen"]) > cash
		if b.disabled:
			b.tooltip_text = "資金が足りません"
		b.pressed.connect(choose.bind(String(c["choice_id"])))
		_buttons.add_child(b)
	visible = true
	_guide_aside(true)
	UiFx.open_pop(_root.find_child("EventChoicePanel", true, false) as Control)
	if _app != null and _app.get("state") != null and int(_app.state.speed_setting) > 0:
		_paused_by_dialog = _app.set_speed(0).ok


static func _free_traffic(choices: Array) -> float:
	for c in choices:
		if int(c["cost_yen"]) == 0:
			return float(c["traffic"])
	return 1.0


## Button text: the label and cost on the first line, the effects, then what it means. When the event changes the
## traffic and this choice brings it back to normal, that is said too (来店 ±0%), so the two choices compare.
static func choice_text(c: Dictionary, free_traffic: float = 1.0) -> String:
	var cost := int(c["cost_yen"])
	var head := "%s　%s" % [String(c["label_ja"]), ("−%s" % GameHud.format_yen(cost)) if cost > 0 else "無料"]
	var fx := EventText.effect_chips({"traffic": float(c["traffic"]), "categories": c["categories"]}).map(func(chip): return String(chip["text"]))
	if absf(float(c["traffic"]) - 1.0) < 0.0001 and absf(free_traffic - 1.0) > 0.0001:
		fx.push_front("来店 ±0%")
	var effect := "・".join(fx) if not fx.is_empty() else "効果なし"
	return "%s\n%s\n%s" % [head, effect, String(c["description_ja"])]


func choose(choice_id: String) -> void:
	if _app == null:
		return
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_event_choice_%d_%s" % [_seq, choice_id], "kind": &"CHOOSE_EVENT_OPTION", "choice_id": choice_id})
	if not r.ok:
		_message.text = CommandMessages.text(r.code, r.message_key)
		_message.visible = true
		return
	var picked: Dictionary = {}
	for c in _view.get("choices", []):
		if String(c["choice_id"]) == choice_id:
			picked = c
	_close()
	var guide := get_parent().get_node_or_null("ProgressionController") if get_parent() != null else null
	if guide != null and guide.has_method("say") and not picked.is_empty():
		guide.say(String(picked["line_ja"]), PAID_REACTION if int(picked["cost_yen"]) > 0 else FREE_REACTION)


func _close() -> void:
	visible = false
	_guide_aside(false)
	if _paused_by_dialog and _app != null:
		_paused_by_dialog = false
		_app.set_speed(maxi(int(_app.state.last_nonzero_speed), 1))


## The corner assistant steps aside while this dialog is open (her card would show dimmed behind it).
func _guide_aside(on: bool) -> void:
	var guide := get_parent().get_node_or_null("ProgressionController") if get_parent() != null else null
	if guide != null and guide.has_method("set_suppressed"):
		guide.set_suppressed(on, "dialog")


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # the store behind does not take clicks while she asks
	_root.theme = BusinessController.map_overlay_theme()   # a CanvasLayer does not pass Main's theme down; cream and pop
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.name = "EventChoiceBackdrop"
	backdrop.material = UiFx.blur_material()   # the store behind, blurred (as the start cut-in)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "EventChoicePanel"
	panel.theme_type_variation = &"WindowFrame"
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	# 今日のイベント and its name on a pink ribbon.
	var ribbon := PanelContainer.new()
	ribbon.name = "EventChoiceRibbon"
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var rb := StyleBoxFlat.new()
	rb.bg_color = PINK
	rb.set_corner_radius_all(14)
	rb.border_color = Color.WHITE
	rb.set_border_width_all(3)
	rb.content_margin_left = 22
	rb.content_margin_right = 26
	rb.content_margin_top = 4
	rb.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rb)
	col.add_child(ribbon)
	var rib_col := VBoxContainer.new()
	rib_col.add_theme_constant_override("separation", -4)
	ribbon.add_child(rib_col)
	var head := Label.new()
	head.text = "今日のイベント"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color("fff3a8"))
	rib_col.add_child(head)
	_title = Label.new()
	_title.name = "EventChoiceTitle"
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color("b8406a"))
	_title.add_theme_constant_override("outline_size", 6)
	rib_col.add_child(_title)
	# The picture in a white rounded frame.
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color.WHITE
	fb.set_corner_radius_all(14)
	fb.set_content_margin_all(6)
	fb.shadow_color = Color(0, 0, 0, 0.2)
	fb.shadow_size = 8
	fb.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", fb)
	col.add_child(frame)
	_art = TextureRect.new()
	_art.name = "EventChoiceArt"
	_art.custom_minimum_size = ART_SIZE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(_art)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = PANEL_WIDTH - 48
	col.add_child(_desc)
	# Her question in her speech box.
	var bubble := PanelContainer.new()
	bubble.name = "EventChoiceAsk"
	bubble.add_theme_stylebox_override("panel", ProgressionController.bubble_style())
	col.add_child(bubble)
	var ask_col := VBoxContainer.new()
	ask_col.add_theme_constant_override("separation", 4)
	bubble.add_child(ask_col)
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_theme_stylebox_override("panel", ProgressionController._name_tab_style())
	var who := Label.new()
	who.text = "%s（店長アシスタント）" % ProgressionController.ASSISTANT_NAME
	who.add_theme_color_override("font_color", Color.WHITE)
	who.add_theme_font_size_override("font_size", 15)
	tab.add_child(who)
	ask_col.add_child(tab)
	_ask = Label.new()
	_ask.add_theme_font_size_override("font_size", 22)
	_ask.add_theme_color_override("font_color", ProgressionController.BUBBLE_TEXT)
	ask_col.add_child(_ask)
	_buttons = VBoxContainer.new()
	_buttons.name = "EventChoiceButtons"
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	_message = Label.new()
	_message.theme_type_variation = &"BadLabel"
	col.add_child(_message)
