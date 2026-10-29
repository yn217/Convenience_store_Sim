class_name CraneGame
extends RefCounted
## A small crane game (UFO catcher, issue #132). The machine (crane_game) is a fixture whose slot holds prize SKUs
## (category crane_prize); ordering, restocking and the stock are those of any shelf. The SKU's sell price is the fee
## of one play, set like any other price.
## A customer who wants a prize plays at the machine: each play is paid there (a SALE row of its own, never at the
## till) and the customer stops at the first win or when out of patience or money. A win takes one prize out of the
## machine (that play's SALE books the prize's cost); a play without a win books the fee only. How many plays and
## which one wins follow from the customer and the machine (no draw from the game's random streams), and the time
## at the machine grows with the plays. Plays and wins are counted per machine (state.crane_stats); a win is
## announced, and so is a machine left without prizes (refill it). A store holds at most max_per_store machines.
## A machine breaks after a number of plays since its last repair (breakdown.after_plays, a hash of the machine and
## its repair count); a broken machine takes no players until the player repairs it (REPAIR_CRANE, a REPAIR row).
## In-game money only; no real-money play.

const PATH := "res://data/crane/crane_v1.json"
const CATEGORY := "crane_prize"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"prizes": {}}
	return _data


## Is this SKU won at a crane game (played at the machine, not bought at the till)?
static func is_crane(state: GameState, sku_id: String) -> bool:
	return String(state.products.get_sku(sku_id).get("category", "")) == CATEGORY


## The customer's session at the machine: {plays, win_at} with win_at the winning play (1-based) or 0. Patience is
## 1..max_plays from a hash of the customer and the machine; the plays stop at the money left for them (the first
## play is already in the planned spend) and at the first win, drawn per play from a stream seeded by the same hash.
static func plan(state: GameState, c: Dictionary) -> Dictionary:
	var d := data()
	var fee := maxi(state.sell_price(String(c["sku_id"])), 1)
	var key := "%s|%s|%d" % [c["customer_id"], c["fixture_id"], state.day]
	var patience := 1 + absi(("%s|patience" % key).hash()) % maxi(int(d.get("max_plays", 1)), 1)
	var afford := 1 + maxi(int(c.get("wallet_yen", 0)) - int(c.get("planned_yen", 0)), 0) / fee
	var plays := clampi(mini(patience, afford), 1, int(d.get("max_plays", 1)))
	var rng := Lcg32.new(key.hash() & 0x7fffffff)
	var p := 1.0 / maxf(float(d.get("win_one_in", 1)), 1.0)
	for i in plays:
		if rng.uniform_0_1() < p:
			return {"plays": i + 1, "win_at": i + 1}
	return {"plays": plays, "win_at": 0}


## Game seconds the customer stands at the machine, on top of the usual look at a shelf.
static func session_seconds(state: GameState, c: Dictionary) -> int:
	return int(plan(state, c)["plays"]) * int(data().get("play_seconds", 0))


## The prize a win gives (a named plush of the SKU), from the sale id.
static func prize_of(sku_id: String, sale_id: String) -> String:
	var names: Array = data().get("prizes", {}).get(sku_id, [])
	if names.is_empty():
		return ""
	return String(names[absi(sale_id.hash()) % names.size()])


## Machines of this type already in the store (the placement cap, max_per_store).
static func machines(state: GameState, type_id: String) -> int:
	var n := 0
	for inst in state.grid.instances.values():
		if String(inst["type_id"]) == type_id:
			n += 1
	return n


## Is a fixture type a crane game (its slots hold crane prizes)?
static func is_machine_type(def: Dictionary) -> bool:
	return Array(def.get("allowed_categories", [])) == [CATEGORY]


## A machine with no prize left in it is announced (refill it).
static func check_empty(state: GameState, fixture_id: String) -> void:
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and loc["fixture_id"] == fixture_id and int(seg["physical_qty"]) > 0:
			return
	state.emit_event("CRANE_EMPTY", {"fixture_id": fixture_id})


## Plays since the last repair after which the machine breaks, or 0 when breakdowns are off. A hash of the machine
## and its repair count picks it from breakdown.after_plays [min, max], so the same machine breaks at the same play.
static func break_after(fixture_id: String, repairs: int) -> int:
	var r: Array = data().get("breakdown", {}).get("after_plays", [0, 0])
	var lo := int(r[0]) if r.size() > 0 else 0
	var hi := maxi(int(r[1]) if r.size() > 1 else lo, lo)
	if lo <= 0:
		return 0
	return lo + absi(("%s|break|%d" % [fixture_id, repairs]).hash()) % (hi - lo + 1)


