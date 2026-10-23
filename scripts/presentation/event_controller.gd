class_name EventController
extends Node
## "今日のイベント" section of the inspector (SCR-11): the day's event, its window, effect and what is
## still missing to profit from it. Shows what EventService decided; it never draws or applies anything.

var _status: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	var title := Label.new()
	title.text = "今日のイベント"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)


func apply_snapshot(snap: Dictionary) -> void:
	_status.text = "\n".join(EventText.lines(snap.get("gameplay_event", {"status": "no_data"}), int(snap.get("time_sec", 0)), snap.get("stocked_categories", [])))
