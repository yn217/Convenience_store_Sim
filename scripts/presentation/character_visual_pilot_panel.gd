extends Node
## Issue #230 pilot runtime display. It only changes presentation and never changes Domain state.

signal pilot_visibility_changed(enabled: bool)

const REGISTRY_PATH := "res://data/presentation/character_visuals_v1.json"
var _entries: Array = []
var _image: TextureRect
var _meta: Label
var _reaction_image: TextureRect
var _reaction_meta: Label
var _reaction_title: Label
var _toggle: CheckButton
var _snapshot: Dictionary = {}


func _ready() -> void:
	if not OS.is_debug_build():
		return
	_entries = _load_entries()
	var body := get_node_or_null("../Layout/MainArea/FixtureInspector/Scroll/Body")
	if body == null:
		return
	var title := Label.new()
	title.text = "店長アシスタント立ち絵（パイロット）"
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)
	_toggle = CheckButton.new()
	_toggle.text = "生成立ち絵を表示（Issue #230）"
	_toggle.tooltip_text = "選定済みパイロット立ち絵をアシスタント欄に表示します。未承認候補の一括採用は行いません。"
	_toggle.toggled.connect(_set_review_visible)
	body.add_child(_toggle)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(0, 300)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.visible = false
	body.add_child(_image)
	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.visible = false
	body.add_child(_meta)
	_reaction_title = Label.new()
	_reaction_title.text = "バストアップリアクション候補（専用枠）"
	_reaction_title.add_theme_font_size_override("font_size", 15)
	_reaction_title.visible = false
	body.add_child(_reaction_title)
	_reaction_image = TextureRect.new()
	_reaction_image.name = "ReactionPilotPreview"
	_reaction_image.custom_minimum_size = Vector2(0, 220)
	_reaction_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reaction_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reaction_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reaction_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reaction_image.visible = false
	body.add_child(_reaction_image)
	_reaction_meta = Label.new()
	_reaction_meta.name = "ReactionPilotMeta"
	_reaction_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reaction_meta.visible = false
	body.add_child(_reaction_meta)
	var default_visible := OS.is_debug_build()
	_toggle.button_pressed = default_visible
	_set_review_visible(default_visible)


func _load_entries() -> Array:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("assets", null)) != TYPE_ARRAY:
		return []
	return parsed["assets"]


func _set_review_visible(enabled: bool) -> void:
	_image.visible = enabled and _reaction_image.texture == null
	_meta.visible = enabled and _reaction_image.texture == null
	_reaction_image.visible = enabled and _reaction_image.texture != null
	_reaction_meta.visible = enabled and _reaction_image.texture != null
	_reaction_title.visible = enabled and _reaction_image.texture != null
	if enabled:
		_show_selected(_select_entry(_snapshot))
	pilot_visibility_changed.emit(enabled)
	var guide := get_node_or_null("../ProgressionController")
	if guide != null and guide.has_method("refresh_visual_pilot"):
		guide.refresh_visual_pilot()


func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if _toggle != null and _toggle.button_pressed:
		_show_selected(_select_entry(snapshot))
	var guide := get_node_or_null("../ProgressionController")
	if guide != null and guide.has_method("refresh_visual_pilot"):
		guide.refresh_visual_pilot()


func is_pilot_enabled() -> bool:
	return _toggle != null and _toggle.button_pressed


func selected_entry(snapshot: Dictionary) -> Dictionary:
	return _select_entry(snapshot)


func stage_entry(snapshot: Dictionary) -> Dictionary:
	var entry := _select_entry(snapshot)
	var story_cue := String(snapshot.get("story_cue", ""))
	if story_cue == "story_queue_giveup":
		return _find("functional_queue")
	if story_cue == "story_staff_short":
		return _find("functional_staff_short")
	if String(entry.get("kind", "")) != "bustup_reaction":
		return entry
	match String(entry.get("id", "")):
		"reaction_discovery":
			return _find("functional_opening_checklist")
		"reaction_pleading":
			return _find("fullbody_emotion_05")
		"reaction_deadpan":
			return _find("fullbody_tutorial_layout")
	return _find("fullbody_dynamic_201")


## Returns a bust-up reaction for story cues that benefit from a close facial read.
## The full-body stage remains available as a separate fallback/route; callers must
## choose one display layer so the two character representations never stack.
func reaction_entry(snapshot: Dictionary) -> Dictionary:
	var story_cue := String(snapshot.get("story_cue", ""))
	match story_cue:
		"story_start":
			return _find("reaction_discovery")
		"story_queue_giveup", "story_staff_short":
			return _find("reaction_pleading")
	return {}


