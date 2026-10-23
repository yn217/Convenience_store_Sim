extends Node
## Build UI controller (04 §2): palette / inspector / store clicks -> commands.
## Presentation only: it asks AppRoot to run commands and previews with the read-only
## validate_placement; it never edits GameState. UI modes: OBSERVE / PLACE / MOVE (never mixed).

const NO_TILE := Vector2i(-1, -1)
const NO_ID := ""

var mode: int = 0
var pending_type: String = ""
var moving_id: String = ""
var preview_rotation: int = 0
var selected_fixture_id: String = ""

var _app: Node
var _world: Node2D
var _catalog: FixtureCatalog
var _snapshot: Dictionary = {}
var _fixture_at: Dictionary = {}
var _instances: Dictionary = {}
var _seq: int = 0
var _catalog_view: BuildCatalog
var _products: ProductCatalog

@onready var _type_list: GridContainer = $"../Layout/MainArea/BuildPalette/Body/Scroll/TypeList"
@onready var _undo: Button = $"../Layout/MainArea/BuildPalette/Body/UndoRow/UndoButton"
@onready var _redo: Button = $"../Layout/MainArea/BuildPalette/Body/UndoRow/RedoButton"
@onready var _preview_label: Label = $"../Layout/MainArea/BuildPalette/Body/PreviewLabel"
@onready var _status_label: Label = $"../Layout/MainArea/BuildPalette/Body/StatusLabel"
@onready var _fixture_label: Label = $"../Layout/MainArea/FixtureInspector/Scroll/Body/Details/FixtureLabel"
@onready var _move_button: Button = $"../Layout/MainArea/FixtureInspector/Scroll/Body/Actions/MoveButton"
@onready var _rotate_button: Button = $"../Layout/MainArea/FixtureInspector/Scroll/Body/Actions/RotateButton"
@onready var _remove_button: Button = $"../Layout/MainArea/FixtureInspector/Scroll/Body/Actions/RemoveButton"
@onready var _remove_dialog: ConfirmationDialog = $"../RemoveDialog"


func setup(app: Node, world: Node2D, catalog: FixtureCatalog, products: ProductCatalog = null) -> void:
	_app = app
	_products = products
	_world = world
	_catalog = catalog
	_catalog_view = BuildCatalog.new()
	_catalog_view.setup(_type_list, _type_list.get_parent(), catalog, begin_place)
	_undo.pressed.connect(func(): run_simple(&"UNDO_LAYOUT"))
	_redo.pressed.connect(func(): run_simple(&"REDO_LAYOUT"))
	_move_button.pressed.connect(begin_move)
	_rotate_button.pressed.connect(rotate_selected)
	_remove_button.pressed.connect(request_remove)
	_remove_dialog.confirmed.connect(confirm_remove)
	_world.tile_clicked.connect(on_tile_clicked)
	_world.hover_changed.connect(func(_t): _update_ghost())
	_world.selection_changed.connect(func(_t): _refresh_inspector())
	_world.cancel_requested.connect(cancel_mode)
	_world.rotate_requested.connect(rotate_preview)
	_world.delete_requested.connect(request_remove)
	_world.undo_requested.connect(func(): run_simple(&"UNDO_LAYOUT"))
	_world.redo_requested.connect(func(): run_simple(&"REDO_LAYOUT"))


func apply_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_instances.clear()
	_fixture_at.clear()
	for inst in snap.get("fixtures", []):
		_instances[inst["instance_id"]] = inst
		var def := _catalog.get_type(inst["type_id"])
		for c in StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"]):
			_fixture_at[c] = inst["instance_id"]
	if mode != 0 and not is_setup():
		cancel_mode()
	if moving_id != NO_ID and not _instances.has(moving_id):
		cancel_mode()
	if _catalog_view != null:
		_catalog_view.set_enabled(is_setup())
		_catalog_view.set_cash(int(snap.get("cash_yen", 0)))
	_undo.disabled = not (is_setup() and snap.get("can_undo", false))
	_redo.disabled = not (is_setup() and snap.get("can_redo", false))
	_refresh_inspector()
	_update_ghost()


func is_setup() -> bool:
	return _snapshot.get("business_state", "SETUP") == "SETUP"


# ------------------------------------------------------------------ modes

func begin_place(type_id: String) -> void:
	if not is_setup():
		_say(CommandMessages.text(&"NOT_IN_SETUP", &"construction_needs_setup"))
		return
	pending_type = type_id
	moving_id = NO_ID
	preview_rotation = 0
	_enter_mode(1)
	_say("「%s」を配置します。クリックで確定、R で回転、Esc でキャンセル" % _catalog.get_type(type_id)["display_name"])


func begin_move() -> void:
	if selected_fixture_id == NO_ID or not is_setup():
		return
	var inst: Dictionary = _instances[selected_fixture_id]
	moving_id = selected_fixture_id
	pending_type = inst["type_id"]
	preview_rotation = inst["rotation"]
	_enter_mode(2)
	_say("移動先をクリックしてください。R で回転、Esc でキャンセル")


func cancel_mode() -> void:
	pending_type = ""
	moving_id = NO_ID
	_enter_mode(0)


func _enter_mode(m: int) -> void:
	mode = m
	_world.mode = m
	if _catalog_view != null:
		_catalog_view.set_selected(pending_type if m == 1 else "")
	_update_ghost()


func rotate_preview() -> void:
	if mode == 0:
		return
	preview_rotation = (preview_rotation + 1) % 4
	_update_ghost()


# ------------------------------------------------------------------ commands

