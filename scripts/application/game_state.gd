class_name GameState
extends RefCounted
## Mutable runtime state. Only GameCommands / SimulationRunner write to it;
## presenters receive snapshot() copies (01 §2, §6).

const SCHEMA_VERSION := 1
const SETUP := &"SETUP"
const OPEN := &"OPEN"
const CLOSING := &"CLOSING"
const PAYMENT_BLOCKED := &"PAYMENT_BLOCKED"
const SPEED_OPTIONS: Array[int] = [0, 1, 2, 4]
## Fixed west-wall door (00_BASELINE §2.1); players cannot move or remove it.
const ENTRANCE_TILES: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 6)]

var revision: int = 0
var time_sec: int = 0
var day: int = 0
var business_state: StringName = SETUP
var speed_setting: int = 0
var last_nonzero_speed: int = 1
var applied_command_ids: Array[String] = []
var rng_states: Dictionary = {}
var reputation: int = 0
var fixtures := FixtureCatalog.new()
var products := ProductCatalog.new()
var grid: StoreGrid
var ledger := Ledger.new()
var layout_history := LayoutHistory.new()
## Stock rows (see StockSegment) and active customer reservations; filled by #11/#17.
var inventory_segments: Array[Dictionary] = []
var reservations: Array[Dictionary] = []
var next_fixture_seq: int = 0
var next_lot_seq: int = 0
var next_segment_seq: int = 0
## Player sell prices that differ from the SKU default {sku_id: yen}. Never touches lot costs
## or already snapshotted reservations/ledger rows.
var product_price_overrides: Dictionary = {}

var store_width: int:
	get: return grid.width
var store_height: int:
	get: return grid.height
var entrance_tiles: Array[Vector2i]:
	get: return grid.entrance_tiles
var cash_yen: int:
	get: return ledger.cash_yen


static func from_balance(balance: Dictionary, seeds: Dictionary, fixture_catalog: FixtureCatalog = null, product_catalog: ProductCatalog = null) -> GameState:
	var s := GameState.new()
	if fixture_catalog != null:
		s.fixtures = fixture_catalog
	if product_catalog != null:
		s.products = product_catalog
	s.grid = StoreGrid.create("store_001", int(balance["store_width_tiles"]), int(balance["store_height_tiles"]), ENTRANCE_TILES.duplicate())
	s.ledger.cash_yen = int(balance["starting_cash_yen"])
	s.reputation = int(balance["starting_reputation"])
	s.rng_states = seeds.duplicate()
	return s


func sell_price(sku_id: String) -> int:
	if product_price_overrides.has(sku_id):
		return int(product_price_overrides[sku_id])
	return int(products.get_sku(sku_id).get("default_sell_price_yen", 0))


## Units of `sku_id` in the backroom that no reservation holds.
func backroom_available(sku_id: String) -> int:
	var n := 0
	for seg in inventory_segments:
		if seg["sku_id"] == sku_id and seg["location"]["kind"] == "BACKROOM":
			n += int(seg["physical_qty"]) - int(seg["reserved_qty"])
	return n


func snapshot() -> Dictionary:
	var ids := grid.instances.keys()
	ids.sort()
	var placed: Array = []
	for id in ids:
		placed.append(grid.instances[id].duplicate())
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"time_sec": time_sec,
		"day": day,
		"business_state": String(business_state),
		"speed_setting": speed_setting,
		"store_width": grid.width,
		"store_height": grid.height,
		"entrance_tiles": grid.entrance_tiles.duplicate(),
		"fixtures": placed,
		"product_price_overrides": product_price_overrides.duplicate(),
		"backroom_stock": _backroom_stock(),
		"shelf_skus": _shelf_skus(),
		"shelf_stock": ShelfDisplay.stock_by_slot(inventory_segments),
		"can_undo": layout_history.can_undo(),
		"can_redo": layout_history.can_redo(),
		"cash_yen": ledger.cash_yen,
		"reputation": reputation,
		"rng_states": rng_states.duplicate(),
	}


func _backroom_stock() -> Dictionary:
	var out := {}
	for seg in inventory_segments:
		if seg["location"]["kind"] == "BACKROOM":
			out[seg["sku_id"]] = int(out.get(seg["sku_id"], 0)) + int(seg["physical_qty"])
	return out


## {fixture_id: {slot_id: sku_id}} for slots that currently hold stock.
func _shelf_skus() -> Dictionary:
	var out := {}
	for seg in inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and int(seg["physical_qty"]) > 0:
			if not out.has(loc["fixture_id"]):
				out[loc["fixture_id"]] = {}
			out[loc["fixture_id"]][loc["slot_id"]] = seg["sku_id"]
	return out
