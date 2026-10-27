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


## A limited series (#139 phase 2) is on in its window of days: (day % every_days) < for_days. Others always are.
static func in_season(sku_id: String, day: int) -> bool:
	var lim: Dictionary = series(sku_id).get("limited", {})
	if lim.is_empty():
		return true
	return posmod(day, int(lim["every_days"])) < int(lim["for_days"])


## Can this SKU be ordered today? A limited series only in its window.
static func orderable(state: GameState, sku_id: String) -> bool:
	return in_season(sku_id, state.day)


## Extra pull of a capsule SKU today: a limited series in its window (1 otherwise).
static func pull(state: GameState, sku_id: String) -> float:
	var lim: Dictionary = series(sku_id).get("limited", {})
	if lim.is_empty() or not in_season(sku_id, state.day):
		return 1.0
	return float(lim.get("pull", 1.0))


## Days until a limited series is on again (0 = on today, -1 = not limited).
static func days_to_season(sku_id: String, day: int) -> int:
	var lim: Dictionary = series(sku_id).get("limited", {})
	if lim.is_empty():
		return -1
	var k := posmod(day, int(lim["every_days"]))
	return 0 if k < int(lim["for_days"]) else int(lim["every_days"]) - k


## After a turn: a machine slot left with nothing of this series is announced (refill it).
static func check_empty(state: GameState, fixture_id: String, sku_id: String) -> void:
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and loc["fixture_id"] == fixture_id and seg["sku_id"] == sku_id and int(seg["physical_qty"]) > 0:
			return
	state.emit_event("CAPSULE_EMPTY", {"fixture_id": fixture_id, "sku_id": sku_id, "name": state.products.get_sku(sku_id).get("display_name", "")})


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
