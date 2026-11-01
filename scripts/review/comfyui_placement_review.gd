extends Control
## Issue #230 read-only gallery for the 334-image placement table.
## This scene is outside Main. It loads only the selected source image, so the
## review gallery never becomes a runtime texture cache and cannot approve assets.

const PLACEMENT_PATH := "res://docs/art/COMFYUI_334_IMAGE_PLACEMENT_20261101.json"
const CANDIDATE_ROOT := "res://assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/"

var _assets: Array = []
var _filtered: Array = []
var _list: ItemList
var _preview: TextureRect
var _meta: Label
var _status: Label
var _filter: LineEdit
var _group_filter: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_assets = load_placement_assets()
	_filtered = _assets.duplicate()
	_build_ui()
	_refresh_list()


static func load_placement_assets() -> Array:
	if not FileAccess.file_exists(PLACEMENT_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("assets", null)) != TYPE_ARRAY:
		return []
	return parsed["assets"]


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("eef1f4")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(key, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "ComfyUI 334枚 配置レビュー（読み取り専用）"
	title.add_theme_font_size_override("font_size", 25)
	root.add_child(title)
	var note := Label.new()
	note.text = "候補画像の実装先・seed・状態を確認します。ここでは承認・採用・runtime_approvedの変更は行いません。画像は選択時だけ読み込みます。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	_filter = LineEdit.new()
	_filter.name = "Search"
	_filter.placeholder_text = "ID / 用途 / trigger / screen を検索"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_value: String): _apply_filter())
	controls.add_child(_filter)
	_group_filter = OptionButton.new()
	_group_filter.name = "GroupFilter"
	_group_filter.add_item("全グループ")
	var groups: Array[String] = []
	for entry in _assets:
		var group := str(entry.get("group", ""))
		if not groups.has(group):
			groups.append(group)
	groups.sort()
	for group in groups:
		_group_filter.add_item(group)
	_group_filter.item_selected.connect(func(_index: int): _apply_filter())
	controls.add_child(_group_filter)

	_status = Label.new()
	root.add_child(_status)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size.x = 560
	split.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 6)
	preview_panel.add_child(preview_column)
	_preview = TextureRect.new()
	_preview.name = "SelectedCandidate"
	_preview.custom_minimum_size = Vector2(520, 470)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_column.add_child(_preview)
	_meta = Label.new()
	_meta.name = "CandidateMetadata"
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_column.add_child(_meta)

	var list_panel := PanelContainer.new()
	split.add_child(list_panel)
	_list = ItemList.new()
	_list.name = "PlacementCandidates"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_select_item)
	list_panel.add_child(_list)


func _apply_filter() -> void:
	var query := _filter.text.strip_edges().to_lower()
	var selected_group := ""
	if _group_filter.selected > 0:
		selected_group = _group_filter.get_item_text(_group_filter.selected)
	_filtered.clear()
	for entry in _assets:
		if selected_group != "" and str(entry.get("group", "")) != selected_group:
			continue
		var haystack := "|".join([
			str(entry.get("asset_id", "")),
			str(entry.get("candidate_relpath", "")),
			str(entry.get("screen_id", "")),
			str(entry.get("trigger_id", "")),
			str(entry.get("approval_state", "")),
		])
		if query != "" and not haystack.to_lower().contains(query):
			continue
		_filtered.append(entry)
	_refresh_list()


func _refresh_list() -> void:
	if _list == null:
		return
	_list.clear()
	for entry in _filtered:
		_list.add_item("[%s] %s | %s | %s | %s" % [
			str(entry.get("asset_id", "")),
			str(entry.get("group", "")),
			str(entry.get("screen_id", "")),
			str(entry.get("trigger_id", "")),
			str(entry.get("approval_state", "")),
		])
	_status.text = "表示 %d / 全候補 %d　（runtime_approved=false / 読み取り専用）" % [_filtered.size(), _assets.size()]
	if not _filtered.is_empty():
		_list.select(0)
		_select_item(0)


func _select_item(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	var entry: Dictionary = _filtered[index]
	var source_path := CANDIDATE_ROOT + str(entry.get("candidate_relpath", ""))
	_preview.texture = load(source_path) as Texture2D
	_meta.text = "ID: %s\nSeed: %s\nGroup: %s\nScreen: %s / Slot: %s\nTrigger: %s\nPriority: %s / Display: %s\nApproval: %s / Visual match: %s\nSource: %s" % [
		str(entry.get("asset_id", "")),
		str(entry.get("seed", "")),
		str(entry.get("group", "")),
		str(entry.get("screen_id", "")),
		str(entry.get("ui_slot", "")),
		str(entry.get("trigger_id", "")),
		str(entry.get("implementation_priority", "")),
		str(entry.get("display_policy", "")),
		str(entry.get("approval_state", "")),
		str(entry.get("visual_match", "")),
		str(entry.get("candidate_relpath", "")),
	]
