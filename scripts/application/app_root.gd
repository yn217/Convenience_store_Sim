extends Node
## Boot + dependency injection (01 §5). Starts paused in SETUP with an empty store.

const BALANCE_PATH := "res://data/balance/mvp_v1.json"
const FIXTURES_PATH := "res://data/fixtures/mvp_v1.json"
const PRODUCTS_PATH := "res://data/products/mvp_v1.json"
const REQUIRED_BALANCE_KEYS := [
	"store_width_tiles", "store_height_tiles", "starting_cash_yen", "starting_reputation",
]
const DEFAULT_SEEDS := {"arrivals": 1234, "purchases": 5678, "visuals": 9012, "events": 345678}

var state: GameState
var commands: GameCommands
var runner: SimulationRunner
## Where save files live (tests point this at a scratch folder).
var save_dir: String = SaveStore.DIR
var _balance: Dictionary
var _fixtures: FixtureCatalog
var _products: ProductCatalog


func _ready() -> void:
	var balance := _load_balance()
	if balance.is_empty():
		push_error("balance config invalid: " + BALANCE_PATH)
		return
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES_PATH))
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string(PRODUCTS_PATH))
	var problems := fixtures.errors + products.errors + fixtures.product_errors(products)
	if not problems.is_empty():
		push_error("master data invalid: " + str(problems))
		return
	_balance = balance
	_fixtures = fixtures
	_products = products
	state = GameState.from_balance(balance, DEFAULT_SEEDS, fixtures, products)
	commands = GameCommands.new(state)
	runner = SimulationRunner.new(state)
	var world := _world()
	if world != null:
		world.fixture_catalog = fixtures
		world.selection_changed.connect(_on_selection_changed)
	var builder := get_node_or_null("../BuildController")
	if builder != null and world != null:
		builder.setup(self, world, fixtures, products)
	if world != null:
		world.pause_toggle_requested.connect(toggle_pause)
	var hud := get_node_or_null("../Layout/TopHUD")
	if hud != null and hud.has_signal("speed_requested"):
		hud.speed_requested.connect(set_speed)
	var business := get_node_or_null("../BusinessController")
	if business != null:
		business.setup(self, balance)
	var saver := get_node_or_null("../SaveController")
	if saver != null:
		saver.setup(self)
	var reporter := get_node_or_null("../ReportController")
	if reporter != null:
		reporter.setup(self)
	var stocker := get_node_or_null("../StockController")
	if stocker != null:
		stocker.setup(self, products, fixtures)
	var pricer := get_node_or_null("../PriceController")
	if pricer != null:
		pricer.setup(self, products)
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


## The only route from the UI to the Domain: runs one command, republishes on success.
func run_command(command: Dictionary) -> CommandResult:
	match StringName(command.get("kind", &"")):
		&"SAVE_GAME":
			return _save_game(String(command.get("slot_id", "")))
		&"LOAD_GAME":
			return _load_game(String(command.get("slot_id", "")), bool(command.get("use_backup", false)))
	var result := commands.execute(command)
	if result.ok:
		_publish_snapshot()
	return result


## HUD speed buttons and the P key. The answer (e.g. "no clock in SETUP") goes to the message line.
func set_speed(speed: int) -> CommandResult:
	var r := run_command({"command_id": "ui_speed_%d_%d" % [Time.get_ticks_usec(), speed], "kind": &"SET_SPEED", "speed": speed})
	_tell(r)
	_publish_snapshot()   # re-syncs the pressed state of the speed buttons after a refusal
	return r


## P: stop the clock, or resume at the last non-zero speed. Never allows construction.
func toggle_pause() -> CommandResult:
	if state.speed_setting == 0:
		return set_speed(state.last_nonzero_speed)
	return set_speed(0)


func _tell(r: CommandResult) -> void:
	var builder := get_node_or_null("../BuildController")
	if builder != null and builder.has_method("say"):
		builder.say("" if r.ok else CommandMessages.text(r.code, r.message_key))


## SAVE_GAME: writes the current state to a slot (temp file, then replace; the previous save is
## kept as the backup). The game state is not changed.
func _save_game(slot_id: String) -> CommandResult:
	if not SaveStore.SLOTS.has(slot_id):
		return CommandResult.failure(&"INVALID_OPERATION", state.revision, &"save_failed")
	var stamp := Time.get_datetime_string_from_system(true) + "Z"
	var written := SaveStore.write(slot_id, SaveGame.to_dict(state, slot_id, stamp), save_dir)
	if not written["ok"]:
		return CommandResult.failure(&"INVALID_OPERATION", state.revision, &"save_failed")
	var events: Array[String] = []
	return CommandResult.success(state.revision, events)


## LOAD_GAME: reads and fully validates the file into a new GameState first; only a valid file
## replaces the running state. Any problem leaves the current game exactly as it is.
func _load_game(slot_id: String, use_backup: bool) -> CommandResult:
	var read := SaveStore.read(slot_id, use_backup, save_dir)
	if not read["ok"]:
		var key := &"save_empty" if read["error"] == "no_save" else &"save_corrupt"
		return CommandResult.failure(&"INVALID_OPERATION", state.revision, key)
	var loaded := SaveGame.from_dict(read["data"], _balance, _fixtures, _products)
	if not loaded["ok"]:
		var key := &"save_unsupported" if loaded["unsupported_version"] else &"save_invalid"
		return CommandResult.failure(&"INVALID_OPERATION", state.revision, key)
	var fresh: GameState = loaded["state"]
	fresh.revision = state.revision + 1
	state = fresh
	commands = GameCommands.new(state)
	runner = SimulationRunner.new(state)
	_publish_snapshot()
	var events: Array[String] = []
	return CommandResult.success(state.revision, events)


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
	var builder := get_node_or_null("../BuildController")
	if builder != null and builder.has_method("apply_snapshot") and builder.is_node_ready():
		builder.apply_snapshot(snap)
	var business := get_node_or_null("../BusinessController")
	if business != null and business.has_method("apply_snapshot") and business.is_node_ready() and business.get("_tiers") != null and not business._tiers.is_empty():
		business.apply_snapshot(snap)
	var reporter := get_node_or_null("../ReportController")
	if reporter != null and reporter.has_method("apply_snapshot") and reporter.is_node_ready() and reporter.get("_chart") != null:
		reporter.apply_snapshot(snap)
	var stocker := get_node_or_null("../StockController")
	if stocker != null and stocker.has_method("apply_snapshot") and stocker.is_node_ready() and stocker.get("_products") != null:
		stocker.apply_snapshot(snap)
	var pricer := get_node_or_null("../PriceController")
	if pricer != null and pricer.has_method("apply_snapshot") and pricer.is_node_ready() and pricer.get("_products") != null:
		pricer.apply_snapshot(snap)
	var hud := get_node_or_null("../Layout/TopHUD")
	if hud != null and hud.has_method("apply_snapshot"):
		hud.apply_snapshot(snap)