static func repair_cost() -> int:
	return int(data().get("breakdown", {}).get("repair_cost_yen", 0))


## Is the machine out of order (no players until repaired)?
static func is_broken(state: GameState, fixture_id: String) -> bool:
	return bool(state.crane_stats.get(fixture_id, {}).get("broken", false))


static func _stats(state: GameState, fixture_id: String) -> Dictionary:
	if not state.crane_stats.has(fixture_id):
		state.crane_stats[fixture_id] = {"plays": 0, "wins": 0, "since": 0, "repairs": 0, "broken": false}
	return state.crane_stats[fixture_id]


## REPAIR_CRANE: pays repair_cost_yen (a REPAIR row) and puts the machine back in order. -> "" or the reason.
static func repair(state: GameState, fixture_id: String, command_id: String) -> String:
	if not state.grid.instances.has(fixture_id) or not is_machine_type(state.fixtures.get_type(state.grid.instances[fixture_id]["type_id"])):
		return "unknown_instance"
	if not is_broken(state, fixture_id):
		return "crane_not_broken"
	var cost := repair_cost()
	if state.ledger.cash_yen < cost:
		return "not_enough_cash"
	if cost > 0 and not state.ledger.record("REPAIR", "%s:REPAIR" % command_id, -cost, state.day, state.time_sec, {"fixture_id": fixture_id}, {"expense": cost}):
		return "not_enough_cash"
	var st := _stats(state, fixture_id)
	st["broken"] = false
	st["since"] = 0
	st["repairs"] = int(st.get("repairs", 0)) + 1
	state.emit_event("CRANE_REPAIRED", {"fixture_id": fixture_id, "cost_yen": cost})
	return ""


## Plays the session: a fee SALE per play without a win, the reserved prize sold on the winning play, released
## when there is none. -> {ok, plays, won, prize, revenue_yen}; ok false when the ledger refused a row.
static func play(state: GameState, c: Dictionary, res_id: String) -> Dictionary:
	var pl := plan(state, c)
	var fid := String(c["fixture_id"])
	var sku_id := String(c["sku_id"])
	var fee := state.sell_price(sku_id)
	var out := {"ok": true, "plays": 0, "won": false, "prize": "", "revenue_yen": 0}
	for i in range(1, int(pl["plays"]) + 1):
		var sale_id := "crane:%s:%d" % [res_id, i]
		if i == int(pl["win_at"]):
			var sale := InventoryService.complete_sale(state, sale_id, res_id)
			if not sale["ok"]:
				break
			out["won"] = true
			out["prize"] = prize_of(sku_id, sale_id)
			out["revenue_yen"] = int(out["revenue_yen"]) + int(sale["revenue_yen"])
		elif not state.ledger.record("SALE", sale_id, fee, state.day, state.time_sec,
				{"fixture_id": fid, "customer_id": c["customer_id"], "crane_play": i, "qty": 1}, {"revenue": fee, "cogs": 0}):
			break
		else:
			out["revenue_yen"] = int(out["revenue_yen"]) + fee
		out["plays"] = i
	if not bool(out["won"]):
		InventoryService.release_reservation(state, res_id)
	out["ok"] = int(out["plays"]) > 0
	var st := _stats(state, fid)
	st["plays"] = int(st["plays"]) + int(out["plays"])
	st["since"] = int(st.get("since", 0)) + int(out["plays"])
	if bool(out["won"]):
		st["wins"] = int(st["wins"]) + 1
		state.emit_event("CRANE_WON", {"customer_id": c["customer_id"], "fixture_id": fid, "sku_id": sku_id, "prize": out["prize"],
			"plays": out["plays"], "name": state.products.get_sku(sku_id).get("display_name", "")})
		check_empty(state, fid)
	var limit := break_after(fid, int(st.get("repairs", 0)))
	if limit > 0 and int(st["since"]) >= limit and not bool(st.get("broken", false)):
		st["broken"] = true
		state.emit_event("CRANE_BROKEN", {"fixture_id": fid, "cost_yen": repair_cost()})
	return out
