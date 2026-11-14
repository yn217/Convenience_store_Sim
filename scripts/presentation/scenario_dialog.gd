class_name ScenarioDialog
extends CanvasLayer
## The scenario's card (user's decision 2026-11-14): at the start of a new scenario game, its story, deadline and goals;
## when the result comes (SCENARIO_CLEARED / SCENARIO_FAILED), クリア！ or 期限終了 with the goals reached and Rikka's line.
## The clock stops while the result is open and runs on at the earlier speed. There is no game over: このまま続ける goes
## on as free play, タイトルへ asks the usual return-to-title question. Presentation only; ScenarioService decides.

const INTRO_REACTION := "res://assets/runtime/rikka_reactions/reaction_06.png"   # inviting, hand out
const CLEAR_REACTION := "res://assets/runtime/rikka_reactions/reaction_46.png"   # beaming
const FAIL_REACTION := "res://assets/runtime/rikka_reactions/reaction_48.png"    # hands together, sorry
const PANEL_WIDTH := 760
const ART_SIZE := Vector2(220, 220)

var _app: Node
var _mode := ""             # "intro" / "cleared" / "failed"
var _introduced := false
var _paused_by_dialog := false
var _root: Control
var _title: Label
var _art: TextureRect
var _line: Label
var _body: Label
var _goals: Label
var _note: Label
var _ok: Button
var _to_title: Button


func _init() -> void:
	layer = 41   # above the event choice (40): a result can come while nothing else asks
	name = "ScenarioDialog"
	_build()
	visible = false


func setup(app: Node) -> void:
	_app = app


func is_open() -> bool:
	return visible


func mode() -> String:
	return _mode if visible else ""


## From ProgressionController with every snapshot: the intro once, for a scenario game that has not opened yet.
func offer_intro(snap: Dictionary) -> void:
	var view: Dictionary = snap.get("scenario", {})
	if _introduced or visible or view.is_empty() or String(view["status"]) != "active":
		return
	_introduced = true
	if String(snap.get("business_state", "")) != String(GameState.SETUP) or int(snap.get("time_sec", 0)) > 0:
		return   # a scenario game loaded mid-way: the goal panel shows it, no card
	var sc := ScenarioRules.find(String(view["scenario_id"]))
	_mode = "intro"
	_title.text = "シナリオ：%s" % String(view["name_ja"])
	_set_art(INTRO_REACTION)
	_line.text = "小春六花「%s」" % String(sc.get("intro_ja", ""))
	_body.text = "%s\n期限：%d日（%s）" % [String(view["summary_ja"]), int(view["days"]), ScenarioText.difficulty_text(int(sc.get("difficulty", 1)))]
	_goals.text = "目標\n" + "\n".join((sc.get("goals", []) as Array).map(func(g): return "・" + ScenarioText.target_text(g)))
	_note.text = "期限が過ぎても、お店はそのまま続けられます。"
	_ok.text = "はじめる"
	_to_title.visible = false
	visible = true
	_guide_aside(true)


## The result card for SCENARIO_CLEARED / SCENARIO_FAILED; records a clear on this computer.
func show_result(event: Dictionary, view: Dictionary) -> void:
	var sc := ScenarioRules.find(String(event.get("scenario_id", "")))
	if sc.is_empty():
		return
	var cleared := String(event["kind"]) == "SCENARIO_CLEARED"
	_mode = "cleared" if cleared else "failed"
	var days := int(event.get("days_used", 0))
	_title.text = ("シナリオクリア！　%s" if cleared else "期限終了　%s") % String(sc["name_ja"])
	_set_art(CLEAR_REACTION if cleared else FAIL_REACTION)
	_line.text = "小春六花「%s」" % String(sc["clear_ja"] if cleared else sc["fail_ja"])
	var best := ScenarioText.record_clear(String(sc["scenario_id"]), days) if cleared else false
	_body.text = ("%d日でクリアしました。%s" % [days, "（自己ベスト！）" if best else ""]) if cleared else "%d日の期限が終わりました。" % int(sc["days"])
	var rows: Array = view.get("goals", []) if not view.is_empty() else []
	_goals.text = "結果\n" + "\n".join(rows.map(func(r): return ScenarioText.goal_text(r)))
	_note.text = "このままフリープレイで続けられます。"
	_ok.text = "このまま続ける"
	_to_title.visible = true
	visible = true
	_guide_aside(true)
	if _app != null and _app.get("state") != null and int(_app.state.speed_setting) > 0:
		_paused_by_dialog = _app.set_speed(0).ok


func _set_art(path: String) -> void:
	_art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_art.visible = _art.texture != null


func close() -> void:
	visible = false
	_mode = ""
	_guide_aside(false)
	if _paused_by_dialog and _app != null:
		_paused_by_dialog = false
		_app.set_speed(maxi(int(_app.state.last_nonzero_speed), 1))


## The corner assistant steps aside while this dialog is open (her card would show dimmed behind it).
func _guide_aside(on: bool) -> void:
	var guide := get_parent().get_node_or_null("ProgressionController") if get_parent() != null else null
	if guide != null and guide.has_method("set_suppressed"):
		guide.set_suppressed(on, "dialog")


func _on_to_title() -> void:
	close()
	var returner := get_parent().get_node_or_null("TitleReturnController") if get_parent() != null else null
	if returner != null and returner.has_method("ask_return_to_title"):
		returner.ask_return_to_title()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.build()   # a CanvasLayer does not pass Main's theme down
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.12, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ScenarioPanel"
	panel.theme_type_variation = &"Card"
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Label.new()
	_title.name = "ScenarioTitle"
	_title.theme_type_variation = &"WindowTitle"
	_title.add_theme_font_size_override("font_size", 26)
	col.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_art = TextureRect.new()
	_art.name = "ScenarioArt"
	_art.custom_minimum_size = ART_SIZE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_art)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	row.add_child(text)
	_line = Label.new()
	_line.theme_type_variation = &"AccentLabel"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = PANEL_WIDTH - ART_SIZE.x - 64
	text.add_child(_line)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = PANEL_WIDTH - ART_SIZE.x - 64
	text.add_child(_body)
	_goals = Label.new()
	_goals.name = "ScenarioGoals"
	_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_goals)
	_note = Label.new()
	_note.theme_type_variation = &"MutedLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_to_title = Button.new()
	_to_title.name = "ScenarioToTitle"
	_to_title.text = "タイトルへ"
	_to_title.custom_minimum_size = Vector2(160, 48)
	_to_title.pressed.connect(_on_to_title)
	buttons.add_child(_to_title)
	_ok = Button.new()
	_ok.name = "ScenarioOk"
	_ok.theme_type_variation = &"PrimaryButton"
	_ok.custom_minimum_size = Vector2(200, 48)
	_ok.pressed.connect(close)
	buttons.add_child(_ok)
