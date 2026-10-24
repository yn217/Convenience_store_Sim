class_name OverlayController
extends Node
## "表示" section of the inspector (#24): the three overlay modes, the list of objects stacked under the
## last click (click again to reach the next one), and the selected customer. Pure view state: switching
## modes never touches the game state, the selection or the build ghost.

var _world: Node2D
var _buttons: Dictionary = {}
var _stack: Label
var _customer: Label
var _hint: Label

@onready var _body: VBoxContainer = $"../Layout/MainArea/FixtureInspector/Scroll/Body"


func _ready() -> void:
	_world = get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	var title := Label.new()
	title.text = "表示モード (O)"
	title.add_theme_font_size_override("font_size", 20)
	_body.add_child(title)
	var row := HBoxContainer.new()
	var group := ButtonGroup.new()
	for m in OverlayModel.MODE_NAMES:
		var b := Button.new()
		b.text = OverlayModel.MODE_NAMES[m]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): set_mode(m))
		row.add_child(b)
		_buttons[m] = b
	_buttons[OverlayModel.Mode.NORMAL].button_pressed = true
	_body.add_child(row)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = "配置: グリッド・通れない場所・客側 / 情報: 在庫と本日の売れ数"
	_body.add_child(_hint)
	var camera_hint := Label.new()
	camera_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_hint.text = "カメラ: ホイール=拡大縮小 / 中ドラッグ・Space+ドラッグ=移動 / F=店舗全体 / Shift+F=店内表示と全体表示を切替"
	_body.add_child(camera_hint)
	_stack = Label.new()
	_stack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_stack)
	_customer = Label.new()
	_customer.theme_type_variation = &"CardTitle"   # the customer's line sits inside the inspector window, as a detail
	_customer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_customer)
	if _world != null:
		_world.overlay_changed.connect(func(m): _buttons[m].button_pressed = true)
		_world.pick_candidates_changed.connect(show_stack)
		_world.customer_selected.connect(func(_id): refresh_customer())


func set_mode(m: int) -> void:
	if _world != null:
		_world.set_overlay_mode(m)


func show_stack(labels: Array) -> void:
	_stack.text = "" if labels.is_empty() else "重なっている対象（同じ場所をもう一度クリックで切替）\n" + "\n".join(labels)


func _process(_delta: float) -> void:
	if _world != null and _world.selected_customer != "":
		refresh_customer()   # the action changes every step; the text is cheap


func refresh_customer() -> void:
	if _world == null or _world.selected_customer == "":
		_customer.text = ""
		return
	for c in _world.customers:
		if c["customer_id"] == _world.selected_customer:
			_customer.text = "\n".join(OverlayModel.customer_panel_lines(c, _shelf_name(String(c.get("fixture_id", "")))))   # #141
			return
	_customer.text = ""


## Display name of a placed fixture (its shelf or register), "" when it is not on the layout.
func _shelf_name(fixture_id: String) -> String:
	if fixture_id == "" or _world.fixture_catalog == null:
		return ""
	for inst in _world.fixtures:
		if inst["instance_id"] == fixture_id:
			return String(_world.fixture_catalog.get_type(inst["type_id"]).get("display_name", ""))
	return ""
