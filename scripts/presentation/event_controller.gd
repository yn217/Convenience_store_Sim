class_name EventController
extends Node
## "今日のイベント" section of the inspector (SCR-11): the day's event, its window, effect and what is
## still missing to profit from it. Shows what EventService decided; it never draws or applies anything.
## Under the text (#31 mockup 本日の地域イベント): 効果の内訳 as chips, and 本日のイベント一覧 with every event of the master
## data marked 選択中 / 候補 / its lock (hover for the details), and イベント履歴: the last HISTORY_LINES days, newest first.

const LIST_COLUMNS := 3
const STATE_JA := {"selected": "選択中", "candidate": "候補"}
const HISTORY_LINES := 7
const DOWN_TEXT := Color("ff8a8e")   # a lowered effect: DANGER_RED is too dark for text on the card

var _status: Label
var _effects: HFlowContainer
var _list_title: Label
var _list: GridContainer
var _list_key := ""
var _cells: Dictionary = {}   # event id -> {panel, state}
var _effects_key := ""
var _history_title: Label
var _history: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	var title := Label.new()
	title.text = "今日のイベント"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
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
	_render_effects(EventText.effect_chips(view) if String(view.get("status", "")) in ["scheduled", "active", "ended", "missed"] else [])
	_render_catalog(snap.get("event_catalog", []))
	var past: Array = snap.get("event_history", [])
	_history.text = history_text(past)
	_history.visible = not past.is_empty()
	_history_title.visible = not past.is_empty()


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
		l.add_theme_color_override("font_color", UiTheme.SUCCESS_GREEN if good else DOWN_TEXT)
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
		var edge: Color = UiTheme.WARM if state == "selected" else UiTheme.BORDER
		var box := UiTheme.chip_box(edge)
		box.set_corner_radius_all(8)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		if state == "selected":
			box.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", box)
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
				tag.add_theme_color_override("font_color", UiTheme.WARM)
			"candidate":
				tag.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
			_:
				panel.modulate = Color(1, 1, 1, 0.55)
				tag.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
		col.add_child(name_label)
		col.add_child(tag)
		panel.add_child(col)
		_list.add_child(panel)
		_cells[e["event_id"]] = {"panel": panel, "state": state, "tag": tag}
