class_name TitleScreen
extends Control
## Title screen (issue #28, mockup SCR-05): 新規ゲーム, 続きから (the slot saved last; off without a save), 設定 (sound
## on / off, the same settings file as the game) and 終了. Presentation only: it picks the scene to start and, for
## 続きから, tells AppRoot which slot to load first.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const SETTINGS_PATH := "user://settings.json"

var save_dir := SaveStore.DIR
var _continue: Button
var _settings: VBoxContainer
var _sound: CheckBox


func _ready() -> void:
	theme = UiTheme.build()
	var bg := ColorRect.new()
	bg.color = Color("17212b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(360, 0)
	center.add_child(col)
	var name_label := Label.new()
	name_label.text = "コンビニ経営シミュレーター"
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
	col.add_child(_button("Quit", "終了", func(): get_tree().quit(), false))
	refresh()


func _button(node_name: String, text: String, on_press: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
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
