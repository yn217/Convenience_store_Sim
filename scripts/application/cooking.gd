class_name Cooking
extends RefCounted
## Made-to-order goods, phase 1 (issue #131: soft serve and frappé). The machine holds the mix as its stock
## (ordered and restocked like any shelf, it keeps 2 days and is wasted after); a customer who wants one waits at
## the machine while it is made — prep_game_seconds of data/cooking/prep_v1.json, added to the time at the shelf —
## then takes it and pays at the till. Other goods have no making time. #130 phase 1: a pizza is baked to order at
## the pizza oven the same way; fresh bread is baked into the bakery oven's trays when restocked and keeps 8 hours.

const PATH := "res://data/cooking/prep_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"prep_game_seconds": {}}
	return _data


## Game seconds a lot of this category bakes in its oven before it goes on sale (0: no baking, #130 phase 2).
static func bake_seconds(category: String) -> int:
	return int((data().get("bake", {}) as Dictionary).get(category, {}).get("bake_game_seconds", 0))


## Shelf life of a baked lot from the moment it comes out of the oven.
static func shelf_life(category: String) -> int:
	return int((data().get("bake", {}) as Dictionary).get(category, {}).get("shelf_life_seconds", 0))


## Lots whose baking is over go on sale (location OVEN -> FIXTURE) and keep their shelf life from now on.
## -> the units that came out.
static func finish_bakes(state: GameState) -> int:
	var out := 0
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] != "OVEN" or int(loc["ready_at_sec"]) > state.time_sec:
			continue
		seg["location"] = {"kind": "FIXTURE", "fixture_id": loc["fixture_id"], "slot_id": loc["slot_id"]}
		var life := shelf_life(String(state.products.get_sku(seg["sku_id"]).get("category", "")))
		if life > 0:
			seg["expires_at_sec"] = state.time_sec + life
		state.bakes_pending = maxi(state.bakes_pending - 1, 0)
		out += int(seg["physical_qty"])
		state.emit_event("BAKE_DONE", {"fixture_id": loc["fixture_id"], "sku_id": seg["sku_id"], "qty": int(seg["physical_qty"]),
			"name": state.products.get_sku(seg["sku_id"]).get("display_name", "")})
	return out


## Lots still in the ovens. -> {fixture_id: {qty, ready_in_sec (the soonest)}}.
static func baking(state: GameState) -> Dictionary:
	var out := {}
	if state.bakes_pending <= 0:
		return out
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "OVEN":
			var v: Dictionary = out.get(loc["fixture_id"], {"qty": 0, "ready_in_sec": 1 << 30})
			v["qty"] = int(v["qty"]) + int(seg["physical_qty"])
			v["ready_in_sec"] = mini(int(v["ready_in_sec"]), maxi(int(loc["ready_at_sec"]) - state.time_sec, 0))
			out[loc["fixture_id"]] = v
	return out


## Game seconds to make one item of this category (0 for goods taken off a shelf).
static func prep_seconds(category: String) -> int:
	return int((data()["prep_game_seconds"] as Dictionary).get(category, 0))
