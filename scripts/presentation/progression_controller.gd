class_name ProgressionController
extends Node
## "はじめかた" section of the inspector: tutorial card with skip / show again, today's challenge,
## milestone progress and the latest notices. It shows what ProgressionService decided; it never
## judges progress itself. Hiding the tutorial only flips `tutorial_skipped` (a Domain command),
## so progress and notices are never lost. The assistant's lines are not in the card: she stands at the
## above the bottom chrome at the left edge of the screen, over the store and any open window, and speaks in a bubble (mockup 2026-10-30).
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
const PILOT_BUSTUP_FRAME_SIZE := Vector2(FIGURE_SIZE.x, 300.0)
const Layout := preload("res://scripts/presentation/main_layout.gd")
const BUBBLE_WIDTH := 420
# Bottom-left corner (user's request 2026-11-14: she covered the left menu): she stands on the bottom bar's top edge,
# shown from the waist up, so her head stays under the menu's last button. Source PNGs are never modified.
const ASSISTANT_LEFT := 10.0
## The bust-up frame's bottom edge: the top of the bottom bar.
const ASSISTANT_BOTTOM := float(Layout.CHROME_BOTTOM)
## Room above the full figure inside its crop, so her little hop is not cut.
const FIGURE_HEADROOM := 24.0
const BUBBLE_BOTTOM := Layout.CHROME_BOTTOM + 12.0
# Keep the line panel aligned with the portrait's lower-left presentation area,
# leaving the character face unobstructed and placing the dialogue a little lower.
const BUBBLE_TOP_DROP := 92.0
## The speech bubble's colours (mockup styles.css .speech: #fffaf3 / #e2b798 / #34222a, and the pink name tab).
const BUBBLE_FILL := Color("fff8ec")
const BUBBLE_BORDER := Color("e2b798")
const BUBBLE_TEXT := Color("34222a")
const BUBBLE_TAB := Color("e98aa4")
const BUBBLE_ACCENT := Color("e2563f")
const CELEBRATE_HEADING := "★ 目標達成！ ★"
const RANK_HEADING := "★ ランクアップ！ ★"
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
var _pilot_reaction: TextureRect
var _pilot_reaction_symbol: Label
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
var _rank: Label               # 店舗ランク and what the next rank needs
var _scenario: Label           # the scenario in play: days left and its goals (ScenarioText.panel_text)
var _scenario_dialog: ScenarioDialog
var _missions: VBoxContainer   # 本日のミッション: today's challenge and the nearest titles, each with a bar
var _mission_rows: Array = []  # per row: {box, caption, goal, bar, count, chip}
var _history: Array[String] = []
var _snap: Dictionary = {}
var _pilot_cue_id := ""
var _pilot_cue_payload: Dictionary = {}
var _pilot_cue_timer: Timer
var _capture_story_cue_override := ""   # visual-QA capture only; never written to GameState
var _opening_cutin_active := false
var _reactions: RikkaReactions   # her live reactions to gameplay cues (data/presentation/rikka_reactions_v1.json)
var _live: Dictionary = {}       # the reaction on screen {cue_id, image, line}, {} when none
var _live_timer: Timer
var _seq: int = 0
var _milestone_defs: Array = []

