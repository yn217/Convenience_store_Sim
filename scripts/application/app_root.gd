extends Node
## Boot + dependency injection (01 §5). Starts paused in SETUP with an empty store.

const BALANCE_PATH := "res://data/balance/mvp_v1.json"
const FIXTURES_PATH := "res://data/fixtures/mvp_v1.json"
const PRODUCTS_PATH := "res://data/products/mvp_v1.json"
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
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES_PATH))
	var products := ProductCatalog.from_json_text(FileAccess.get_file_as_string(PRODUCTS_PATH))
	var problems := fixtures.errors + products.errors + fixtures.product_errors(products)
	if not problems.is_empty():
		push_error("master data invalid: " + str(problems))
		return
	state = GameState.from_balance(balance, DEFAULT_SEEDS, fixtures, products)
	commands = GameCommands.new(state)
	runner = SimulationRunner.new(state)
	var world := _world()
	if world != null:
		world.fixture_catalog = fixtures
		world.selection_changed.connect(_on_selection_changed)
	var builder := get_node_or_null("../BuildController")
	if builder != null and world != null:
		builder.setup(self, world, fixtures)
	var business := get_node_or_null("../BusinessController")
	if business != null:
		business.setup(self, balance)
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
	var result := commands.execute(command)
	if result.ok:
		_publish_snapshot()
	return result


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
