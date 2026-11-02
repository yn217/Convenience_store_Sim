class_name EventController
extends Node
## "今日のイベント" section of the inspector (SCR-11): the day's event, its window, effect and what is
## still missing to profit from it. Shows what EventService decided; it never draws or applies anything.
## Under the text (#31 mockup 本日の地域イベント): 効果の内訳 as chips, and 本日のイベント一覧 with every event of the master
## data marked 選択中 / 候補 / its lock (hover for the details), and イベント履歴: the last HISTORY_LINES days, newest first.

const LIST_COLUMNS := 3
const STATE_JA := {"selected": "選択中", "candidate": "候補"}
const HISTORY_LINES := 7

var _status: Label
var _effects: HFlowContainer
var _list_title: Label
var _list: GridContainer
var _list_key := ""
var _cells: Dictionary = {}   # event id -> {panel, state}
var _effects_key := ""
var _history_title: Label
var _history: Label
var _visual_row: HBoxContainer
var _pilot_column: VBoxContainer
var _picture: TextureRect
var _pilot_caption: Label
var _pilot_picture: TextureRect
var _pilot_reaction_picture: TextureRect
var _pilot_reaction_symbol: Label
var _pilot_texture_active := false
const PICTURE_DIR := "res://assets/ui/events/"
const PICTURE_SIZE := Vector2(384, 216)
const PILOT_FULLBODY_SIZE := Vector2(160, 240)
const PILOT_REACTION_SIZE := Vector2(220, 220)
static var _pictures := {}

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	var title := Label.new()
	title.text = "今日のイベント"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_visual_row = HBoxContainer.new()
	_visual_row.name = "EventVisualRow"
	_visual_row.add_theme_constant_override("separation", 12)
	_visual_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_body.add_child(_visual_row)
	_picture = TextureRect.new()   # the day's event as an anime illustration (ComfyUI, 576x324 for this 384x216 slot)
	_picture.name = "EventPicture"
	_picture.custom_minimum_size = PICTURE_SIZE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.visible = false
	_visual_row.add_child(_picture)
	_pilot_column = VBoxContainer.new()
	_pilot_column.name = "EventPilotColumn"
	_pilot_column.add_theme_constant_override("separation", 4)
	_visual_row.add_child(_pilot_column)
	_pilot_caption = Label.new()
	_pilot_caption.text = "イベント用立ち絵（パイロット・確認中）"
	_pilot_caption.theme_type_variation = &"CardTitle"
	_pilot_caption.visible = false
	_pilot_column.add_child(_pilot_caption)
	_pilot_picture = TextureRect.new()
	_pilot_picture.name = "EventPilotFullbodyPicture"
	_pilot_picture.custom_minimum_size = PILOT_FULLBODY_SIZE
	_pilot_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pilot_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pilot_picture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pilot_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilot_picture.visible = false
	_pilot_column.add_child(_pilot_picture)
	_pilot_reaction_picture = TextureRect.new()
	_pilot_reaction_picture.name = "EventPilotReactionPicture"
	_pilot_reaction_picture.custom_minimum_size = PILOT_REACTION_SIZE
	_pilot_reaction_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pilot_reaction_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pilot_reaction_picture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pilot_reaction_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilot_reaction_picture.visible = false
	_pilot_column.add_child(_pilot_reaction_picture)
	_pilot_reaction_symbol = Label.new()
	_pilot_reaction_symbol.name = "EventPilotReactionSymbol"
	_pilot_reaction_symbol.add_theme_font_size_override("font_size", 34)
	_pilot_reaction_symbol.add_theme_color_override("font_color", UiTheme.WARM)
	_pilot_reaction_symbol.add_theme_color_override("font_outline_color", Color("172333"))
	_pilot_reaction_symbol.add_theme_constant_override("outline_size", 6)
	_pilot_reaction_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pilot_reaction_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilot_reaction_symbol.visible = false
	_pilot_column.add_child(_pilot_reaction_symbol)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)
	_effects = HFlowContainer.new()
	_effects.name = "EventEffects"
	_effects.add_theme_constant_override("h_separation", 6)
	_effects.add_theme_constant_override("v_separation", 6)
	_body.add_child(_effects)
	_list_title = Label.new()
	_list_title.text = "本日のイベント一覧"
	_list_title.theme_type_variation = &"CardTitle"
	_body.add_child(_list_title)
	_list = GridContainer.new()
	_list.name = "EventCatalog"
	_list.columns = LIST_COLUMNS
	_list.add_theme_constant_override("h_separation", 6)
	_list.add_theme_constant_override("v_separation", 6)
	_body.add_child(_list)
	_history_title = Label.new()
	_history_title.text = "イベント履歴"
	_history_title.theme_type_variation = &"CardTitle"
	_body.add_child(_history_title)
	_history = Label.new()
	_history.name = "EventHistory"
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_history)