func _next_id() -> String:
	_seq += 1
	return "ui_%d_%d" % [Time.get_ticks_msec(), _seq]


func run_simple(kind: StringName) -> CommandResult:
	return _run({"command_id": _next_id(), "kind": kind})


func on_tile_clicked(tile: Vector2i) -> void:
	if mode == 1:
		_run({"command_id": _next_id(), "kind": &"PLACE_FIXTURE", "type_id": pending_type, "x": tile.x, "y": tile.y, "rotation": preview_rotation})
	elif mode == 2:
		var r := _run({"command_id": _next_id(), "kind": &"MOVE_FIXTURE", "instance_id": moving_id, "x": tile.x, "y": tile.y, "rotation": preview_rotation})
		if r.ok:
			cancel_mode()


func rotate_selected() -> void:
	if selected_fixture_id == NO_ID:
		return
	var inst: Dictionary = _instances[selected_fixture_id]
	_run({"command_id": _next_id(), "kind": &"MOVE_FIXTURE", "instance_id": inst["instance_id"], "x": inst["x"], "y": inst["y"], "rotation": (inst["rotation"] + 1) % 4})


func request_remove() -> void:
	if selected_fixture_id == NO_ID or not is_setup():
		return
	_remove_dialog.dialog_text = "「%s」を撤去しますか？ 費用は戻りません（棚の商品はバックヤードへ移ります）。" % _catalog.get_type(_instances[selected_fixture_id]["type_id"])["display_name"]
	_remove_dialog.popup_centered()


func confirm_remove() -> void:
	if selected_fixture_id == NO_ID:
		return
	_run({"command_id": _next_id(), "kind": &"REMOVE_FIXTURE", "instance_id": selected_fixture_id})


const OK_TEXT := {
	&"PLACE_FIXTURE": "設置しました", &"MOVE_FIXTURE": "移動しました", &"REMOVE_FIXTURE": "撤去しました",
	&"UNDO_LAYOUT": "元に戻しました（設置は購入費も戻ります）", &"REDO_LAYOUT": "やり直しました",
}


func _run(cmd: Dictionary) -> CommandResult:
	var r: CommandResult = _app.run_command(cmd)
	if r.ok:
		_say(OK_TEXT.get(cmd["kind"], "実行しました"))
	else:
		_say(CommandMessages.text(r.code, r.message_key))
	return r


func _say(text: String) -> void:
	_status_label.text = text


## Message line shared with the other panels (speed changes, pause).
func say(text: String) -> void:
	_say(text)


# ------------------------------------------------------------------ views

func _update_ghost() -> void:
	if mode == 0 or _world.hover_tile == NO_TILE:
		_world.clear_ghost()
		_preview_label.text = ""
		return
	var t: Vector2i = _world.hover_tile
	var res: PlacementResult = _app.commands.validate_placement(pending_type, t.x, t.y, preview_rotation, moving_id)
	_world.set_ghost(res.cells, res.access_cells, res.ok, res.queue_cells)
	if res.ok:
		_preview_label.text = "設置できます ¥%s" % GameHud.format_yen(res.cost_yen).trim_prefix("¥") if mode == 1 else "移動できます（費用なし）"
	else:
		_preview_label.text = CommandMessages.text(res.code, res.message_key)


func _refresh_inspector() -> void:
	var tile: Vector2i = _world.selected_tile if _world != null else NO_TILE
	selected_fixture_id = _fixture_at.get(tile, NO_ID)
	var has := selected_fixture_id != NO_ID
	_move_button.disabled = not (has and is_setup())
	_rotate_button.disabled = not (has and is_setup())
	_remove_button.disabled = not (has and is_setup())
	if not has:
		_fixture_label.text = "什器なし" if tile != NO_TILE else ""
		return
	var inst: Dictionary = _instances[selected_fixture_id]
	var def := _catalog.get_type(inst["type_id"])
	_fixture_label.text = "%s\n位置 (%d, %d)  向き %d°\n占有 %d×%d  価格 %s\nアクセス面 %s" % [
		def["display_name"], inst["x"], inst["y"], inst["rotation"] * 90, def["footprint"]["w"], def["footprint"]["h"],
		GameHud.format_yen(def["placement_cost_yen"]),
		",".join(def["access_edges"].map(func(e): return PlacementRules.rotate_edge(e, inst["rotation"]))),
	]
	_fixture_label.text += _slot_lines(inst, def)


## One line per shelf slot: what is on it, how full, and the selling price against the unit cost.
func _slot_lines(inst: Dictionary, def: Dictionary) -> String:
	if def["shelf_slots"].is_empty() or _products == null:
		return ""
	var held: Dictionary = _snapshot.get("shelf_stock", {}).get(inst["instance_id"], {})
	var skus: Dictionary = _snapshot.get("shelf_skus", {}).get(inst["instance_id"], {})
	var overrides: Dictionary = _snapshot.get("product_price_overrides", {})
	var out := "\n棚の中身"
	for slot in def["shelf_slots"]:
		var sid: String = slot["slot_id"]
		if not skus.has(sid):
			out += "\n%s: 空き（容量 %d）" % [sid, slot["capacity_units"]]
			continue
		var sku := _products.get_sku(skus[sid])
		var price := int(overrides.get(skus[sid], sku["default_sell_price_yen"]))
		out += "\n%s: %s %d/%d ・売価 %s（原価 %s）" % [sid, sku["display_name"], int(held.get(sid, 0)), slot["capacity_units"], GameHud.format_yen(price), GameHud.format_yen(int(sku["purchase_cost_yen"]))]
	return out
