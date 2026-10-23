extends Node
## Boot + dependency injection (01 §5). Starts paused in SETUP with an empty store.

const BALANCE_PATH := "res://data/balance/mvp_v1.json"
const REQUIRED_BALANCE_KEYS := [
	"store_width_tiles", "store_height_tiles", "starting_cash_yen", "starting_reputation",
]
const DEFAULT_SEEDS := {"arrivals": 1234, "purchases": 5678, "visuals": 9012}

var state: GameState
var commands: GameCommands
var runner: SimulationRunner


func _ready() -> void:
	var balance := _load_balance()
	if balance.is_empty():
		push_error("balance config invalid: " + BALANCE_PATH)
		return
	state = GameState.from_balance(balance, DEFAULT_SEEDS)
	commands = GameCommands.new(state)
	runner = SimulationRunner.new(state)
	var world := _world()
	if world != null:
		world.selection_changed.connect(_on_selection_changed)
	_publish_snapshot()


func _process(delta: float) -> void:
	if runner == null:
		return
	if runner.process_frame(delta) > 0:
		_publish_snapshot()


func _load_balance() -> Dictionary:
	var file := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	for key in REQUIRED_BALANCE_KEYS:
		if not parsed.has(key):
			return {}
	return parsed


func _world() -> Node:
	return get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")


func _on_selection_changed(tile: Vector2i) -> void:
	var main := get_parent()
	if main != null and main.has_method("show_selection"):
		main.show_selection(tile)


func _publish_snapshot() -> void:
	var snap := state.snapshot()
	var world := _world()
	if world != null and world.has_method("apply_snapshot"):
		world.apply_snapshot(snap)
	var hud := get_node_or_null("../Layout/TopHUD")
	if hud != null and hud.has_method("apply_snapshot"):
		hud.apply_snapshot(snap)
