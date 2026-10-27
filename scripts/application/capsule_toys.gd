class_name CapsuleToys
extends RefCounted
## Capsule toy machines, phase 1 (issue #139). A machine (capsule_toy_1 / _3 / _5) is a fixture whose slots hold
## capsule SKUs (one series per slot); restocking, ordering and the stock are those of any shelf. A customer turns
## it at the machine: the turn is paid there (a SALE row of its own, never at the till) and a customer who bought
## nothing else leaves without queueing. The prize of a turn follows from its sale id (data/capsule/
## capsule_series_v1.json: one in rare_one_in is the rare one); turns and rare prizes are counted per SKU
## (state.capsule_stats) and a rare prize is announced. In-game money only; no real-money draws.

const PATH := "res://data/capsule/capsule_series_v1.json"
const CATEGORY := "capsule_toy"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"series": []}
	return _data


static func series(sku_id: String) -> Dictionary:
	for s in data()["series"]:
		if s["sku_id"] == sku_id:
			return s
	return {}


## Is this SKU turned at a machine (paid there, not at the till)?
static func is_capsule(state: GameState, sku_id: String) -> bool:
	return String(state.products.get_sku(sku_id).get("category", "")) == CATEGORY


## The prize of one turn, from its sale id (the same sale always gives the same prize). -> {name, rare}.
static func prize_of(sku_id: String, sale_id: String) -> Dictionary:
	var s := series(sku_id)
	if s.is_empty():
		return {"name": "", "rare": false}
	var rng := Lcg32.new(sale_id.hash() & 0x7fffffff)   # seeded by the sale: no draw from the game's streams
	if rng.uniform_0_1() < 1.0 / maxf(float(s["rare_one_in"]), 1.0):
		return {"name": String(s["rare"]), "rare": true}
	var variants: Array = s["variants"]
	return {"name": String(variants[mini(int(rng.uniform_0_1() * variants.size()), variants.size() - 1)]), "rare": false}


## Counts a turn and announces a rare prize. -> the prize.
static func on_turned(state: GameState, sku_id: String, sale_id: String, customer_id: String, fixture_id: String) -> Dictionary:
	var prize := prize_of(sku_id, sale_id)
	if not state.capsule_stats.has(sku_id):
		state.capsule_stats[sku_id] = {"turns": 0, "rare": 0}
	var st: Dictionary = state.capsule_stats[sku_id]
	st["turns"] = int(st["turns"]) + 1
	if bool(prize["rare"]):
		st["rare"] = int(st["rare"]) + 1
		state.emit_event("CAPSULE_RARE", {"customer_id": customer_id, "sku_id": sku_id, "fixture_id": fixture_id, "prize": prize["name"],
			"name": state.products.get_sku(sku_id).get("display_name", "")})
	return prize
