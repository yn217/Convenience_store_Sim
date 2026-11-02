class_name TitleScreen
extends Control
## Title screen (issue #28, mockup SCR-05): 新規ゲーム, 続きから (the slot saved last; off without a save), 設定 (sound
## on / off, the same settings file as the game) and 終了. Presentation only: it picks the scene to start and, for
## 続きから, tells AppRoot which slot to load first.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const SETTINGS_PATH := "user://settings.json"
const TITLE_RIKKA := "res://assets/ui/title/title_rikka.png"
const PILOT_REGISTRY_PATH := "res://data/presentation/character_visuals_v1.json"
const PILOT_TITLE_ID := "title_background_pilot"
const TITLE_RIKKA_SIZE := Vector2(560, 815)   # keeps the art's 640:931 aspect

var save_dir := SaveStore.DIR
var _continue: Button
var _settings: VBoxContainer
var _sound: CheckBox


func _ready() -> void:
	theme = UiTheme.build()
	# The artwork contains no baked-in buttons: all controls remain real Godot UI elements.
	var background := TextureRect.new()
	background.name = "TitleBackground"
	# Anime background art (ComfyUI, tools/assets/build_scene_ui.py, 1920x1080); the flat SVG is the fallback.
	var painted := "res://assets/ui/title/title_background.png"
	var pilot_texture := pilot_title_texture(VisualVariants.override())
	background.texture = pilot_texture if pilot_texture != null else load(painted if ResourceLoader.exists(painted) else "res://assets/ui/title/title_background.svg") as Texture2D
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var tint := ColorRect.new()
	tint.name = "TitleTint"
	tint.color = Color(0.045, 0.10, 0.18, 0.22)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	# 小春六花 greets the player at the right (ComfyUI render, tools/assets/build_character_ui.py; 640x931 for ~640 px).
	# The pilot title image already contains 小春六花. Do not layer the standalone figure on top of it.
	var rikka_texture: Texture2D = null
	if pilot_texture == null:
		rikka_texture = load(TITLE_RIKKA) as Texture2D
	if rikka_texture != null:
		var rikka := TextureRect.new()
		rikka.name = "TitleRikka"
		rikka.texture = rikka_texture
		rikka.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rikka.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rikka.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rikka.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		rikka.offset_left = -TITLE_RIKKA_SIZE.x - 40
		rikka.offset_right = -40
		rikka.offset_top = -TITLE_RIKKA_SIZE.y
		rikka.offset_bottom = 0
		add_child(rikka)
	# The reference title screen uses a warm framed menu and a small notification affordance.
	# These remain real Godot controls layered over the art; the generated background stays text-free.
	var menu_frame := PanelContainer.new()
	menu_frame.name = "TitleMenuFrame"
	menu_frame.set_anchors_preset(Control.PRESET_CENTER)
	menu_frame.offset_left = -310
	menu_frame.offset_top = -270
	menu_frame.offset_right = 310
	menu_frame.offset_bottom = 285
	menu_frame.add_theme_stylebox_override("panel", _title_menu_style())
	menu_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_frame)
	add_child(_title_notice())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(550, 0)
	center.add_child(col)
	var logo_texture := load("res://assets/ui/title/title_logo.svg") as Texture2D
	if logo_texture != null:
		var logo := TextureRect.new()
		logo.name = "TitleLogo"
		logo.texture = logo_texture
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(550, 150)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(logo)
		# The plate is drawn at half size (1100x260 -> 550x130, 10 px down); the words sit on it as labels, since
		# Godot's SVG import draws no <text>.
		logo.add_child(_logo_label("TitleName", "コンビニ経営\nシミュレーション", 34, Color("ffb03a"), Rect2(14, 10, 522, 84), 8))
		logo.add_child(_logo_label("TitleSub", "CONVENIENCE STORE SIM", 15, Color("23537c"), Rect2(154, 95, 242, 32), 0))
	else:
		var name_label := Label.new()
		name_label.text = "コンビニ経営\nシミュレーション"
		name_label.add_theme_font_size_override("font_size", 34)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
	var tagline := Label.new()
	tagline.text = "目指せ、街で愛されるコンビニ。"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_outline_color", Color("0b1a2b"))   # readable over the lit storefront of the painted background
	tagline.add_theme_constant_override("outline_size", 6)
	col.add_child(tagline)
	col.add_child(HSeparator.new())
	col.add_child(_button("NewGame", "新規ゲーム", new_game, true))
	_continue = _button("Continue", "続きから", continue_game, false)
	col.add_child(_continue)
	col.add_child(_button("Settings", "設定", func(): _settings.visible = not _settings.visible, false))
	_settings = VBoxContainer.new()
	_settings.visible = false
	_sound = CheckBox.new()
	_sound.text = "効果音を鳴らす"
	_sound.button_pressed = not bool(read_settings().get("muted", true))
	_sound.toggled.connect(func(on): write_setting("muted", not on))
	_settings.add_child(_sound)
	col.add_child(_settings)
	col.add_child(_button("Quit", "ゲームを終了", func(): get_tree().quit(), false))
	refresh()


