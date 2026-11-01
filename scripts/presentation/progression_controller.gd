class_name ProgressionController
extends Node
## "はじめかた" section of the inspector: tutorial card with skip / show again, today's challenge,
## milestone progress and the latest notices. It shows what ProgressionService decided; it never
## judges progress itself. Hiding the tutorial only flips `tutorial_skipped` (a Domain command),
## so progress and notices are never lost. The assistant's lines are not in the card: she stands at the
## bottom left of the screen (on the summary strip), over the store and any open window, and speaks in a bubble (mockup 2026-10-30).
## When a title or a daily challenge is achieved she cheers first (目標達成！ with the badge, a small hop); the
## celebration is presentation only: the badge is the whole reward, and each achievement event is shown once.

const NOTICE_LINES := 5
const ASSISTANT_NAME := "小春六花"   # the manager assistant character (user's choice, 2026-10-30)
# Her standing figure per mood: ComfyUI renders (tools/assets/comfy_rikka.py) cut out by tools/assets/cutout_rikka_stand.py.
const FIGURES := {
	"normal": "res://assets/ui/characters/rikka_normal.png",
	"happy": "res://assets/ui/characters/rikka_happy.png",      # a celebration, a good day
	"worried": "res://assets/ui/characters/rikka_worried.png",  # a loss, a day without a sale
	"point": "res://assets/ui/characters/rikka_point.png",      # explaining: the story and tutorial lines
	"welcome": "res://assets/ui/characters/rikka_welcome.png",  # her first greeting (story_start)
}
const FIGURE_SIZE := Vector2(300, 436)   # keeps the art's 640:931 aspect
const Layout := preload("res://scripts/presentation/main_layout.gd")
const BUBBLE_WIDTH := 420
const CELEBRATE_HEADING := "★ 目標達成！ ★"
const CELEBRATE_SECONDS := 8.0   # a celebration closes itself so it never keeps covering the store
const BLOCKED_LINE := "大変です、店長…！費用が払えなくて、お店が止まってしまいました。セーブからやり直しましょう。"
const CUTIN_WORD := "開店！"
const CUTIN_LINE := "今日もよろしくお願いします、店長！"
const CUTIN_BAND := 200.0
const CUTIN_SECONDS := 1.6
const MISSION_ROWS := 4   # today's challenge + the three titles closest to done

var _app: Node
var _card: Label
var _challenge: Label
var _milestones: Label
var _notices: Label
var _toggle: Button
var _assistant: Label          # her current line, inside the bubble
var _stage: Control            # full-screen layer on Main: the standing figure and the bubble; takes no clicks itself
var _bubble: PanelContainer
var _dismiss: Button
var _heading: Label            # 目標達成！ while celebrating, hidden otherwise
var _figure: TextureRect
var _pilot_figure: TextureRect
var _figure_textures: Dictionary = {}   # mood -> Texture2D
var _day_mood := "normal"      # her face for the day-end remark
var _blocked_closed := false
var _last_business := ""       # business_state of the last snapshot ("" before the first)
var _cutin: Control            # 開店！: a band across the screen with her happy figure, played when the store opens   # 閉じる on her payment-stop line (until the store runs again)
var _celebrations: Array[Dictionary] = []   # queued {badge, line}; the first one is on screen
var _celebrate_timer: Timer
var _suppressed_by := {}       # why the corner figure steps aside: "window" (management window open, its left edge
                               # would sit under her bubble), "kuji" (限定くじ管理, she is on that screen)
