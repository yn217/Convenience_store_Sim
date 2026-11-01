extends Control
## Issue #230 review-only gallery for the 11-image character visual pilot.
## It deliberately lives outside the normal Main scene so unapproved candidates cannot replace
## the production UI. The registry is the only source of image paths and trigger metadata.

const REGISTRY_PATH := "res://data/presentation/character_visuals_v1.json"
const CARD_WIDTH := 248.0
const CARD_HEIGHT := 300.0

var _registry: Dictionary = {}
var _preview: TextureRect
var _preview_meta: Label
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_registry = _load_registry()
	_build_ui()


func _load_registry() -> Dictionary:
	if not FileAccess.file_exists(REGISTRY_PATH):
		push_error("Character visual registry is missing: " + REGISTRY_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("assets", null)) != TYPE_ARRAY:
		push_error("Character visual registry is invalid: " + REGISTRY_PATH)
		return {}
	return parsed


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#eef1f4")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "小春六花 キャラクター素材パイロット"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)

	var note := Label.new()
	note.text = "Issue #230 / 11枚のレビュー用プレビュー。未承認素材は通常ゲーム画面へ自動接続しません。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 300
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size.x = 430
	split.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 6)
	preview_panel.add_child(preview_column)
	var preview_title := Label.new()
	preview_title.text = "選択プレビュー"
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_column.add_child(preview_title)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(400, 230)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_preview_column.add_child(_preview)
	_preview_meta = Label.new()
	_preview_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_column.add_child(_preview_meta)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var assets: Array = _registry.get("assets", [])
	_status = Label.new()
	_status.text = "候補数: %d / runtime_approved: false" % assets.size()
	column.add_child(_status)

	for entry in assets:
		_add_card(grid, entry)
	if not assets.is_empty():
		_select_asset(assets[0])


func _add_card(grid: GridContainer, entry: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	grid.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)

	var image := TextureButton.new()
	image.custom_minimum_size = Vector2(CARD_WIDTH - 12, 220)
	image.ignore_texture_size = true
	image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_normal = load(String(entry.get("runtime_path", "")))
	image.tooltip_text = "クリックで選択プレビュー"
	image.pressed.connect(func() -> void: _select_asset(entry))
	column.add_child(image)

	var label := Label.new()
	label.text = "%s\n%s / %s\n%s" % [
		String(entry.get("id", "")),
		String(entry.get("kind", "")),
		String(entry.get("screen_id", "")),
		String(entry.get("trigger", "")),
	]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)


func _select_asset(entry: Dictionary) -> void:
	_preview.texture = load(String(entry.get("runtime_path", "")))
	_preview_meta.text = "ID: %s\n画面: %s\n発火条件: %s\n状態: %s\nフォールバック: %s" % [
		String(entry.get("id", "")),
		String(entry.get("screen_id", "")),
		String(entry.get("trigger", "")),
		String(entry.get("status", "review_only")),
		String(entry.get("fallback", "text_only")),
	]