func event_entry(event_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("kind", "")) == "event_image" and String(entry.get("trigger", "")) == event_id:
			return entry
	if event_id == "evt_quiet_street":
		return _find("reaction_deadpan")
	return {}


func cue_entry(cue_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("kind", "")) == "functional_pose" and String(entry.get("trigger", "")) == cue_id:
			return entry
	if cue_id == "rival_opened":
		return _find("functional_rival_store")
	if cue_id == "capsule_empty":
		return _find("functional_capsule_rare")
	if cue_id == "save_complete":
		return _find("functional_save_complete")
	if cue_id == "restock_help":
		return _find("functional_restock_guidance")
	if cue_id == "staff_hired":
		return _find("functional_staff_hiring")
	if cue_id == "seasonal_campaign_started":
		return _find("functional_campaign")
	return {}


func _select_entry(snapshot: Dictionary) -> Dictionary:
	var event_data: Dictionary = snapshot.get("gameplay_event", {})
	var event_id := String(event_data.get("event_id", event_data.get("id", "")))
	var progression: Dictionary = snapshot.get("progression", {})
	var story_cue := String(snapshot.get("story_cue", ""))
	var completed: Array = progression.get("completed_milestone_ids", [])
	if event_id == "evt_neighbor_mentions":
		return _find("event_neighbor_mentions")
	if event_id == "evt_quiet_street":
		return _find("reaction_deadpan")
	if story_cue == "story_sold_out":
		return _find("functional_sold_out")
	if story_cue == "story_queue_giveup":
		return _find("reaction_pleading")
	if story_cue == "story_staff_short":
		return _find("reaction_pleading")
	if story_cue == "story_event":
		return _find("event_neighbor_mentions")
	if story_cue == "story_start":
		return _find("reaction_discovery")
	if story_cue == "story_register":
		return _find("functional_register_guidance")
	if story_cue == "story_first_restock":
		return _find("functional_restock_guidance")
	if story_cue == "story_first_profit":
		return _find("functional_first_profit")
	if story_cue == "story_first_sale":
		return _find("fullbody_emotion_05")
	if story_cue != "":
		return _find("functional_opening_checklist")
	if str(progression.get("active_daily_challenge_id", "")) == "challenge_sales_3":
		return _find("functional_three_sales")
	if str(progression.get("active_daily_challenge_id", "")) == "challenge_stock_2":
		return _find("functional_stock_challenge")
	if str(progression.get("active_daily_challenge_id", "")) == "challenge_no_waste":
		return _find("functional_no_waste")
	for milestone in [
		["ms_three_fixtures", "functional_expansion"],
		["ms_first_week", "functional_day_end_review"],
		["ms_six_categories", "functional_six_categories"],
		["ms_fifty_visitors", "functional_fifty_visitors"],
		["ms_ten_sales", "functional_ten_sales"]
	]:
		if completed.has(milestone[0]):
			return _find(milestone[1])
	if completed.has("ms_first_sale") or completed.has("ms_first_profit"):
		return _find("fullbody_emotion_05")
	return _find("fullbody_dynamic_201")


func day_end_entry(mood: String) -> Dictionary:
	return _find("functional_day_end_review") if mood == "worried" else _find("functional_day_report")


func _find(asset_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("id", "")) == asset_id:
			return entry
	return {}


func _show_selected(entry: Dictionary) -> void:
	if entry.is_empty():
		_image.texture = null
		_reaction_image.texture = null
		_image.visible = false
		_meta.visible = false
		_reaction_image.visible = false
		_reaction_meta.visible = false
		_reaction_title.visible = false
		_meta.text = "候補画像がありません。従来の文字表示へフォールバックします。"
		return
	var is_reaction := String(entry.get("kind", "")) == "bustup_reaction"
	var texture := load(String(entry.get("runtime_path", ""))) as Texture2D
	_image.texture = null if is_reaction else texture
	_reaction_image.texture = texture if is_reaction else null
	_image.visible = is_pilot_enabled() and not is_reaction
	_meta.visible = is_pilot_enabled() and not is_reaction
	_reaction_image.visible = is_pilot_enabled() and is_reaction
	_reaction_meta.visible = is_pilot_enabled() and is_reaction
	_reaction_title.visible = is_pilot_enabled() and is_reaction
	var details := "画面=%s / 条件=%s\n未承認候補のため、既存表示へのフォールバックを維持" % [
		String(entry.get("screen_id", "")),
		String(entry.get("trigger", "")),
	]
	if is_reaction:
		_reaction_meta.text = "バストアップリアクション: %s\n%s" % [String(entry.get("id", "")), details]
	else:
		_meta.text = "パイロット立ち絵: %s\n%s" % [String(entry.get("id", "")), details]
