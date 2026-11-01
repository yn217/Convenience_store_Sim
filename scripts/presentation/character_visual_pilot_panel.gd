extends Node
## Optional review-only panel for Issue #230. It is opt-in and never changes Domain state.

const REGISTRY_PATH := "res://data/presentation/character_visuals_v1.json"

var _entries: Array = []
var _image: TextureRect
var _meta: Label
var _toggle: CheckButton
var _snapshot: Dictionary = {}


func _ready() -> void:
	_entries = _load_entries()
	var body := get_node_or_null("../Layout/MainArea/FixtureInspector/Scroll/Body")
	if body == null:
		return
	var title := Label.new()
	title.text = "キャラクター素材パイロット"
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)
	_toggle = CheckButton.new()
	_toggle.text = "候補画像を表示（未承認）"
	_toggle.tooltip_text = "Issue #230のレビュー候補。通常のゲーム演出を置き換えません。"
	_toggle.toggled.connect(_set_review_visible)
	body.add_child(_toggle)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(0, 220)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.visible = false
	body.add_child(_image)
	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.visible = false
	body.add_child(_meta)


func _load_entries() -> Array:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("assets", null)) != TYPE_ARRAY:
		return []
	return parsed["assets"]


func _set_review_visible(enabled: bool) -> void:
	_image.visible = enabled
	_meta.visible = enabled
	if enabled:
		_show_selected(_select_entry(_snapshot))


func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if _toggle != null and _toggle.button_pressed:
		_show_selected(_select_entry(snapshot))


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
	if story_cue != "":
		return _find("functional_opening_checklist")
	if completed.has("ms_first_sale") or completed.has("ms_first_profit"):
		return _find("fullbody_emotion_05")
	return _find("fullbody_dynamic_201")


func _find(asset_id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.get("id", "")) == asset_id:
			return entry
	return {}


func _show_selected(entry: Dictionary) -> void:
	if entry.is_empty():
		_image.texture = null
		_meta.text = "候補画像がありません。従来の文字表示へフォールバックします。"
		return
	_image.texture = load(String(entry.get("runtime_path", "")))
	_meta.text = "未承認パイロット: %s\n画面=%s / 条件=%s\n通常ビルドでは従来表示へフォールバック" % [
		String(entry.get("id", "")),
		String(entry.get("screen_id", "")),
		String(entry.get("trigger", "")),
	]
