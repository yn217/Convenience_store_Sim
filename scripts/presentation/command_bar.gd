class_name CommandBar
extends PanelContainer
## Bottom toolbar (mockup A/B): the everyday selection commands in one row. Every button forwards to the
## inspector button that already owns the behaviour, so rules, texts and disabled states live in one place.

const ACTIONS := [
	{"label": "移動", "target": "MoveButton"},
	{"label": "回転", "target": "RotateButton"},
	{"label": "撤去", "target": "RemoveButton"},
]

var _pairs: Array = []   # [bar button, inspector button]
var _mode_button: Button


func _ready() -> void:
	name = "CommandBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var layout := _layout()
	for a in ACTIONS:
		var target := layout.find_child(a["target"], true, false) as Button   # the inspector's button (sections are cards now)
		if target == null:
			continue
		var b := Button.new()
		b.text = a["label"]
		b.focus_mode = Control.FOCUS_NONE
		CommandGrid.slim_button(b)
		b.pressed.connect(func(): target.pressed.emit())
		row.add_child(b)
		_pairs.append([b, target])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_mode_button = Button.new()
	_mode_button.text = "表示切替 (O)"
	_mode_button.focus_mode = Control.FOCUS_NONE
	CommandGrid.slim_button(_mode_button)
	_mode_button.pressed.connect(_cycle_overlay)
	row.add_child(_mode_button)
	sync_state()


func _process(_delta: float) -> void:
	sync_state()


func sync_state() -> void:
	for p in _pairs:
		(p[0] as Button).disabled = (p[1] as Button).disabled


func _cycle_overlay() -> void:
	var world := _layout().get_node_or_null("MainArea/StoreViewport/SubViewport/StoreWorld")
	if world != null and world.has_method("cycle_overlay_mode"):
		world.cycle_overlay_mode()


## The Layout VBoxContainer that holds the screen's side panels. The bar sits in a row below it, so walk up.
func _layout() -> Node:
	var n := get_parent()
	while n != null and n.name != "Layout":
		n = n.get_parent()
	return n
