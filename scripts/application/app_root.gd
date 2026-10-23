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


func _publish_snapshot() -> void:
	var snap := state.snapshot()
	var world := get_node_or_null("../MainArea/StoreViewport/SubViewport/StoreWorld")
	if world != null and world.has_method("apply_snapshot"):
		world.apply_snapshot(snap)
	var label := get_node_or_null("../GameHUD/StateLabel") as Label
	if label != null:
		label.text = "空店舗 %d×%d / %s / speed %d / 現金 %d円" % [
			snap["store_width"], snap["store_height"], snap["business_state"],
			snap["speed_setting"], snap["cash_yen"]]
