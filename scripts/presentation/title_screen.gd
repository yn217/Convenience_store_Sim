class_name TitleScreen
extends Control
## Title screen (issue #28, mockup SCR-05): 新規ゲーム, 続きから (the slot saved last; off without a save), 設定 (sound
## on / off, the same settings file as the game) and 終了. Presentation only: it picks the scene to start and, for
## 続きから, tells AppRoot which slot to load first.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const SETTINGS_PATH := "user://settings.json"
const TITLE_RIKKA := "res://assets/ui/title/title_rikka.png"
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
	background.texture = load("res://assets/ui/title/title_background.svg") as Texture2D
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
	var rikka_texture := load(TITLE_RIKKA) as Texture2D
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
		logo.add_child(_logo_label("TitleName", "コンビニ経営ゲーム", 46, Color("ffb03a"), Rect2(14, 14, 522, 74), 10))
		logo.add_child(_logo_label("TitleSub", "CONVENIENCE STORE SIM", 15, Color("23537c"), Rect2(154, 95, 242, 32), 0))
	else:
		var name_label := Label.new()
		name_label.text = "コンビニ経営ゲーム"
		name_label.add_theme_font_size_override("font_size", 34)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
	var tagline := Label.new()
	tagline.text = "目指せ、街で愛されるコンビニ。"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1, 1, 1, 0.75)
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