func apply_snapshot(snap: Dictionary) -> void:
	var view: Dictionary = snap.get("gameplay_event", {"status": "no_data"})
	_status.text = "\n".join(EventText.lines(view, int(snap.get("time_sec", 0)), snap.get("stocked_categories", [])))
	var pic := picture_for(String(view.get("event_id", ""))) if String(view.get("status", "")) in ["scheduled", "active", "ended", "missed"] else null
	_picture.texture = pic
	_picture.visible = pic != null
	var event_id := String(view.get("event_id", ""))
	var pilot := get_node_or_null("../CharacterVisualPilotPanel")
	var pilot_active: bool = String(view.get("status", "")) == "active"
	var pilot_entry: Dictionary = pilot.event_entry(event_id) if pilot_active and pilot != null and pilot.has_method("event_entry") and pilot.has_method("is_pilot_enabled") and pilot.is_pilot_enabled() else {}
	var pilot_texture: Texture2D = load(String(pilot_entry.get("runtime_path", ""))) as Texture2D if not pilot_entry.is_empty() else null
	var is_reaction := String(pilot_entry.get("kind", "")) == "bustup_reaction"
	_pilot_picture.texture = pilot_texture if pilot_texture != null and not is_reaction else null
	_pilot_reaction_picture.texture = pilot_texture if pilot_texture != null and is_reaction else null
	_pilot_reaction_symbol.text = String(pilot_entry.get("overlay_symbol", "")) if pilot_texture != null and is_reaction else ""
	_pilot_caption.visible = pilot_texture != null
	_pilot_picture.visible = pilot_texture != null and not is_reaction
	_pilot_reaction_picture.visible = pilot_texture != null and is_reaction
	_pilot_reaction_symbol.visible = pilot_texture != null and is_reaction and not _pilot_reaction_symbol.text.is_empty()
	_pilot_texture_active = pilot_texture != null
	_sync_assistant_suppression()
	_render_effects(EventText.effect_chips(view) if String(view.get("status", "")) in ["scheduled", "active", "ended", "missed"] else [])
	_render_catalog(snap.get("event_catalog", []))
	var past: Array = snap.get("event_history", [])
	_history.text = history_text(past)
	_history.visible = not past.is_empty()
	_history_title.visible = not past.is_empty()


## The event pilot owns the event-management presentation while its panel is open.
## Keep the persistent corner assistant hidden in that case so the same character
## is not rendered twice. MainLayout calls this again when the screen opens/closes.
func sync_assistant_suppression(management_visible: bool) -> void:
	var guide := get_node_or_null("../ProgressionController")
	if guide != null and guide.has_method("set_suppressed"):
		guide.set_suppressed(management_visible and _pilot_texture_active, "event_pilot")
	var chrome := get_node_or_null("../MockupChrome")
	if chrome != null and chrome.has_method("set_pilot_assistant_visible"):
		if management_visible and _pilot_texture_active:
			# The event panel's own pilot is the only assistant representation on screen.
			chrome.set_pilot_assistant_visible(true)
		elif guide != null and guide.has_method("refresh_visual_pilot"):
			guide.refresh_visual_pilot()


func _sync_assistant_suppression() -> void:
	var main := get_parent()
	if main == null or not main.has_method("mode_name"):
		return
	var management_visible: bool = main.mode_name() == "SCREEN" and String(main.ui.screen_tab) == "経営"
	sync_assistant_suppression(management_visible)


## The illustration of an event (assets/ui/events/<event_id>.png), null when it has none.
static func picture_for(event_id: String) -> Texture2D:
	if event_id == "":
		return null
	if not _pictures.has(event_id):
		var path := PICTURE_DIR + event_id + ".png"
		_pictures[event_id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _pictures[event_id]


## イベント履歴 lines, newest first: 'DAY 3　近隣の工事（開催）' / '（見送り）' when the store was not open in its window /
## 'DAY 2　イベントなし'.
static func history_text(past: Array) -> String:
	var lines: Array[String] = []
	for h in past.slice(0, HISTORY_LINES):
		var name := String(h["name_ja"])
		lines.append("DAY %d　%s" % [int(h["day"]), "イベントなし" if name == "" else "%s（%s）" % [name, "開催" if h["held"] else "見送り"]])
	return "\n".join(lines)


func _render_effects(chips: Array) -> void:
	_effects.visible = not chips.is_empty()
	var key := ",".join(chips.map(func(c): return c["text"]))
	if key == _effects_key and _effects.get_child_count() == chips.size():
		return
	_effects_key = key
	for c in _effects.get_children():
		c.queue_free()
	for chip in chips:
		var l := Label.new()
		l.text = chip["text"]
		var good: bool = chip["good"]
		l.theme_type_variation = &"GoodLabel" if good else &"BadLabel"
		var box := UiTheme.chip_box(UiTheme.SUCCESS_GREEN if good else UiTheme.DANGER_RED)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		l.add_theme_stylebox_override("normal", box)
		_effects.add_child(l)
	_effects.visible = not chips.is_empty()


func _render_catalog(entries: Array) -> void:
	_list_title.visible = not entries.is_empty()
	var key := ",".join(entries.map(func(e): return "%s:%s" % [e["event_id"], e["state"]]))
	if key == _list_key:
		return
	_list_key = key
	for c in _list.get_children():
		c.queue_free()
	_cells.clear()
	for e in entries:
		var state := String(e["state"])
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.tooltip_text = EventText.catalog_tooltip(e)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.theme_type_variation = &"SubCardSelected" if state == "selected" else &"SubCard"
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.text = String(e["name_ja"])
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := Label.new()
		tag.text = STATE_JA.get(state, String(e["lock"]))
		tag.add_theme_font_size_override("font_size", 12)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match state:
			"selected":
				tag.theme_type_variation = &"AccentLabel"
			"candidate":
				tag.theme_type_variation = &"MutedLabel"
			_:
				panel.modulate = Color(1, 1, 1, 0.55)
				tag.theme_type_variation = &"MutedLabel"
		col.add_child(name_label)
		col.add_child(tag)
		panel.add_child(col)
		_list.add_child(panel)
		_cells[e["event_id"]] = {"panel": panel, "state": state, "tag": tag}