func _title_menu_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.08, 0.055, 0.82)
	box.border_color = Color("f7d18b")
	box.set_border_width_all(4)
	box.set_corner_radius_all(26)
	box.shadow_color = Color(0.02, 0.01, 0.01, 0.48)
	box.shadow_size = 12
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box


func _title_notice() -> Control:
	var notice := PanelContainer.new()
	notice.name = "TitleNotice"
	notice.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notice.offset_left = -254
	notice.offset_top = 24
	notice.offset_right = -28
	notice.offset_bottom = 92
	notice.add_theme_stylebox_override("panel", _title_notice_style())
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	notice.add_child(row)
	var bell_path := "res://assets/ui/art/bell.png"
	if ResourceLoader.exists(bell_path):
		var bell := TextureRect.new()
		bell.name = "Bell"
		bell.texture = load(bell_path) as Texture2D
		bell.custom_minimum_size = Vector2(34, 34)
		bell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bell)
	var label := Label.new()
	label.name = "NoticeLabel"
	label.text = "お知らせ"
	label.add_theme_font_size_override("font_size", 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var badge := Label.new()
	badge.name = "NoticeBadge"
	badge.text = "!"
	badge.custom_minimum_size = Vector2(28, 28)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", _title_badge_style())
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	return notice


func _title_notice_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.08, 0.055, 0.92)
	box.border_color = Color("f7d18b")
	box.set_border_width_all(3)
	box.set_corner_radius_all(24)
	box.content_margin_left = 16
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _title_badge_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e94b55")
	box.set_corner_radius_all(14)
	return box


## Registry-gated title candidate. Unapproved rows remain fallback-only; a non-empty
## VisualVariants override explicitly waives that gate for local debug inspection.
static func pilot_title_texture(override_name: String = "") -> Texture2D:
	# An explicit override is a QA-only path which may inspect an unapproved
	# candidate. Once a registry row is approved, the same texture is also
	# available to the normal title screen in release builds.
	if not FileAccess.file_exists(PILOT_REGISTRY_PATH):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(PILOT_REGISTRY_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	for raw_entry in data.get("assets", []):
		if typeof(raw_entry) != TYPE_DICTIONARY or String(raw_entry.get("id", "")) != PILOT_TITLE_ID:
			continue
		if not title_entry_allowed(raw_entry, OS.is_debug_build(), override_name):
			return null
		var path := String(raw_entry.get("runtime_path", ""))
		if path == "" or not ResourceLoader.exists(path):
			return null
		var texture := load(path) as Texture2D
		return texture
	return null


static func title_entry_allowed(entry: Dictionary, debug_build: bool, override_name: String = "") -> bool:
	## QA override may inspect a held candidate only in debug; approved entries work normally.
	return (debug_build and override_name != "") or bool(entry.get("runtime_approved", false))


func _logo_label(node_name: String, text: String, size: int, color: Color, rect: Rect2, outline: int) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("13263e"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(node_name: String, text: String, on_press: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(on_press)
	return b


## 続きから is off without a save.
func refresh() -> void:
	var has_save := SaveStore.latest_slot(save_dir) != ""
	_continue.disabled = not has_save
	_continue.tooltip_text = "" if has_save else "セーブがありません"


func new_game() -> void:
	AppRoot.start_slot = ""
	get_tree().change_scene_to_file(MAIN_SCENE)


## Starts the game with the slot saved last.
func continue_game() -> void:
	var slot := SaveStore.latest_slot(save_dir)
	if slot == "":
		return
	AppRoot.start_slot = slot
	get_tree().change_scene_to_file(MAIN_SCENE)


static func read_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Changes one setting and keeps the others (the game reads the same file, CuePlayer).
static func write_setting(key: String, value) -> void:
	var data := read_settings()
	data[key] = value
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
