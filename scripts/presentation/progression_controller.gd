class_name ProgressionController
extends Node
## "はじめかた" section of the inspector: tutorial card with skip / show again, today's challenge,
## milestone progress and the latest notices. It shows what ProgressionService decided; it never
## judges progress itself. Hiding the tutorial only flips `tutorial_skipped` (a Domain command),
## so progress and notices are never lost.

const NOTICE_LINES := 5
const ASSISTANT_NAME := "小春六花"   # the manager assistant character (user's choice, 2026-10-30)
const ASSISTANT_PORTRAIT := "res://assets/ui/characters/rikka_portrait.png"

var _app: Node
var _card: Label
var _challenge: Label
var _milestones: Label
var _notices: Label
var _toggle: Button
var _assistant: Label
var _assistant_row: HBoxContainer   # portrait + the assistant's line
var _dismiss: Button
var _achievements: Label
var _history: Array[String] = []
var _snap: Dictionary = {}
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
	_assistant_row = HBoxContainer.new()
	_assistant_row.name = "AssistantRow"
	_assistant_row.add_theme_constant_override("separation", 10)
	var portrait := TextureRect.new()
	portrait.name = "AssistantPortrait"
	portrait.texture = load(ASSISTANT_PORTRAIT) as Texture2D
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_assistant_row.add_child(portrait)
	_assistant = Label.new()
	_assistant.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assistant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assistant_row.add_child(_assistant)
	_dismiss = Button.new()
	_dismiss.text = "閉じる"
	_dismiss.pressed.connect(dismiss_cue)
	_achievements = Label.new()
	_achievements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in [_card, _toggle, _challenge, _milestones, _notices, _assistant_row, _dismiss, _achievements]:
		_body.add_child(c)
	apply_snapshot({"progression": {"tutorial_skipped": false, "tutorial_step_index": 0, "completed_milestone_ids": [], "active_daily_challenge_id": null}})


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	var p: Dictionary = snap["progression"]
	var skipped: bool = p["tutorial_skipped"]
	_card.text = "チュートリアルは非表示です（進み具合は保存されています）" if skipped else ProgressionText.step_text(int(p["tutorial_step_index"]))
	_toggle.text = "チュートリアルを再表示" if skipped else "チュートリアルをスキップ"
	_challenge.text = ProgressionText.challenge_text(p["active_daily_challenge_id"])
	var done: int = p["completed_milestone_ids"].size()
	_milestones.text = "称号 %d/%d（店のレベル %d）" % [done, maxi(_milestone_defs.size(), done), done]
	_notices.text = "\n".join(_history.slice(maxi(_history.size() - NOTICE_LINES, 0)))
	var cue := String(snap.get("story_cue", ""))
	_assistant.text = ("%s（店長アシスタント）\n%s" % [ASSISTANT_NAME, ProgressionText.assistant_text(cue)]) if cue != "" else ""
	_assistant.visible = cue != ""
	_assistant_row.visible = cue != ""
	_dismiss.visible = cue != ""
	var lines: Array[String] = []
	for entry in snap.get("milestone_progress", []):
		lines.append(ProgressionText.progress_line(entry))
	_achievements.text = "実績一覧\n" + "\n".join(lines) if not lines.is_empty() else ""


## Called by AppRoot with the achievements that happened since the last snapshot.
func show_events(events: Array) -> void:
	for e in events:
		var line := ProgressionText.notice(e, _milestone_defs)
		if line != "":
			_history.append(line)
	if not events.is_empty() and not _snap.is_empty():
		apply_snapshot(_snap)


func dismiss_cue() -> CommandResult:
	_seq += 1
	return _app.run_command({"command_id": "ui_cue_%d" % _seq, "kind": &"DISMISS_STORY_CUE", "cue_id": String(_snap.get("story_cue", ""))})


func toggle_tutorial() -> CommandResult:
	_seq += 1
	var skipped: bool = _snap.get("progression", {}).get("tutorial_skipped", false)
	return _app.run_command({"command_id": "ui_tutorial_%d" % _seq, "kind": &"SET_TUTORIAL_SKIPPED", "skipped": not skipped})