var _day_remark := ""          # her remark on the closed day while the day-end card is open ("" otherwise)
var _achievements: Label
var _missions: VBoxContainer   # 本日のミッション: today's challenge and the nearest titles, each with a bar
var _mission_rows: Array = []  # per row: {box, caption, goal, bar, count, chip}
var _history: Array[String] = []
var _snap: Dictionary = {}
var _pilot_cue_id := ""
var _pilot_cue_payload: Dictionary = {}
var _pilot_cue_timer: Timer
var _seq: int = 0
var _milestone_defs: Array = []

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node, milestones: Array) -> void:
	_app = app
	_milestone_defs = milestones
	var title := Label.new()
	title.text = "はじめかた・目標"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_card = Label.new()
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toggle = Button.new()
	_toggle.pressed.connect(toggle_tutorial)
	_challenge = Label.new()
	_challenge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_milestones = Label.new()
	_milestones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notices = Label.new()
	_notices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_achievements = Label.new()
	_achievements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_missions = VBoxContainer.new()
	_missions.name = "Missions"
	_missions.add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "本日のミッション"
	heading.theme_type_variation = &"CardTitle"
	_missions.add_child(heading)
	for i in MISSION_ROWS:
		_mission_rows.append(_build_mission_row())
	for c in [_card, _toggle, _challenge, _missions, _milestones, _notices, _achievements]:
		_body.add_child(c)
	_build_stage()
	# Added after Main has built its management window, so she stands in front of it.
	get_parent().add_child.call_deferred(_stage)
	_watch_window.call_deferred()
	_build_cutin()
	get_parent().add_child.call_deferred(_cutin)
	_pilot_cue_timer = Timer.new()
	_pilot_cue_timer.one_shot = true
	_pilot_cue_timer.timeout.connect(_clear_pilot_cue)
	add_child(_pilot_cue_timer)
	_connect_pilot_cue.call_deferred()
	apply_snapshot({"progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "completed_milestone_ids": [], "active_daily_challenge_id": null}})


func _connect_pilot_cue() -> void:
	var player := get_parent().get_node_or_null("CuePlayer")
	if player != null and player.has_signal("pilot_cue_requested"):
		var callback := Callable(self, "_on_pilot_cue")
		if not player.is_connected("pilot_cue_requested", callback):
			player.connect("pilot_cue_requested", callback)


func _on_pilot_cue(cue_id: String, payload: Dictionary) -> void:
	if not ["low_stock_notice", "expiry_notice", "long_queue", "access_blocked", "empty_handed", "rival_opened", "capsule_rare", "capsule_empty"].has(cue_id):
		return
	_pilot_cue_id = cue_id
	_pilot_cue_payload = payload.duplicate()
	_pilot_cue_timer.start(2.5)
	_refresh_stage()


func _clear_pilot_cue() -> void:
	_pilot_cue_id = ""
	_pilot_cue_payload = {}
	_refresh_stage()


func apply_snapshot(snap: Dictionary) -> void:
	var state := String(snap.get("business_state", ""))
	if _last_business == String(GameState.SETUP) and state == String(GameState.OPEN):
		show_opening()   # the player just opened the store (never on a load: the first snapshot only sets _last_business)
	if state != "":
		_last_business = state
	_snap = snap
	var p: Dictionary = snap["progression"]
	var skipped: bool = p["tutorial_skipped"]
	_card.text = "チュートリアルは非表示です（進み具合は保存されています）" if skipped else ProgressionText.step_text(int(p["tutorial_step_index"]))
	_toggle.text = "チュートリアルを再表示" if skipped else "チュートリアルをスキップ"
	_challenge.text = ProgressionText.challenge_text(p["active_daily_challenge_id"])
	var done: int = p["completed_milestone_ids"].size()
	_milestones.text = "称号 %d/%d（店のレベル %d）" % [done, maxi(_milestone_defs.size(), done), done]
	_notices.text = "\n".join(_history.slice(maxi(_history.size() - NOTICE_LINES, 0)))
	var challenge: Dictionary = snap.get("challenge_progress", {})
	_challenge.visible = challenge.is_empty()   # a day with a challenge shows it as the first mission row instead
	_render_missions(ProgressionText.mission_rows(challenge, snap.get("milestone_progress", [])))
	_refresh_stage()
	var lines: Array[String] = []
	for entry in snap.get("milestone_progress", []):
		lines.append(ProgressionText.progress_line(entry))
	_achievements.text = "実績一覧\n" + "\n".join(lines) if not lines.is_empty() else ""


func _build_mission_row() -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var caption := Label.new()
	caption.add_theme_color_override("font_color", UiTheme.WARM)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := Label.new()
	head.add_child(caption)
	head.add_child(chip)
	box.add_child(head)
	var goal := Label.new()
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(goal)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size.y = UiTheme.BAR_HEIGHT
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count := Label.new()
	line.add_child(bar)
	line.add_child(count)
	box.add_child(line)
	_missions.add_child(box)
	return {"box": box, "caption": caption, "goal": goal, "bar": bar, "count": count, "chip": chip}


func _render_missions(rows: Array[Dictionary]) -> void:
	for i in _mission_rows.size():
		var view: Dictionary = _mission_rows[i]
		(view["box"] as Control).visible = i < rows.size()
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		view["caption"].text = r["caption"]
		view["goal"].text = r["goal"]
		view["bar"].value = float(r["value"]) / maxf(float(r["goal_value"]), 1.0)
		view["count"].text = "%d / %d" % [int(r["value"]), int(r["goal_value"])]
		view["chip"].text = "達成" if r["done"] else "進行中"
		view["chip"].add_theme_color_override("font_color", UiTheme.SUCCESS_GREEN if r["done"] else UiTheme.TEXT_SECONDARY)


## Celebration first, then her day-end remark, then the story line; nothing to say hides her.
func _refresh_stage() -> void:
	if _stage == null:
		return
	var cue := String(_snap.get("story_cue", ""))
	var celebrating := not _celebrations.is_empty()
	var blocked := String(_snap.get("business_state", "")) == String(GameState.PAYMENT_BLOCKED)
	if not blocked:
		_blocked_closed = false
	var warn := blocked and not _blocked_closed
	_heading.visible = celebrating and not warn
	if warn:   # the store stopped for unpaid costs: she says so first, worried (the panel has the details)
		_assistant.text = BLOCKED_LINE
	elif celebrating:
		_assistant.text = String(_celebrations[0]["line"])
	elif _day_remark != "":
		_assistant.text = _day_remark
	elif cue != "":
		_assistant.text = ProgressionText.assistant_text(cue) if cue != "" else ""
	else:
		_assistant.text = CueText.toast_text(_pilot_cue_id, _pilot_cue_payload)
	_stage.visible = _suppressed_by.is_empty() and (warn or celebrating or _day_remark != "" or cue != "" or _pilot_cue_id != "")
	if warn:
		set_mood("worried")
	else:
		set_mood("happy" if celebrating else (_day_mood if _day_remark != "" else story_mood(cue)))
	refresh_visual_pilot()


## Her face for a story line: a bow for the first greeting, explaining for the rest.
static func story_mood(cue: String) -> String:
	if cue == "":
		return "normal"
	return "welcome" if cue == "story_start" else "point"


## Her face: "normal", "happy" or "worried" (FIGURES).
func set_mood(mood: String) -> void:
	if _figure != null and _figure_textures.has(mood):
		_figure.texture = _figure_textures[mood]


## Shows a selected Issue #230 pilot sprite in the real assistant stage when enabled in the inspector.
## The legacy mood figure remains the fallback whenever the pilot registry, texture, or toggle is unavailable.
func refresh_visual_pilot() -> void:
	if _pilot_figure == null:
		return
	var pilot := get_node_or_null("../CharacterVisualPilotPanel")
	var enabled: bool = pilot != null and pilot.has_method("is_pilot_enabled") and pilot.is_pilot_enabled()
	var entry: Dictionary = {}
	if enabled:
		if _pilot_cue_id != "" and pilot.has_method("cue_entry"):
			entry = pilot.cue_entry(_pilot_cue_id)
		elif _day_remark != "" and pilot.has_method("day_end_entry"):
			entry = pilot.day_end_entry(_day_mood)
		else:
			entry = pilot.stage_entry(_snap)
	var texture: Texture2D = load(String(entry.get("runtime_path", ""))) as Texture2D if not entry.is_empty() else null
	var usable: bool = enabled and texture != null
	_pilot_figure.visible = usable
	_pilot_figure.texture = texture if usable else null
	if _figure != null:
		_figure.visible = not usable


func mood() -> String:
	for k in _figure_textures:
		if _figure != null and _figure.texture == _figure_textures[k]:
			return k
	return ""


func is_celebrating() -> bool:
	return not _celebrations.is_empty()


## 閉じる (or the timer) ends the current celebration; the next queued one, or the story line, follows.
func close_celebration() -> void:
	if _celebrations.is_empty():
		return
	_celebrations.pop_front()
	_start_celebration()
	_refresh_stage()


## The day-end card opened (ReportController): she comments on the day until it closes.
func say_day_end(remark: String, day_mood: String = "normal") -> void:
	_day_remark = remark
	_day_mood = day_mood
	_refresh_stage()


## 開店！ cut-in: a warm band across the middle of the screen with the word and her happy figure, sliding in and out over
## about two seconds. Presentation only; it takes no clicks.
func _build_cutin() -> void:
	_cutin = Control.new()
	_cutin.name = "OpeningCutin"
	_cutin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cutin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.visible = false
	var band := ColorRect.new()
	band.name = "Band"
	band.color = Color(0.09, 0.16, 0.27, 0.86)
	band.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	band.anchor_right = 1.0
	band.offset_top = -CUTIN_BAND / 2.0
	band.offset_bottom = CUTIN_BAND / 2.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(band)
	var edge := ColorRect.new()   # thin warm lines above and below the band
	edge.color = UiTheme.WARM
	edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edge.offset_bottom = 4
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(edge)
	var edge2 := edge.duplicate() as ColorRect
	edge2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	edge2.offset_top = -4
	edge2.offset_bottom = 0
	band.add_child(edge2)
	var word := Label.new()
	word.name = "Word"
	word.text = CUTIN_WORD
	word.add_theme_font_size_override("font_size", 84)
	word.add_theme_color_override("font_color", UiTheme.WARM)
	word.add_theme_color_override("font_outline_color", Color("0b1a2b"))
	word.add_theme_constant_override("outline_size", 12)
	word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(word)
	var sub := Label.new()
	sub.text = CUTIN_LINE
	sub.add_theme_font_size_override("font_size", 22)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_top = -44
	sub.offset_bottom = -12
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(sub)
	var face := TextureRect.new()
	face.name = "Rikka"
	face.texture = load(FIGURES["happy"]) as Texture2D
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	face.offset_left = -FIGURE_SIZE.x - 160
	face.offset_right = -160
	face.offset_top = -FIGURE_SIZE.y / 2.0 - 30
	face.offset_bottom = FIGURE_SIZE.y / 2.0 - 30
	_cutin.add_child(face)


func show_opening() -> void:
	if _cutin == null:
		return
	var pilot := get_parent().get_node_or_null("CharacterVisualPilotPanel")
	if pilot != null and pilot.has_method("cue_entry") and pilot.has_method("is_pilot_enabled") and pilot.is_pilot_enabled():
		var opening: Dictionary = pilot.cue_entry("business_started")
		var texture := load(String(opening.get("runtime_path", ""))) as Texture2D
		if texture != null:
			(_cutin.get_node("Rikka") as TextureRect).texture = texture
	_cutin.visible = true
	_cutin.modulate = Color(1, 1, 1, 0)
	if not _cutin.is_inside_tree():
		return   # tests without a tree: visible is enough
	var tw := _cutin.create_tween()
	tw.tween_property(_cutin, "modulate:a", 1.0, 0.25)
	tw.tween_interval(CUTIN_SECONDS)
	tw.tween_property(_cutin, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _cutin.visible = false)


## She steps aside while the management window is open (user's choice, 2026-10-31).
func _watch_window() -> void:
	var window := get_parent().get_node_or_null("ManagementWindow") as Control
	if window == null:
		return
	window.visibility_changed.connect(func(): set_suppressed(window.visible, "window"))
	set_suppressed(window.visible, "window")
	# The build catalog stands at the left edge, where her bubble is (screen audit 2026-11-01): she steps aside there too.
	var palette := get_parent().get_node_or_null("Layout/MainArea/BuildPalette") as Control
	if palette != null:
		palette.visibility_changed.connect(func(): set_suppressed(palette.is_visible_in_tree(), "build"))
		set_suppressed(palette.is_visible_in_tree(), "build")


## The area map (#150) is a window of its own: BusinessController reports when it opens and closes.
func set_map_open(on: bool) -> void:
	set_suppressed(on, "map")


func set_suppressed(on: bool, reason: String = "screen") -> void:
	if on:
		_suppressed_by[reason] = true
	else:
		_suppressed_by.erase(reason)
	_refresh_stage()


func end_day_end() -> void:
	_day_remark = ""
	_refresh_stage()


func _on_dismiss_pressed() -> void:
	if _assistant.text == BLOCKED_LINE:
		_blocked_closed = true
		_refresh_stage()
	elif is_celebrating():
		close_celebration()
	elif _day_remark != "":
		end_day_end()
	else:
		dismiss_cue()


func _start_celebration() -> void:
	if _celebrations.is_empty() or _celebrate_timer == null:
		return
	if _celebrate_timer.is_inside_tree():
		_celebrate_timer.start()
	if _figure != null and _figure.is_inside_tree():   # a little hop for joy
		var base := -Layout.BOTTOM_HEIGHT
		var hop := _figure.create_tween()
		for i in 2:
			hop.tween_property(_figure, "offset_bottom", base - 18.0, 0.12).set_ease(Tween.EASE_OUT)
			hop.parallel().tween_property(_figure, "offset_top", base - FIGURE_SIZE.y - 18.0, 0.12).set_ease(Tween.EASE_OUT)
			hop.tween_property(_figure, "offset_bottom", base, 0.14).set_ease(Tween.EASE_IN)
			hop.parallel().tween_property(_figure, "offset_top", base - FIGURE_SIZE.y, 0.14).set_ease(Tween.EASE_IN)


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "AssistantStage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var figure := TextureRect.new()
	figure.name = "AssistantFigure"
	for k in FIGURES:
		_figure_textures[k] = load(FIGURES[k]) as Texture2D
	figure.texture = _figure_textures["normal"]
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the rail and the store under her stay clickable
	figure.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	figure.offset_left = 0
	figure.offset_right = FIGURE_SIZE.x
	figure.offset_top = -FIGURE_SIZE.y - Layout.BOTTOM_HEIGHT   # she stands on the summary strip, not over its cards
	figure.offset_bottom = -Layout.BOTTOM_HEIGHT
	_stage.add_child(figure)
	_figure = figure
	var pilot_figure := TextureRect.new()
	pilot_figure.name = "AssistantPilotFigure"
	pilot_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pilot_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	pilot_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_figure.visible = false
	pilot_figure.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pilot_figure.offset_left = 0
	pilot_figure.offset_right = FIGURE_SIZE.x
	pilot_figure.offset_top = -FIGURE_SIZE.y - Layout.BOTTOM_HEIGHT
	pilot_figure.offset_bottom = -Layout.BOTTOM_HEIGHT
	_stage.add_child(pilot_figure)
	_pilot_figure = pilot_figure
	_celebrate_timer = Timer.new()
	_celebrate_timer.one_shot = true
	_celebrate_timer.wait_time = CELEBRATE_SECONDS
	_celebrate_timer.timeout.connect(close_celebration)
	_stage.add_child(_celebrate_timer)
	_bubble = PanelContainer.new()
	_bubble.name = "AssistantBubble"
	_bubble.theme_type_variation = &"Card"
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bubble.offset_left = FIGURE_SIZE.x - 40          # beside her head, slightly over her shoulder
	_bubble.offset_right = FIGURE_SIZE.x - 40 + BUBBLE_WIDTH
	_bubble.offset_top = -FIGURE_SIZE.y - Layout.BOTTOM_HEIGHT + 40
	_bubble.offset_bottom = _bubble.offset_top
	_bubble.grow_vertical = Control.GROW_DIRECTION_END
	_stage.add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_bubble.add_child(column)
	var name_label := Label.new()
	name_label.name = "AssistantName"
	name_label.text = "%s（店長アシスタント）" % ASSISTANT_NAME
	name_label.add_theme_color_override("font_color", UiTheme.WARM)
	name_label.add_theme_font_size_override("font_size", 18)
	column.add_child(name_label)
	_heading = Label.new()
	_heading.name = "CelebrateHeading"
	_heading.text = CELEBRATE_HEADING
	_heading.add_theme_color_override("font_color", UiTheme.WARM)
	_heading.add_theme_font_size_override("font_size", 30)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.visible = false
	column.add_child(_heading)
	_assistant = Label.new()
	_assistant.name = "AssistantLine"
	_assistant.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assistant.custom_minimum_size.x = BUBBLE_WIDTH - 40
	_assistant.add_theme_font_size_override("font_size", 17)
	column.add_child(_assistant)
	_dismiss = Button.new()
	_dismiss.name = "AssistantDismiss"
	_dismiss.text = "閉じる"
	_dismiss.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dismiss.pressed.connect(_on_dismiss_pressed)
	column.add_child(_dismiss)
	# The bubble's tail points left, at her face.
	var tail := Polygon2D.new()
	tail.name = "BubbleTail"
	tail.polygon = PackedVector2Array([Vector2(0, 30), Vector2(-22, 52), Vector2(0, 62)])
	tail.color = UiTheme.CARD_TOP.lerp(UiTheme.CARD_BOTTOM, 0.2)   # the card's gradient near the top, where the tail sits
	_bubble.add_child(tail)


## Called by AppRoot with the achievements that happened since the last snapshot.
func show_events(events: Array) -> void:
	for e in events:
		var line := ProgressionText.notice(e, _milestone_defs)
		if line != "":
			_history.append(line)
		var cheer := ProgressionText.celebration(e, _milestone_defs)
		if cheer != "":
			_celebrations.append({"kind": String(e["kind"]), "line": cheer})
			if _celebrations.size() == 1:
				_start_celebration()
	if not events.is_empty() and not _snap.is_empty():
		apply_snapshot(_snap)
	else:
		_refresh_stage()


func dismiss_cue() -> CommandResult:
	_seq += 1
	return _app.run_command({"command_id": "ui_cue_%d" % _seq, "kind": &"DISMISS_STORY_CUE", "cue_id": String(_snap.get("story_cue", ""))})


func toggle_tutorial() -> CommandResult:
	_seq += 1
	var skipped: bool = _snap.get("progression", {}).get("tutorial_skipped", false)
	return _app.run_command({"command_id": "ui_tutorial_%d" % _seq, "kind": &"SET_TUTORIAL_SKIPPED", "skipped": not skipped})