const PILOT_SCREEN_CUES := [
	"opening_checklist", "low_stock_notice", "expiry_notice",
	"long_queue", "access_blocked", "empty_handed", "rival_opened", "capsule_rare", "capsule_empty",
	"order_help", "restock_help", "staff_schedule_open",
	"save_complete", "staff_hired", "seasonal_campaign_started", "layout_help"
]

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func setup(app: Node, milestones: Array) -> void:
	_app = app
	_milestone_defs = milestones
	var title := Label.new()
	title.text = "はじめかた・目標"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_scenario = Label.new()
	_scenario.name = "ScenarioGoal"
	_scenario.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario.theme_type_variation = &"AccentLabel"
	_scenario.visible = false
	_body.add_child(_scenario)
	_scenario_dialog = ScenarioDialog.new()
	_scenario_dialog.setup(app)
	get_parent().add_child.call_deferred(_scenario_dialog)
	_rank = Label.new()
	_rank.name = "StoreRank"
	_rank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rank.theme_type_variation = &"AccentLabel"
	_body.add_child(_rank)
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
	_reactions = RikkaReactions.load_default()
	_live_timer = Timer.new()
	_live_timer.one_shot = true
	_live_timer.timeout.connect(_clear_live_reaction)
	add_child(_live_timer)
	add_child(_pilot_cue_timer)
	_connect_pilot_cue.call_deferred()
	apply_snapshot({"progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "completed_milestone_ids": [], "active_daily_challenge_id": null}})


func _connect_pilot_cue() -> void:
	var player := get_parent().get_node_or_null("CuePlayer")
	if player != null and player.has_signal("pilot_cue_requested"):
		var callback := Callable(self, "_on_pilot_cue")
		if not player.is_connected("pilot_cue_requested", callback):
			player.connect("pilot_cue_requested", callback)


func request_pilot_cue(cue_id: String, payload: Dictionary = {}) -> void:
	## Lets sibling UI controllers announce a successful presentation event without
	## coupling them to CuePlayer's gameplay notification signal.
	_on_pilot_cue(cue_id, payload)


func _on_pilot_cue(cue_id: String, payload: Dictionary) -> void:
	if react(cue_id, Time.get_ticks_msec() / 1000.0):
		return
	if not ["opening_checklist", "low_stock_notice", "expiry_notice", "long_queue", "access_blocked", "empty_handed", "rival_opened", "capsule_rare", "capsule_empty", "order_help", "restock_help", "staff_schedule_open", "save_complete", "staff_hired", "seasonal_campaign_started", "layout_help"].has(cue_id):
		return
	# A newer notice replaces her reaction (a reaction cooling down falls back to this pose and the factual line).
	if not _live.is_empty():
		if _live_timer != null:
			_live_timer.stop()
		_live = {}
	_pilot_cue_id = cue_id
	_pilot_cue_payload = payload.duplicate()
	_pilot_cue_timer.start(2.5)
	_refresh_stage()


## Her live reaction to a gameplay cue: a bust-up face and one line for a few seconds. She stays quiet while she has
## something more important to say (a celebration, the payment stop, the day-end remark, the opening) or a window
## is open; such a cue is skipped without starting its cooldown. Returns true when she reacted.
func react(cue_id: String, now: float) -> bool:
	if _reactions == null or not _reactions.handles(cue_id) or not can_react():
		return false
	var picked := _reactions.pick(cue_id, now)
	if picked.is_empty():
		return false
	_live = picked
	if _live_timer != null and _live_timer.is_inside_tree():
		_live_timer.start(_reactions.show_seconds)
	_refresh_stage()
	return true


func can_react() -> bool:
	return _celebrations.is_empty() and _day_remark == "" and not _opening_cutin_active and _suppressed_by.is_empty() \
		and String(_snap.get("business_state", "")) != String(GameState.PAYMENT_BLOCKED)


## A line of her own with a reaction face, e.g. after the player picked an event choice (EventChoiceDialog).
func say(line: String, image: String, symbol: String = "") -> void:
	_live = {"cue_id": "say", "image": image, "line": line, "symbol": symbol}
	if _live_timer != null and _live_timer.is_inside_tree():
		_live_timer.start(_reactions.show_seconds + 1.0 if _reactions != null else 5.0)
	_refresh_stage()


func scenario_dialog() -> ScenarioDialog:
	return _scenario_dialog


func live_reaction() -> Dictionary:
	return _live


func _clear_live_reaction() -> void:
	_live = {}
	_refresh_stage()


func _clear_pilot_cue() -> void:
	_pilot_cue_id = ""
	_pilot_cue_payload = {}
	_refresh_stage()


func clear_pilot_cue() -> void:
	"""End a screen-scoped pilot cue when its owning management screen closes."""
	if _pilot_cue_timer != null:
		_pilot_cue_timer.stop()
	_clear_pilot_cue()


func apply_snapshot(snap: Dictionary) -> void:
	if _capture_story_cue_override != "":
		snap = snap.duplicate(true)
		snap["story_cue"] = _capture_story_cue_override
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
	_rank.text = rank_text(snap.get("store_rank", {}))
	_rank.visible = not _rank.text.is_empty()
	_scenario.text = ScenarioText.panel_text(snap.get("scenario", {}))
	_scenario.visible = not _scenario.text.is_empty()
	_scenario_dialog.offer_intro(snap)
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


func set_capture_story_cue(cue: String) -> void:
	## Capture-only presentation override. It keeps a requested story image visible while the real state continues
	## to publish snapshots during the deterministic screenshot setup.
	_capture_story_cue_override = cue
	if not _snap.is_empty():
		var snapshot := _snap.duplicate(true)
		snapshot["story_cue"] = cue
		apply_snapshot(snapshot)


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
	if celebrating:
		_heading.text = RANK_HEADING if String(_celebrations[0].get("kind", "")) == "RANK_UP" else CELEBRATE_HEADING
	if warn:   # the store stopped for unpaid costs: she says so first, worried (the panel has the details)
		_assistant.text = BLOCKED_LINE
	elif celebrating:
		_assistant.text = String(_celebrations[0]["line"])
	elif _day_remark != "":
		_assistant.text = _day_remark
	elif not _live.is_empty():
		_assistant.text = String(_live["line"])
	elif cue != "":
		_assistant.text = ProgressionText.assistant_text(cue) if cue != "" else ""
	else:
		_assistant.text = CueText.toast_text(_pilot_cue_id, _pilot_cue_payload)
	var pilot_screen_overlay := PILOT_SCREEN_CUES.has(_pilot_cue_id)
	# An event-management pilot is the owning presentation layer. It must hide the
	# persistent assistant even when opening a management tab also queued a short
	# screen cue such as opening_checklist.
	var event_pilot_suppressed := _suppressed_by.has("event_pilot")
	var build_suppressed := _suppressed_by.has("build")
	_stage.visible = not event_pilot_suppressed and not build_suppressed and (_suppressed_by.is_empty() or pilot_screen_overlay) and (warn or celebrating or _day_remark != "" or not _live.is_empty() or cue != "" or _pilot_cue_id != "")
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
	var review_candidate: Dictionary = pilot.review_candidate_entry() if enabled and pilot != null and pilot.has_method("review_candidate_entry") else {}
	var review_candidate_active := not review_candidate.is_empty()
	var entry: Dictionary = {}
	var reaction_entry: Dictionary = {}
	# A live reaction is her own presentation, not a pilot route: it shows whether or not the pilot is enabled, but a
	# celebration, the payment stop and the day-end remark keep their own figure.
	var live := not _live.is_empty() and _celebrations.is_empty() and _day_remark == "" and not review_candidate_active
	if live:
		reaction_entry = {"runtime_path": String(_live["image"]), "overlay_symbol": String(_live.get("symbol", ""))}   # the cutout drops drawn symbols
	elif enabled:
		if not review_candidate.is_empty():
			if String(review_candidate.get("kind", "")) == "bustup_reaction":
				reaction_entry = review_candidate
			else:
				entry = review_candidate
		elif _pilot_cue_id != "" and pilot.has_method("cue_entry"):
			entry = pilot.cue_entry(_pilot_cue_id)
		elif _day_remark != "" and pilot.has_method("day_end_entry"):
			entry = pilot.day_end_entry(_day_mood)
		else:
			entry = pilot.stage_entry(_snap)
			if pilot.has_method("reaction_entry"):
				reaction_entry = pilot.reaction_entry(_snap)
	var texture: Texture2D = load(String(entry.get("runtime_path", ""))) as Texture2D if not entry.is_empty() else null
	var reaction_texture: Texture2D = load(String(reaction_entry.get("runtime_path", ""))) as Texture2D if not reaction_entry.is_empty() else null
	var usable: bool = enabled and texture != null
	var reaction_usable: bool = (enabled or live) and reaction_texture != null
	_pilot_figure.visible = usable and not reaction_usable
	_pilot_figure.texture = texture if usable else null
	if _pilot_reaction != null:
		_pilot_reaction.visible = reaction_usable
		_pilot_reaction.texture = reaction_texture if reaction_usable else null
	if _pilot_reaction_symbol != null:
		_pilot_reaction_symbol.text = String(reaction_entry.get("overlay_symbol", "")) if reaction_usable else ""
		_pilot_reaction_symbol.visible = reaction_usable and not _pilot_reaction_symbol.text.is_empty()
	if _figure != null:
		_figure.visible = not usable and not reaction_usable
	if review_candidate_active and not _suppressed_by.has("event_pilot") and not _suppressed_by.has("build") and not _opening_cutin_active:
		_stage.visible = true
	if _opening_cutin_active:
		# The opening cut-in owns the character layer for its whole animation.
		# Keep both the generated pilot stage and the legacy fallback out of the frame.
		_stage.visible = false
	if PILOT_SCREEN_CUES.has(_pilot_cue_id) and not _suppressed_by.has("event_pilot") and not _suppressed_by.has("build") and not _opening_cutin_active and (usable or reaction_usable):
		# A screen-scoped pilot cue is allowed to remain above the management window.
		# Reassert this after snapshot/window callbacks so the parent presentation node
		# cannot accidentally hide an explicitly requested visual route.
		_stage.visible = true
	var chrome := get_node_or_null("../MockupChrome")
	if chrome != null and chrome.has_method("set_pilot_assistant_visible"):
		var event_pilot_owns_assistant := _suppressed_by.has("event_pilot")
		chrome.set_pilot_assistant_visible(event_pilot_owns_assistant or _opening_cutin_active or (_stage.visible and (usable or reaction_usable)))


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
	_opening_cutin_active = true
	var pilot := get_parent().get_node_or_null("CharacterVisualPilotPanel")
	if pilot != null and pilot.has_method("cue_entry") and pilot.has_method("is_pilot_enabled") and pilot.is_pilot_enabled():
		var opening: Dictionary = pilot.cue_entry("business_started")
		var texture := load(String(opening.get("runtime_path", ""))) as Texture2D
		if texture != null:
			(_cutin.get_node("Rikka") as TextureRect).texture = texture
	_cutin.visible = true
	_cutin.modulate = Color(1, 1, 1, 0)
	if not _cutin.is_inside_tree():
		_stage.visible = false
		return   # tests without a tree: visible is enough
	set_suppressed(true, "opening_cutin")
	var tw := _cutin.create_tween()
	tw.tween_property(_cutin, "modulate:a", 1.0, 0.25)
	tw.tween_interval(CUTIN_SECONDS)
	tw.tween_property(_cutin, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_finish_opening_cutin)


func _finish_opening_cutin() -> void:
	_opening_cutin_active = false
	_cutin.visible = false
	set_suppressed(false, "opening_cutin")


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
	elif not _live.is_empty():   # 閉じる on a live reaction closes only the reaction, never the story line under it
		if _live_timer != null:
			_live_timer.stop()
		_clear_live_reaction()
	else:
		dismiss_cue()


func _start_celebration() -> void:
	if _celebrations.is_empty() or _celebrate_timer == null:
		return
	if _celebrate_timer.is_inside_tree():
		_celebrate_timer.start()
	if _figure != null and _figure.is_inside_tree():   # a little hop for joy
		var base := FIGURE_HEADROOM   # her top inside the crop
		var hop := _figure.create_tween()
		for i in 2:
			hop.tween_property(_figure, "offset_top", base - 18.0, 0.12).set_ease(Tween.EASE_OUT)
			hop.parallel().tween_property(_figure, "offset_bottom", base + FIGURE_SIZE.y - 18.0, 0.12).set_ease(Tween.EASE_OUT)
			hop.tween_property(_figure, "offset_top", base, 0.14).set_ease(Tween.EASE_IN)
			hop.parallel().tween_property(_figure, "offset_bottom", base + FIGURE_SIZE.y, 0.14).set_ease(Tween.EASE_IN)


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "AssistantStage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var figure := TextureRect.new()
	figure.name = "AssistantFigure"
	for k in FIGURES:
		_figure_textures[k] = load(FIGURES[k]) as Texture2D
	figure.texture = _figure_textures["normal"]
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the rail and the store under her stay clickable
	# The fallback figure is shown waist up too, in its own crop that ends on the bottom bar.
	var figure_crop := Control.new()
	figure_crop.name = "AssistantFigureCrop"
	figure_crop.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	figure_crop.offset_left = ASSISTANT_LEFT
	figure_crop.offset_right = ASSISTANT_LEFT + FIGURE_SIZE.x
	figure_crop.offset_top = -PILOT_BUSTUP_FRAME_SIZE.y - FIGURE_HEADROOM - ASSISTANT_BOTTOM
	figure_crop.offset_bottom = -ASSISTANT_BOTTOM
	figure_crop.clip_contents = true
	figure_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(figure_crop)
	figure.set_anchors_preset(Control.PRESET_TOP_LEFT)
	figure.offset_left = 0.0
	figure.offset_right = FIGURE_SIZE.x
	figure.offset_top = FIGURE_HEADROOM
	figure.offset_bottom = FIGURE_HEADROOM + FIGURE_SIZE.y
	figure_crop.add_child(figure)
	_figure = figure
	# Generated pilot files remain full-body source assets.  The assistant slot on the
	# store screen is intentionally a bust-up window: clip the child at display time
	# so the original PNG stays reusable for event panels and future layouts.
	var pilot_crop := Control.new()
	pilot_crop.name = "AssistantPilotBustupCrop"
	pilot_crop.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pilot_crop.offset_left = ASSISTANT_LEFT
	pilot_crop.offset_right = ASSISTANT_LEFT + PILOT_BUSTUP_FRAME_SIZE.x
	pilot_crop.offset_top = -PILOT_BUSTUP_FRAME_SIZE.y - ASSISTANT_BOTTOM
	pilot_crop.offset_bottom = -ASSISTANT_BOTTOM
	pilot_crop.clip_contents = true
	pilot_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(pilot_crop)
	var pilot_figure := TextureRect.new()
	pilot_figure.name = "AssistantPilotFigure"
	pilot_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pilot_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	pilot_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_figure.visible = false
	pilot_figure.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pilot_figure.offset_left = 0.0
	pilot_figure.offset_right = FIGURE_SIZE.x
	pilot_figure.offset_top = 0.0
	pilot_figure.offset_bottom = FIGURE_SIZE.y
	pilot_crop.add_child(pilot_figure)
	_pilot_figure = pilot_figure
	var pilot_reaction := TextureRect.new()
	pilot_reaction.name = "AssistantPilotReaction"
	pilot_reaction.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pilot_reaction.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pilot_reaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_reaction.visible = false
	pilot_reaction.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pilot_reaction.offset_left = ASSISTANT_LEFT + 18
	pilot_reaction.offset_right = ASSISTANT_LEFT + 18 + 260
	pilot_reaction.offset_top = -ASSISTANT_BOTTOM - 260
	pilot_reaction.offset_bottom = -ASSISTANT_BOTTOM
	_stage.add_child(pilot_reaction)
	_pilot_reaction = pilot_reaction
	var pilot_reaction_symbol := Label.new()
	pilot_reaction_symbol.name = "AssistantPilotReactionSymbol"
	pilot_reaction_symbol.add_theme_font_size_override("font_size", 42)
	pilot_reaction_symbol.add_theme_color_override("font_color", UiTheme.WARM)
	pilot_reaction_symbol.add_theme_color_override("font_outline_color", Color("172333"))
	pilot_reaction_symbol.add_theme_constant_override("outline_size", 8)
	pilot_reaction_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pilot_reaction_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pilot_reaction_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_reaction_symbol.visible = false
	pilot_reaction_symbol.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Beside her head, left of the speech bubble (which starts at FIGURE_SIZE.x - 40): drawn under it, it was hidden.
	pilot_reaction_symbol.offset_left = ASSISTANT_LEFT + 176
	pilot_reaction_symbol.offset_right = ASSISTANT_LEFT + 252
	pilot_reaction_symbol.offset_top = -ASSISTANT_BOTTOM - 262
	pilot_reaction_symbol.offset_bottom = -ASSISTANT_BOTTOM - 202
	_stage.add_child(pilot_reaction_symbol)
	_pilot_reaction_symbol = pilot_reaction_symbol
	_celebrate_timer = Timer.new()
	_celebrate_timer.one_shot = true
	_celebrate_timer.wait_time = CELEBRATE_SECONDS
	_celebrate_timer.timeout.connect(close_celebration)
	_stage.add_child(_celebrate_timer)
	_bubble = PanelContainer.new()
	_bubble.name = "AssistantBubble"
	_bubble.add_theme_stylebox_override("panel", bubble_style())   # the mockup's cream speech bubble (styles.css .speech)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bubble.offset_left = ASSISTANT_LEFT + FIGURE_SIZE.x - 40          # beside her head, right of the left menu
	_bubble.offset_right = ASSISTANT_LEFT + FIGURE_SIZE.x - 40 + BUBBLE_WIDTH
	_bubble.offset_top = -FIGURE_SIZE.y - BUBBLE_BOTTOM + 40 + BUBBLE_TOP_DROP
	_bubble.offset_bottom = _bubble.offset_top
	_bubble.grow_vertical = Control.GROW_DIRECTION_END
	_stage.add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_bubble.add_child(column)
	# Her name on a pink tab, as in the mockup.
	var name_tab := PanelContainer.new()
	name_tab.name = "AssistantNameTab"
	name_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_tab.add_theme_stylebox_override("panel", _name_tab_style())
	column.add_child(name_tab)
	var name_label := Label.new()
	name_label.name = "AssistantName"
	name_label.text = "%s（店長アシスタント）" % ASSISTANT_NAME
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	name_tab.add_child(name_label)
	_heading = Label.new()
	_heading.name = "CelebrateHeading"
	_heading.text = CELEBRATE_HEADING
	_heading.add_theme_color_override("font_color", BUBBLE_ACCENT)
	_heading.add_theme_color_override("font_outline_color", Color.WHITE)
	_heading.add_theme_constant_override("outline_size", 6)
	_heading.add_theme_font_size_override("font_size", 30)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.visible = false
	column.add_child(_heading)
	_assistant = Label.new()
	_assistant.name = "AssistantLine"
	_assistant.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assistant.custom_minimum_size.x = BUBBLE_WIDTH - 40
	_assistant.add_theme_font_size_override("font_size", 18)
	_assistant.add_theme_color_override("font_color", BUBBLE_TEXT)
	_assistant.add_theme_constant_override("line_spacing", 4)
	column.add_child(_assistant)
	_dismiss = Button.new()
	_dismiss.name = "AssistantDismiss"
	_dismiss.text = "閉じる"
	_dismiss.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_dismiss(_dismiss)
	_dismiss.pressed.connect(_on_dismiss_pressed)
	column.add_child(_dismiss)
	# The bubble's tail points left, at her face: the border colour first, the cream fill over it.
	var tail_edge := Polygon2D.new()
	tail_edge.name = "BubbleTailEdge"
	tail_edge.polygon = PackedVector2Array([Vector2(3, 34), Vector2(-26, 58), Vector2(3, 72)])
	tail_edge.color = BUBBLE_BORDER
	_bubble.add_child(tail_edge)
	var tail := Polygon2D.new()
	tail.name = "BubbleTail"
	tail.polygon = PackedVector2Array([Vector2(4, 38), Vector2(-20, 58), Vector2(4, 68)])
	tail.color = BUBBLE_FILL
	_bubble.add_child(tail)


## The speech bubble: cream with a warm tan border and round corners, a soft shadow (mockup styles.css .speech).
static func bubble_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BUBBLE_FILL
	box.border_color = BUBBLE_BORDER
	box.set_border_width_all(3)
	box.corner_radius_top_left = 34
	box.corner_radius_top_right = 30
	box.corner_radius_bottom_left = 26
	box.corner_radius_bottom_right = 26
	box.corner_detail = 10
	box.shadow_color = Color(0.05, 0.03, 0.02, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 20
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func _name_tab_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BUBBLE_TAB
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	return box


## 閉じる: a small pill in the bubble's colours instead of the dark theme button.
static func _style_dismiss(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = BUBBLE_BORDER.lightened(0.35) if state == "normal" else BUBBLE_BORDER.lightened(0.15)
		box.border_color = BUBBLE_BORDER.darkened(0.15)
		box.set_border_width_all(2 if state != "focus" else 3)
		box.set_corner_radius_all(16)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 4
		box.content_margin_bottom = 5
		if state == "focus":
			box.bg_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, box)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, BUBBLE_TEXT)
	b.add_theme_font_size_override("font_size", 16)


## Called by AppRoot with the achievements that happened since the last snapshot.
func show_events(events: Array) -> void:
	for e in events:
		if String(e["kind"]) in ["SCENARIO_CLEARED", "SCENARIO_FAILED"]:
			_scenario_dialog.show_result(e, _snap.get("scenario", {}))
		var line := ProgressionText.notice(e, _milestone_defs)
		if line != "":
			_history.append(line)
		var cheer := rank_cheer(int(e["rank"])) if String(e["kind"]) == "RANK_UP" else ProgressionText.celebration(e, _milestone_defs)
		if cheer != "":
			_celebrations.append({"kind": String(e["kind"]), "line": cheer})
			if _celebrations.size() == 1:
				_start_celebration()
	if not events.is_empty() and not _snap.is_empty():
		apply_snapshot(_snap)
	else:
		_refresh_stage()


## 店舗ランク ★2 にぎわうお店 and the next rank's two conditions, e.g. "次の★3: 累計売上 ¥1,234,567 / ¥5,000,000・評判 53 / 55".
static func rank_text(view: Dictionary) -> String:
	if view.is_empty():
		return ""
	var lines: Array[String] = ["店舗ランク %s %s" % [StoreRank.stars(int(view["rank"])), String(view["name_ja"])]]
	var next: Dictionary = view.get("next", {})
	if next.is_empty():
		lines.append("最高ランクです")
	else:
		lines.append("次の%s: 累計売上 %s / %s・評判 %d / %d" % [StoreRank.stars(int(next["rank"])), GameHud.format_yen(int(view["revenue_yen"])),
			GameHud.format_yen(int(next["revenue_yen"])), int(view["reputation"]), int(next["reputation"])])
	return "
".join(lines)


## What she says when the store climbs a rank: the new rank and what it opens (fixture names from the catalog).
func rank_cheer(rank: int) -> String:
	var info := StoreRank.rank_info(rank)
	var names: Array[String] = []
	var fixtures: FixtureCatalog = _app.state.fixtures if _app != null and _app.get("state") != null else null
	for t in info["fixtures"]:
		var shown := String(fixtures.get_type(t).get("display_name", t)) if fixtures != null else String(t)
		names.append(shown.get_slice("（", 0))   # the short name: ベーカリーオーブン, not its case in brackets
	for f in info["features"]:
		names.append(String(StoreRank.FEATURE_JA.get(f, f)))
	var opened := "
新しく使えるもの: %s" % "、".join(names) if not names.is_empty() else ""
	return "店長、お店のランクが%s「%s」に上がりました！%s" % [StoreRank.stars(rank), info["name_ja"], opened]


func dismiss_cue() -> CommandResult:
	_seq += 1
	return _app.run_command({"command_id": "ui_cue_%d" % _seq, "kind": &"DISMISS_STORY_CUE", "cue_id": String(_snap.get("story_cue", ""))})


func toggle_tutorial() -> CommandResult:
	_seq += 1
	var skipped: bool = _snap.get("progression", {}).get("tutorial_skipped", false)
	return _app.run_command({"command_id": "ui_tutorial_%d" % _seq, "kind": &"SET_TUTORIAL_SKIPPED", "skipped": not skipped})
